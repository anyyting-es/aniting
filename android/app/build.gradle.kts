import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.anyyting.aniting"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.anyyting.aniting"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = "anitingapp"
            keyAlias = "aniting"
            keyPassword = "anitingapp"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    packaging {
        jniLibs {
            pickFirsts.add("**/libc++_shared.so")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

val dartDefinesString = project.findProperty("dart-defines") as? String
val isNoBackendViaDartDefine = if (!dartDefinesString.isNullOrEmpty()) {
    try {
        val decoded = String(Base64.getDecoder().decode(dartDefinesString))
        decoded.contains("NO_BACKEND=true") || decoded.contains("INCLUDE_BACKEND=false")
    } catch (_: Exception) { false }
} else false

val includeBackend = if (isNoBackendViaDartDefine) {
    false
} else {
    project.findProperty("includeBackend")?.toString()?.toBoolean()
        ?: (System.getenv("INCLUDE_BACKEND")?.toBoolean() ?: true)
}

if (includeBackend) {
    println("[Aniting Build] Packaging FULL build with embedded Go backend (seanime.aar)")
} else {
    println("[Aniting Build] Packaging LIGHTWEIGHT build WITHOUT Go backend (client-only)")
}

dependencies {
    if (includeBackend) {
        implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
    } else {
        implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar"), "exclude" to listOf("seanime.aar"))))
    }
    implementation(project(":libass"))
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.5.1")
    implementation("androidx.media3:media3-exoplayer-dash:1.5.1")
    implementation("androidx.media3:media3-ui:1.5.1")
    implementation("androidx.media3:media3-common:1.5.1")
}

flutter {
    source = "../.."
}
