plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.leetcode_streak"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    
    defaultConfig {
        applicationId = "com.example.leetcode_streak"
        // Set minSdk to 23 as required by androidx.glance
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.glance:glance:1.2.0-beta01")
    implementation("androidx.glance:glance-appwidget:1.2.0-beta01")
}