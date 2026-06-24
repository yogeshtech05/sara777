// android/settings.gradle.kts

pluginManagement {
    val flutterSdkPath = run {
        val p = java.util.Properties()
        file("local.properties").inputStream().use { p.load(it) }
        val path = p.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }

    // Flutter Gradle integration
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Flutter artifacts (embedding, etc.)
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.12.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Apply in :app only if you really use Firebase/Play Services
    id("com.google.gms.google-services") version "4.3.15" apply false
}

include(":app")
