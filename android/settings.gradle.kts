pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP pinned to the latest 8.x line, deliberately below 9.0: AGP 9 flips
    // plugins to AGP's built-in Kotlin compilation, but our plugin set (e.g.
    // file_picker, permission_handler) still ships the legacy `apply plugin:
    // org.jetbrains.kotlin.android` path, which only runs under AGP < 9.
    // 8.13.x clears Flutter 3.44's warn floor (>= 8.11.1) without entering the
    // not-yet-uniformly-supported built-in-Kotlin transition.
    id("com.android.application") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.2.21" apply false
}

include(":app")
