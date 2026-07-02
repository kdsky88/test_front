plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Base64
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(name: String): String? =
    (keystoreProperties[name] as String?) ?: System.getenv("ANDROID_${envKey(name)}")

fun requiredSigningValue(name: String): String =
    signingValue(name)
        ?: error(
            "Missing Android release signing value '$name'. " +
                "Set it in android/key.properties or ANDROID_${envKey(name)}."
        )

fun envKey(name: String): String =
    name.replace(Regex("([a-z])([A-Z])"), "$1_$2").uppercase()

val isReleaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true)
}

fun releaseApiBaseUrl(): String {
    val defineArg = project.findProperty("dart-defines") as String?
    if (defineArg == null) return ""
    return defineArg
        .split(",")
        .mapNotNull { encoded: String ->
            runCatching {
                String(Base64.getDecoder().decode(encoded))
            }.getOrNull()
        }
        .firstOrNull { decoded: String -> decoded.startsWith("API_BASE_URL=") }
        ?.substringAfter("=")
        ?: ""
}

android {
    namespace = "com.openclaw.todo_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications가 java.time을 써서 desugaring 필요
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.openclaw.todo_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = if (isReleaseBuildRequested) requiredSigningValue("keyAlias") else signingValue("keyAlias")
            keyPassword = if (isReleaseBuildRequested) requiredSigningValue("keyPassword") else signingValue("keyPassword")
            storeFile = file(
                if (isReleaseBuildRequested) requiredSigningValue("storeFile") else signingValue("storeFile") ?: "missing-release-keystore.jks"
            )
            storePassword = if (isReleaseBuildRequested) requiredSigningValue("storePassword") else signingValue("storePassword")
        }
    }

    buildTypes {
        release {
            if (isReleaseBuildRequested) {
                val apiBaseUrl = releaseApiBaseUrl()
                if (!apiBaseUrl.startsWith("https://")) {
                    error("Release builds require --dart-define=API_BASE_URL=https://...")
                }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
