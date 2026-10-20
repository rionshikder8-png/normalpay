# Fix for ErrorProne / Tink
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-keep class com.google.crypto.tink.** { *; }

# Fix for Tink KeysDownloader (Google API Client)
-dontwarn com.google.api.client.**
-dontwarn org.joda.time.**
-dontwarn com.google.crypto.tink.util.KeysDownloader
