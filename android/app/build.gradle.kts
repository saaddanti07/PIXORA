plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pixora.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pixora.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The LiteRT model is memory-mapped straight out of the APK, which requires
    // it to be stored uncompressed.
    androidResources {
        noCompress += "tflite"
    }

    buildTypes {
        release {
            // Phase 01 produces development builds only. Release signing is
            // added through a local `key.properties` file (never committed).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Google LiteRT runtime (the successor of org.tensorflow:tensorflow-lite).
    // CPU execution with the bundled XNNPACK kernels is the Phase 02 baseline.
    implementation("com.google.ai.edge.litert:litert:1.0.0")

    // EXIF orientation, so a portrait photo is not restored lying on its side.
    implementation("androidx.exifinterface:exifinterface:1.3.7")

    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
