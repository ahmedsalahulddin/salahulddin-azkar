# Gson requires generic type signatures at runtime to deserialize collections.
# R8 strips them by default, causing "Missing type parameter." on every
# zonedSchedule() call inside flutter_local_notifications.
-keepattributes Signature
-keepattributes *Annotation*

# Keep Gson's own classes and TypeAdapterFactory implementations.
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter { *; }
-keep class * implements com.google.gson.TypeAdapterFactory { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# flutter_local_notifications: keep all models and plugin classes so Gson
# can construct and read them with their declared field names.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
