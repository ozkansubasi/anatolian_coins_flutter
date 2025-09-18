plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.anatolian_coins"
    compileSdk = flutter.compileSdkVersion

    // ❗ NDK sürümünü pluginlerin istediği 27.0.12077973'e sabitle
    ndkVersion = "27.0.12077973"

    // ❗ Java 17 kullan (AGP 8+ için gerekli)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Uygulama kimliğini kendi paket adına göre değiştirebilirsin.
        applicationId = "com.example.anatolian_coins"

        // Flutter değişkenleri
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ❗ flutter_appauth için redirect scheme placeholder'ı ver
        // com.anatoliancoins.app://callback -> scheme: com.anatoliancoins.app
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "com.anatoliancoins.app"
        )
    }

    buildTypes {
        release {
            // Şimdilik debug imzası ile; release için kendi imzanı ekleyebilirsin.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
