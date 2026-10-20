# R8 Missing Classes Fix for Google Tink / ErrorProne
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-keep class com.google.crypto.tink.** { *; }
