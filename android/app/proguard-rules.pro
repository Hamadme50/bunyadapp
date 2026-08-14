# R8 only ever sees the thin Java/Kotlin plugin layer — the Dart code is
# already compiled into libapp.so and is untouched by shrinking. These are the
# few places that layer is reached other than by a direct call.

# flutter_secure_storage goes through the Android keystore to hold the bearer
# token; the crypto classes are looked up rather than called.
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Flutter's engine references Play Core for deferred components. This app ships
# as one module and never loads a split, so the classes are absent by design.
-dontwarn com.google.android.play.core.**
