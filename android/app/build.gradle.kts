plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.langtok.app"
    // Delegate to Flutter's own SDK version constants rather than a
    // hardcoded number. This is the fix recommended by the Flutter team
    // for AGP 9 compatibility issues where transitive plugin dependencies
    // (e.g. package_info_plus, pulled in by file_picker) fail to resolve
    // compileSdkVersion under the new AGP DSL. See:
    // https://github.com/flutter/flutter/issues/181383
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.langtok.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Using debug signing so `flutter build apk --release` produces
            // an installable, unsigned-for-store (but sideload-ready) APK
            // out of the box. Replace with your own keystore before
            // publishing to Google Play.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        // Avoids duplicate native lib conflicts pulled in by media_kit's
        // bundled libmpv binaries across architectures.
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}
