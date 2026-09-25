const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const functionsV1 = require("firebase-functions/v1");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// À chaque cœur créé, notifie le destinataire sur ses appareils.
exports.onHeartCreated = onDocumentCreated("hearts/{heartId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const heart = snap.data() || {};
  const toUid = heart.toUid;
  const fromUid = heart.fromUid || "";
  const count = heart.count || 1;
  const message = (heart.message || "").trim();
  if (!toUid) return;

  // Nom local que le destinataire a donné à l'expéditeur, sinon le nom envoyé.
  let senderName = heart.fromName || "Quelqu'un";
  try {
    const people = await db
      .collection("users").doc(toUid).collection("people")
      .where("linkedUid", "==", fromUid).limit(1).get();
    if (!people.empty) {
      const n = ((people.docs[0].data() || {}).name || "").trim();
      if (n) senderName = n;
    }
  } catch (e) { /* ignore */ }

  // Tokens du destinataire.
  const tokensSnap = await db
    .collection("users").doc(toUid).collection("fcmTokens").get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) return;

  const s = count > 1 ? "s" : "";
  const title = `${senderName} t'envoie ${count} cœur${s} 💗`;
  const body = message.length > 0 ? message : "Ouvre l'app pour les recevoir 💕";

  const resp = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
    data: { type: "heart", fromUid, count: String(count) },
  });

  // Supprime les tokens devenus invalides.
  const invalid = [];
  resp.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
      ) {
        invalid.push(tokens[i]);
      }
    }
  });
  await Promise.all(
    invalid.map((t) =>
      db.collection("users").doc(toUid).collection("fcmTokens").doc(t)
        .delete().catch(() => {})
    )
  );
});


// ---------------------------------------------------------------------------
// Relance "réponds à tes cœurs".
//
// Toutes les 5 minutes, on cherche les cœurs reçus il y a au moins 30 minutes
// dont le destinataire n'a PAS répondu (= n'a pas renvoyé de cœurs à
// l'expéditeur depuis). On lui propose alors, par une notification push,
// d'envoyer des cœurs en retour. Une relance n'est envoyée qu'une fois par
// couple (destinataire, expéditeur) : les cœurs traités sont marqués
// `replyReminderSent: true` (écriture admin, hors règles de sécurité).
// ---------------------------------------------------------------------------
exports.remindUnansweredHearts = onSchedule(
  {
    schedule: "every 5 minutes",
    region: "europe-west9",
    timeZone: "Europe/Paris",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    const now = Date.now();
    const cutoff = Timestamp.fromMillis(now - 30 * 60 * 1000); // reçus il y a >= 30 min
    const floor = Timestamp.fromMillis(now - 6 * 60 * 60 * 1000); // borne basse : 6 h

    // Cœurs reçus dans la fenêtre [floor, cutoff] (plage sur un seul champ,
    // donc pas d'index composite à créer).
    const snap = await db
      .collection("hearts")
      .where("createdAt", ">=", floor)
      .where("createdAt", "<=", cutoff)
      .get();
    if (snap.empty) return;

    // Regroupe les cœurs non encore relancés par couple destinataire/expéditeur.
    const pairs = new Map(); // `${toUid}|${fromUid}` -> {toUid, fromUid, refs:[], minMs}
    snap.forEach((doc) => {
      const d = doc.data() || {};
      if (d.replyReminderSent === true) return;
      const toUid = d.toUid;
      const fromUid = d.fromUid;
      if (!toUid || !fromUid || toUid === fromUid) return;
      const key = `${toUid}|${fromUid}`;
      let pair = pairs.get(key);
      if (!pair) {
        pair = { toUid, fromUid, refs: [], minMs: Infinity };
        pairs.set(key, pair);
      }
      pair.refs.push(doc.ref);
      const ms = d.createdAt ? d.createdAt.toMillis() : now;
      if (ms < pair.minMs) pair.minMs = ms;
    });
    if (pairs.size === 0) return;

    const remindByRecipient = new Map(); // toUid -> [{fromUid, name}]
    const toMark = []; // refs à marquer replyReminderSent

    for (const pair of pairs.values()) {
      const { toUid, fromUid, minMs } = pair;
      // Ces cœurs sont traités dans tous les cas (évite les relances répétées).
      pair.refs.forEach((ref) => toMark.push(ref));

      // A a-t-il répondu ? = a-t-il envoyé des cœurs à B depuis la réception ?
      // Deux égalités (fromUid + toUid) => servi par les index simples, pas
      // d'index composite. Le filtre temporel se fait en mémoire.
      const replySnap = await db
        .collection("hearts")
        .where("fromUid", "==", toUid)
        .where("toUid", "==", fromUid)
        .get();
      const replied = replySnap.docs.some((r) => {
        const c = (r.data() || {}).createdAt;
        return c && c.toMillis() > minMs;
      });
      if (replied) continue;

      // Garde-fous : blocage (dans un sens ou l'autre) ou expéditeur supprimé.
      const [blockedByA, blockedByB, senderDoc] = await Promise.all([
        db.doc(`users/${toUid}/blocked/${fromUid}`).get(),
        db.doc(`users/${fromUid}/blocked/${toUid}`).get(),
        db.doc(`users/${fromUid}`).get(),
      ]);
      if (blockedByA.exists || blockedByB.exists || !senderDoc.exists) continue;

      // Nom local que le destinataire a donné à l'expéditeur.
      let name = "quelqu'un";
      try {
        const people = await db
          .collection("users").doc(toUid).collection("people")
          .where("linkedUid", "==", fromUid).limit(1).get();
        if (!people.empty) {
          const n = ((people.docs[0].data() || {}).name || "").trim();
          if (n) name = n;
        }
      } catch (e) { /* ignore */ }

      let arr = remindByRecipient.get(toUid);
      if (!arr) {
        arr = [];
        remindByRecipient.set(toUid, arr);
      }
      arr.push({ fromUid, name });
    }

    // Marque les cœurs traités (par lots de 400 pour rester sous la limite).
    for (let i = 0; i < toMark.length; i += 400) {
      const batch = db.batch();
      toMark.slice(i, i + 400).forEach((ref) =>
        batch.update(ref, { replyReminderSent: true })
      );
      await batch.commit();
    }

    // Une notification par destinataire.
    await Promise.all(
      Array.from(remindByRecipient.entries()).map(([toUid, senders]) =>
        sendReplyReminder(toUid, senders)
      )
    );
  }
);

