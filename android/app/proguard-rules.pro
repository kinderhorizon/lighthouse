# ProGuard / R8 rules for NūriTalk / ACC2
# Preserves Kotlin Coroutines & JNI reflection required by Flutter plugins (such as shared_preferences_android, isar, flutter_tts)

# Flutter core and plugin channels
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Shared preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep interface io.flutter.plugins.sharedpreferences.** { *; }

# Isar Database native JNI & models
-keep class io.isar.** { *; }
-keep interface io.isar.** { *; }

# Text-To-Speech (flutter_tts)
-keep class com.tundralabs.fluttertts.** { *; }

# Audio recording & playback (record, just_audio)
-keep class com.llfbandit.record.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# Path Provider & File Selector
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

# Kotlin coroutines and standard types used in plugin JNI signatures
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.coroutines.** { *; }
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses

# Suppress warnings for optional Play Store deferred components not bundled in app
-dontwarn com.google.android.play.core.**
