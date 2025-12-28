# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Sign In
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }

# Google APIs (Drive, etc.)
-keep class com.google.api.client.** { *; }
-keep class com.google.api.services.drive.** { *; }

# Prevent shrinking of model classes that might be used via reflection
-keep class com.google.api.services.drive.model.** { *; }

# Square OkHttp
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.** 

# Ignore missing Play Core classes (we don't use dynamic features)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
