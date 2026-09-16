import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 2026-09-17: real release signing, replacing the Flutter template's
// "sign with the debug keys for now" TODO that had survived since the
// project was generated — the same replacement Yahweh's Sword got on
// 2026-08-25 and Yahweh's Words on 2026-09-09. A debug-signed APK
// carries `CN=Android Debug, O=Android, C=US` as its certificate DN,
// which is what a recipient sees, and every Flutter install on every
// machine shares that one well-known keypair: it identifies nobody,
// and anyone can forge an "update" to it.
//
// The keystore is NEVER in this repository. It is looked for in two
// places, in order, and if neither exists the build FALLS BACK to
// debug signing rather than failing:
//
//   1. android/key.properties     — the Flutter convention, already
//                                   covered by android/.gitignore
//   2. ~/.config/yswords/secrets/ — where this machine's secrets live,
//                                   mirrored to ~/Documents/secure-keys-backup/
//
// The fallback is deliberate rather than lazy: a machine without the
// keystore (a fresh clone, a CI runner) must still be able to build a
// sideloadable APK for testing. It warns loudly when it takes that
// path, because an APK signed that way must not be published.
//
// Losing the keystore is unrecoverable: Android refuses an update
// signed with a different key, so a lost key forces every user to
// uninstall and reinstall. That is also why this change is a one-time
// cost — installs of v1.2.6 and earlier carry the debug certificate
// and must be removed once before v1.2.7 will install over them.
val keystoreProperties = Properties().apply {
    val candidates = listOf(
        rootProject.file("key.properties"),
        File(
            System.getProperty("user.home"),
            ".config/yswords/secrets/newsinsight-key.properties",
        ),
    )
    candidates.firstOrNull { it.exists() }?.inputStream()?.use { load(it) }
}
val releaseStoreFile: File? =
    keystoreProperties.getProperty("storeFile")?.let(::File)?.takeIf { it.exists() }

android {
    namespace = "com.yswords.yahwehsworld"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The application id is what Android identifies an install by.
        // It ships in the published APK, so it does not change.
        applicationId = "com.yswords.yahwehsworld"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // See the keystore note at the top of this file.
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "News Insight: no release keystore found — signing with " +
                        "the DEBUG key. This APK is for testing only; its " +
                        "certificate DN reads CN=Android Debug. Do not publish it.",
                )
                signingConfigs.getByName("debug")
            }
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
