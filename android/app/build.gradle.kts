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
var hasValidReleaseKey = false

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    val storeFilePath = keystoreProperties.getProperty("storeFile")
    val keyAlias = keystoreProperties.getProperty("keyAlias")
    val storePassword = keystoreProperties.getProperty("storePassword")
    val keyPassword = keystoreProperties.getProperty("keyPassword")

    val resolvedStoreFile = if (!storeFilePath.isNullOrBlank()) {
        val f = file(storeFilePath)
        if (f.exists()) f else rootProject.file(storeFilePath)
    } else null

    if (resolvedStoreFile != null && resolvedStoreFile.exists() &&
        !keyAlias.isNullOrBlank() && !storePassword.isNullOrBlank() && !keyPassword.isNullOrBlank()) {
        hasValidReleaseKey = true
    }
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
        if (hasValidReleaseKey) {
            create("release") {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                val f = file(storeFilePath)
                storeFile = if (f.exists()) f else rootProject.file(storeFilePath)
                keyAlias = keystoreProperties.getProperty("keyAlias")
                storePassword = keystoreProperties.getProperty("storePassword")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasValidReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Fail-closed: a distribution release build must NOT silently use debug keys.
// Evaluated at execution time (so it does not break plain debug builds or
// configuration). An assemble/bundle/package *Release* task with neither a
// valid release keystore nor the -PallowDebugSigningForRelease opt-in is aborted.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any { t ->
        val n = t.name
        (n.startsWith("assemble") || n.startsWith("bundle") ||
            n.startsWith("package")) && n.contains("Release")
    }
    if (releasing) {
        if (hasValidReleaseKey) {
            println("========================================================================")
            println("[RELEASE SIGNING] Signing release artifact with production upload key.")
            println("Key Alias: " + keystoreProperties.getProperty("keyAlias"))
            println("========================================================================")
        } else if (project.hasProperty("allowDebugSigningForRelease")) {
            println("========================================================================")
            println("[WARNING] Building release artifact with INSECURE DEBUG signing key.")
            println("- Flag: -PallowDebugSigningForRelease=true was provided.")
            println("- Artifacts produced are signed with Android Debug certificate.")
            println("- DO NOT DISTRIBUTE OR UPLOAD THESE ARTIFACTS TO GOOGLE PLAY STORE.")
            println("========================================================================")
        } else {
            throw GradleException(
                "========================================================================\n" +
                "ERROR: PRODUCTION RELEASE BUILD BLOCKED - SIGNING KEY REQUIRED\n" +
                "No valid android/key.properties found.\n\n" +
                "To build a production-ready artifact for Google Play:\n" +
                "  1. Copy android/key.properties.example to android/key.properties\n" +
                "  2. Configure storeFile, storePassword, keyAlias, and keyPassword\n" +
                "  3. Ensure the upload keystore exists and is kept secure (never committed)\n\n" +
                "For an intentional local testing build ONLY, explicitly pass:\n" +
                "  -PallowDebugSigningForRelease=true\n" +
                "========================================================================"
            )
        }
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
