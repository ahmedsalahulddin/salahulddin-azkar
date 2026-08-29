import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing credentials live outside the repository. android/key.properties and
// the keystore itself are git-ignored: losing them means never being able to
// update the app on Play again, and leaking them lets anyone publish as you.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.salahulddin.azkar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.salahulddin.azkar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // R8 strips generic type signatures by default, breaking Gson's
            // TypeToken inside flutter_local_notifications ("Missing type
            // parameter."). The rules file keeps Signature attributes and all
            // plugin model classes so serialisation round-trips correctly.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Falls back so the app still builds on a fresh checkout, but
                // says so loudly: the debug key is identical on every machine
                // in the world, and Play rejects anything signed with it.
                //
                // println rather than logger.warn — `flutter build` filters
                // Gradle's warning channel, so a warning there is never seen.
                signingConfig = signingConfigs.getByName("debug")
                println(
                    "\n⚠️  Release build is signed with the DEBUG key." +
                        "\n   android/key.properties is missing — this APK cannot go to Play.\n"
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
