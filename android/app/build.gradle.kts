import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.playfriends.play_friends"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.playfriends.play_friends"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasVal = keystoreProperties.getProperty("keyAlias")
            val keyPasswordVal = keystoreProperties.getProperty("keyPassword")
            val storeFileVal = keystoreProperties.getProperty("storeFile")
            val storePasswordVal = keystoreProperties.getProperty("storePassword")

            if (storeFileVal != null && storeFileVal.isNotBlank()) {
                val resolvedStoreFile = file(storeFileVal)
                if (!resolvedStoreFile.exists()) {
                    throw GradleException(
                        "Release signing error: Keystore file not found at '${resolvedStoreFile.absolutePath}'. " +
                        "Verify 'storeFile' in android/key.properties."
                    )
                }
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
                storeFile = resolvedStoreFile
                storePassword = storePasswordVal
            }
        }
    }

    buildTypes {
        release {
            val hasKeystore = keystorePropertiesFile.exists() && keystoreProperties.getProperty("storeFile") != null
            if (!hasKeystore) {
                throw GradleException(
                    "Production release build failed: 'android/key.properties' is missing or incomplete! " +
                    "Production release builds cannot silently use debug signing. " +
                    "Copy 'android/key.properties.example' to 'android/key.properties' and configure your upload keystore."
                )
            }
            signingConfig = signingConfigs.getByName("release")
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
