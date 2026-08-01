plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bt.bt_torrent"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bt.bt_torrent"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // BT 引擎：libtorrent4j（libtorrent 2.x 的 JNI 封装）
    implementation("org.libtorrent4j:libtorrent4j:2.1.0-36")
    implementation("org.libtorrent4j:libtorrent4j-android-arm64:2.1.0-36") {
        exclude(group = "org.libtorrent4j", module = "libtorrent4j")
    }
    implementation("org.libtorrent4j:libtorrent4j-android-arm:2.1.0-36") {
        exclude(group = "org.libtorrent4j", module = "libtorrent4j")
    }
    implementation("org.libtorrent4j:libtorrent4j-android-x86:2.1.0-36") {
        exclude(group = "org.libtorrent4j", module = "libtorrent4j")
    }
    implementation("org.libtorrent4j:libtorrent4j-android-x86_64:2.1.0-36") {
        exclude(group = "org.libtorrent4j", module = "libtorrent4j")
    }
}
