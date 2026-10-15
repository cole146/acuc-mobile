plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "jobs.acuc.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Same package as the app already on Google Play, so this ships as an update.
        applicationId = "jobs.acuc.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        // CI passes -PacucVersionCode (always higher than the last Play upload).
        versionCode = (project.findProperty("acucVersionCode") as String?)?.toInt() ?: flutter.versionCode
        versionName = (project.findProperty("acucVersionName") as String?) ?: flutter.versionName
    }

    // Release signing: the ACUC upload key when ACUC_KEYSTORE_FILE is set; otherwise the bundle is left
    // unsigned and signed afterwards with the upload key (jarsigner).
    val ks = System.getenv("ACUC_KEYSTORE_FILE")
    signingConfigs {
        if (!ks.isNullOrEmpty()) {
            create("upload") {
                storeFile = file(ks)
                storePassword = System.getenv("ACUC_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ACUC_KEY_ALIAS")
                keyPassword = System.getenv("ACUC_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (!ks.isNullOrEmpty()) signingConfigs.getByName("upload") else null
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
