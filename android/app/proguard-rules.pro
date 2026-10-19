# Supabase & Secure Storage rules
-keep public class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# shared_preferences (used by supabase_flutter for session storage)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.coroutines.Continuation
-keep class kotlin.Metadata { *; }

# Google Play services / Google Sign-In (Credential Manager)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn com.google.android.libraries.identity.googleid.**