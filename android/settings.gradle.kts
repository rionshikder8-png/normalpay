pluginManagement {
    val flutterSdkPath = run {
        val localProperties = file("local.properties")
        val path = if (localProperties.exists()) {
            val lines = localProperties.readLines()
            lines.firstOrNull { it.startsWith("flutter.sdk=") }?.substringAfter("=")?.trim()
        } else {
            null
        }

        path ?: System.getenv("FLUTTER_ROOT") ?: run {
            throw GradleException("Flutter SDK not found. Check local.properties or FLUTTER_ROOT.")
        }
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "normal_pay_sms_reader"
include(":app")
