plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

fun projectPropertyOrEnv(name: String): String? {
    val propertyValue = findProperty(name) as String?
    if (!propertyValue.isNullOrBlank()) {
        return propertyValue
    }

    val environmentValue = System.getenv(name)
    if (!environmentValue.isNullOrBlank()) {
        return environmentValue
    }

    return null
}

val releaseStoreFilePath = projectPropertyOrEnv("ANDROID_STORE_FILE")
val releaseStorePassword = projectPropertyOrEnv("ANDROID_STORE_PASSWORD")
val releaseKeyAlias = projectPropertyOrEnv("ANDROID_KEY_ALIAS")
val releaseKeyPassword = projectPropertyOrEnv("ANDROID_KEY_PASSWORD")
val hasReleaseSigning =
    !releaseStoreFilePath.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "com.liftsforge.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.liftsforge.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Keep local release builds working until a real keystore is provided.
                signingConfigs.getByName("debug")
            }
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

dependencies {
  implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
  implementation("com.google.firebase:firebase-analytics")
}
