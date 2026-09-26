import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload keystore bilgileri android/key.properties'ten okunur (git'e girmez)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.anatoliancoins.app"
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
        applicationId = "com.anatoliancoins.app"

        // Flutter değişkenleri
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ❗ flutter_appauth için redirect scheme placeholder'ı ver
        // com.anatoliancoins.app://callback -> scheme: com.anatoliancoins.app
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "com.anatoliancoins.app",
            "appLabel" to "Anatolian Coins"
        )
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        // Geliştirme sürümü Play sürümünün YANINA kurulur (farklı paket adı):
        // cihazda düzen/görsel iterasyonu ve log izleme için, Play kurulumuna
        // ve verisine dokunmadan (2026-09-26). Satın alma bu pakette çalışmaz.
        debug {
            applicationIdSuffix = ".dev"
            manifestPlaceholders += mapOf("appLabel" to "AC Dev")
        }
        release {
            // key.properties varsa upload anahtarıyla, yoksa debug imzasıyla
            // (Play'e yükleme için key.properties ZORUNLU)
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for flutter_appauth (Chrome Custom Tabs)
    implementation("androidx.browser:browser:1.8.0")
}
