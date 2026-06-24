-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.datatransport.** { *; }
-keepclassmembers class * {
    @com.google.firebase.messaging.FirebaseMessagingService *;
}
