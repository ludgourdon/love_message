# --- WorkManager / Room (tirés par le SDK Google Mobile Ads) ---
# Évite "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.startup.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# --- Google Mobile Ads (AdMob) ---
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# --- Firebase ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Conserve les infos utiles à Crashlytics.
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
