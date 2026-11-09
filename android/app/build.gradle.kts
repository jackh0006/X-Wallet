plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jackh0006.xwallet"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jackh0006.xwallet"
        // Android 8.0 (API 26) supports devices such as the Huawei Y9 2019
        // while retaining modern platform encryption and TLS capabilities.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ABIs are selected by the build command: the release script builds
        // one arm64-v8a APK and one universal APK. When
        // ORG_GRADLE_PROJECT_xwalletAbi is set, restrict every native library
        // (including plugin libraries) to that ABI.
        val requestedAbi = project.findProperty("xwalletAbi") as String?
        if (requestedAbi != null && requestedAbi.isNotBlank()) {
            ndk {
                abiFilters.clear()
                abiFilters.add(requestedAbi)
            }
        }
    }

    buildTypes {
        release {
            // Signed with apksigner (v3) by scripts/build-apk.sh; debug keys here
            // keep `flutter run --release` working during development.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
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
