plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.justplay.timekiller"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once published: Play identifies the app by this string, and it
        // can never be changed for an existing listing. `timekiller` is the app,
        // `justplay` the studio — a second app becomes com.justplay.<name>.
        applicationId = "com.justplay.timekiller"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // RELEASE BLOCKER — debug keys. An APK or bundle built from this cannot
            // be uploaded to Play. Creating the upload keystore is a credential
            // operation and belongs to whoever owns the account; see
            // docs/RELEASE.md for what to generate and where it plugs in.
            signingConfig = signingConfigs.getByName("debug")
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
