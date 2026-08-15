import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing credentials, read from android/key.properties when it exists.
//
// That file is gitignored and holds passwords, so it is never committed and
// never present on a fresh clone or a CI runner. Everything below therefore has
// to work without it — see the fallback in buildTypes.release.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    keystoreProperties.getProperty("storeFile") != null

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

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Real keys when they are available, debug keys otherwise.
            //
            // The fallback is what keeps `flutter build apk --release` working on a
            // clone with no credentials, including CI. It is also a trap: a
            // debug-signed build looks fine locally and is rejected by Play, so the
            // warning below fires on every release build that lacks a keystore
            // rather than letting it pass quietly.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Fires during configuration, so it is visible in the build log of any release
// build made without credentials. Silence here is how a debug-signed artefact
// reaches an upload attempt before anybody notices.
if (!hasReleaseKeystore) {
    logger.warn(
        "JustPlay: android/key.properties not found — release builds will be signed " +
            "with DEBUG keys and cannot be uploaded to Play. See docs/RELEASE.md."
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
