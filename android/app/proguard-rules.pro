# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
# The embedding references Google Play's split-install classes for deferred components, which this app does not use
# (no Play Store delivery): R8 must not fail on their absence (rules from its own missing_rules.txt).
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Firebase
-keep class com.google.firebase.** { *; }

# flutter_local_notifications serializes its scheduled notifications with Gson; without these rules, R8 strips the
# generic type information Gson reads and notifications break in release builds only (plugin README, "release build
# configuration"; rules from google/gson examples/android-proguard-example). ADR-020 M1: first release build.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
