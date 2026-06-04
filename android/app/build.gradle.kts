import java.io.FileInputStream
import java.util.Properties

// Release signing reads android/key.properties (gitignored, never committed:
// the keystore is the org's app-signing credential). When the file is absent
// (CI, a fresh clone, day-to-day debug work) debug builds work normally. A
// distribution RELEASE build without the keystore is hard-blocked (see the
// taskGraph guard below) so a debug-signed store artifact can never ship; an
// intentional local debug-signed release build needs -PallowDebugSigningForRelease=true.
// To produce a store build, generate the keystore and write key.properties;
// see android/README signing notes. Keep the keystore and passwords out of the repo.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // Kotlin (org.jetbrains.kotlin.android) is applied automatically by the
    // Flutter Gradle Plugin below, matching the Flutter 3.44 scaffold. Do not
    // re-add `id("kotlin-android")` here: applying it explicitly trips the
    // tool's "migrate to built-in Kotlin" warning on every build.
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Locked bundle identity. namespace and applicationId must both stay
    // org.kinderhorizon.lighthouse (matches the iOS bundle ID and the store
    // listings). Do NOT let a `flutter create` regeneration reintroduce an
    // _aac suffix here.
    namespace = "org.kinderhorizon.lighthouse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.kinderhorizon.lighthouse"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Real release keys when key.properties is present (store builds).
            // Otherwise fall back to debug keys so CONFIGURATION never fails and
            // `flutter run --release` is possible WITH the explicit opt-in below.
            // A distribution release build without the keystore is hard-blocked
            // by the taskGraph guard after this block, so a debug-signed AAB/APK
            // is never produced unintentionally.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Fail-closed: a distribution release build must NOT silently use debug keys.
// Evaluated at execution time (so it does not break plain debug builds or
// configuration). An assemble/bundle/package *Release* task with neither a
// release keystore nor the -PallowDebugSigningForRelease opt-in is aborted.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any { t ->
        val n = t.name
        (n.startsWith("assemble") || n.startsWith("bundle") ||
            n.startsWith("package")) && n.contains("Release")
    }
    if (releasing && !keystorePropertiesFile.exists() &&
        !project.hasProperty("allowDebugSigningForRelease")) {
        throw GradleException(
            "Release build requires android/key.properties (release signing). " +
            "For an intentional debug-signed local release build, pass " +
            "-PallowDebugSigningForRelease=true. " +
            "Never distribute a debug-signed artifact."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