async function sendReplyReminder(toUid, senders) {
  const tokensSnap = await db
    .collection("users").doc(toUid).collection("fcmTokens").get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) return;

  let title;
  let body;
  if (senders.length === 1) {
    title = `Réponds à ${senders[0].name} 💌`;
    body = "Tu as reçu des cœurs il y a un moment — envoie-lui-en en retour ?";
  } else {
    const others = senders.length - 1;
    title = "Des cœurs attendent ta réponse 💌";
    body =
      `${senders[0].name} et ${others} autre${others > 1 ? "s" : ""} ` +
      "t'ont envoyé des cœurs — réponds-leur ?";
  }

  const resp = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
    data: {
      type: "reply_reminder",
      count: String(senders.length),
      fromUid: senders.length === 1 ? senders[0].fromUid : "",
    },
  });

  const invalid = [];
  resp.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
      ) {
        invalid.push(tokens[i]);
      }
    }
  });
  await Promise.all(
    invalid.map((t) =>
      db.collection("users").doc(toUid).collection("fcmTokens").doc(t)
        .delete().catch(() => {})
    )
  );
}


// ---------------------------------------------------------------------------
// Rappel d'anniversaire.
//
// Chaque matin, on repère les comptes dont c'est l'anniversaire aujourd'hui
// (jour + mois) et on notifie leurs proches connectés pour qu'ils lui envoient
// des cœurs et un petit mot. La notification ouvre l'écran d'envoi vers la
// personne (payload fromUid). Aucune écriture croisée : lecture admin.
// ---------------------------------------------------------------------------
exports.notifyBirthdays = onSchedule(
  {
    schedule: "0 9 * * *", // tous les jours à 09:00
    region: "europe-west9",
    timeZone: "Europe/Paris",
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    // Date du jour en Europe/Paris.
    const parts = new Intl.DateTimeFormat("fr-FR", {
      timeZone: "Europe/Paris",
      day: "numeric",
      month: "numeric",
    }).formatToParts(new Date());
    const day = Number(parts.find((p) => p.type === "day").value);
    const month = Number(parts.find((p) => p.type === "month").value);

    // Comptes dont c'est l'anniversaire aujourd'hui.
    const birthdaysSnap = await db
      .collection("users")
      .where("birthdayMonth", "==", month)
      .where("birthdayDay", "==", day)
      .where("birthdayRemindersEnabled", "==", true)
      .get();
    if (birthdaysSnap.empty) return;

    for (const bDoc of birthdaysSnap.docs) {
      const birthdayUid = bDoc.id;
      // Proches connectés à cette personne : tous les "people" liés à son uid.
      const linkedSnap = await db
        .collectionGroup("people")
        .where("linkedUid", "==", birthdayUid)
        .get();
      if (linkedSnap.empty) continue;

      for (const personDoc of linkedSnap.docs) {
        // Le propriétaire de cette carte "people" = destinataire de la notif.
        const ownerRef = personDoc.ref.parent.parent;
        if (!ownerRef) continue;
        const ownerUid = ownerRef.id;
        if (ownerUid === birthdayUid) continue;

        // Garde-fou : pas de rappel si l'un a bloqué l'autre.
        const [blockedByOwner, blockedByBday] = await Promise.all([
          db.doc(`users/${ownerUid}/blocked/${birthdayUid}`).get(),
          db.doc(`users/${birthdayUid}/blocked/${ownerUid}`).get(),
        ]);
        if (blockedByOwner.exists || blockedByBday.exists) continue;

        // Nom local que le destinataire a donné à la personne fêtée.
        const name = ((personDoc.data() || {}).name || "").trim() || "un proche";

        const tokensSnap = await db
          .collection("users").doc(ownerUid).collection("fcmTokens").get();
        const tokens = tokensSnap.docs.map((d) => d.id);
        if (tokens.length === 0) continue;

        const resp = await getMessaging().sendEachForMulticast({
          tokens,
          notification: {
            title: `C'est l'anniversaire de ${name} 🎂`,
            body: "Envoie-lui des cœurs et un petit mot pour lui faire plaisir 💗",
          },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default" } } },
          data: { type: "birthday", fromUid: birthdayUid },
        });

        const invalid = [];
        resp.responses.forEach((r, i) => {
          if (!r.success) {
            const code = r.error && r.error.code;
            if (
              code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-argument"
            ) {
              invalid.push(tokens[i]);
            }
          }
        });
        await Promise.all(
          invalid.map((t) =>
            db.collection("users").doc(ownerUid).collection("fcmTokens").doc(t)
              .delete().catch(() => {})
          )
        );
      }
    }
  }
);


// ---------------------------------------------------------------------------
// Purge RGPD à la suppression de compte.
//
// Quand le compte Auth d'un utilisateur est supprimé (depuis l'app ou par
// l'admin), on efface avec les droits admin toutes les données résiduelles qui
// le référencent et que les règles Firestore strictes empêchent l'app de
// supprimer côté client : cœurs envoyés/reçus, invitations et demandes de
// connexion.
// ---------------------------------------------------------------------------
async function _deleteWhere(collection, field, uid) {
  while (true) {
    const snap = await db
      .collection(collection)
      .where(field, "==", uid)
      .limit(400)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.reference));
    await batch.commit();
    if (snap.size < 400) break;
  }
}

exports.onUserDeleted = functionsV1
  .region("europe-west9")
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    for (const [collection, field] of [
      ["hearts", "fromUid"],
      ["hearts", "toUid"],
      ["connectionRequests", "fromUid"],
      ["connectionRequests", "toUid"],
      ["invitations", "fromUid"],
      ["invitations", "toUid"],
    ]) {
      try {
        await _deleteWhere(collection, field, uid);
      } catch (e) {
        // On continue les autres purges même si l'une échoue.
      }
    }
  });
