const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
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
