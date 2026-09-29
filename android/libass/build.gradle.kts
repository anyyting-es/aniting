import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// Static-linking the native core here avoids shipping a separate libass.so with
// different merge rules from the app.
plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
}

android {
  namespace = "com.edde746.plezy.libass"
  compileSdk = 35
  ndkVersion = "28.2.13676358"

  defaultConfig {
    minSdk = 21
    consumerProguardFiles("consumer-rules.pro")
    externalNativeBuild {
      cmake {
        arguments += listOf(
          "-DANDROID_STL=c++_shared",
          "-DLIBASS_CACHE_DIR=${layout.buildDirectory.get().asFile}/libass-prebuilt"
        )
      }
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  externalNativeBuild {
    cmake {
      path = file("src/main/cpp/CMakeLists.txt")
      version = "3.22.1"
    }
  }
}

kotlin {
  compilerOptions {
    jvmTarget.set(JvmTarget.JVM_17)
  }
}

dependencies {
  implementation("androidx.annotation:annotation:1.9.1")
  implementation("androidx.annotation:annotation-experimental:1.4.1")
  implementation("androidx.media3:media3-exoplayer:1.5.1")
  implementation("androidx.media3:media3-ui:1.5.1")
}
