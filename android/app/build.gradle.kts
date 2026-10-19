plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nexusweave.talksy_authenticator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nexusweave.talksy_authenticator"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")

            // STEP 1 (testing): minify OFF. If the release app works now, R8 was the problem.
            isMinifyEnabled = false
            isShrinkResources = false

            // STEP 2 (after it works): turn minify ON by replacing the two lines above with:
            //   isMinifyEnabled = true
            //   isShrinkResources = true
            //   proguardFiles(
            //       getDefaultProguardFile("proguard-android-optimize.txt"),
            //       "proguard-rules.pro"
            //   )
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