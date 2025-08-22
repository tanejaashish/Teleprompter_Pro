plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    //id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.teleprompt_mobile"
    compileSdk = 34
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true  // Add this
        sourceCompatibility = JavaVersion.VERSION_8
        targetCompatibility = JavaVersion.VERSION_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.teleprompt_mobile"
        //minSdkVersion = flutter.minSdkVersion
        minSdkVersion flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")  // Add this
}

apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
