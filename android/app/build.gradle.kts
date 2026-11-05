plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.namaz_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // Bu satırı ekle
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }


    // İki sürüm: "deneme" geliştiricinin telefonundaki test sürümü (kablosuz güncelleme, test araçları),
    // "yayin" Play Store'a giden kullanıcı sürümü. Paket adları farklı: telefonda yan yana durabilirler.
    //   flutter build apk --flavor deneme      (./publish.sh)
    //   flutter build appbundle --flavor yayin
    flavorDimensions += "surum"
    productFlavors {
        create("deneme") {
            dimension = "surum"
            applicationId = "com.example.namaz_app"
            manifestPlaceholders["uygulamaAdi"] = "Takva Yolum Test"
        }
        create("yayin") {
            dimension = "surum"
            applicationId = "com.takvayolum.app"
            manifestPlaceholders["uygulamaAdi"] = "Takva Yolum"
        }
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
    // Sürümü 2.0.3'ten 2.1.4'e yükseltin
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

