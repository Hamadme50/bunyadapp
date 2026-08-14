# R8 only ever sees the thin Java/Kotlin plugin layer — the Dart code is
# already compiled into libapp.so and is untouched by shrinking. These are the
# few places that layer is reached other than by a direct call.

# flutter_secure_storage goes through the Android keystore to hold the bearer
# token; the crypto classes are looked up rather than called.
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Flutter's engine references Play Core's deferred-components APIs. This app
# ships as one module and never loads a split, so those classes are absent by
# design. Narrowed to the split packages: com.google.android.play:app-update is
# genuinely on the classpath now, for the in-app update flow, and blanket
# -dontwarn there would hide a real missing-class problem in a release build —
# the only kind of build the update flow ever runs in.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# The update flow is handed to Play through a listener it calls back on, so the
# entry points are never reached by a direct call R8 can see.
-keep class com.google.android.play.core.appupdate.** { *; }
-keep interface com.google.android.play.core.install.** { *; }
