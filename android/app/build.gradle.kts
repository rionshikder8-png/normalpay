import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "store.adverune.aps"
    compileSdk = 36
    ndkVersion = "27.0.12077973"
    
    compileOptions { 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17 
    }
    
    kotlinOptions { 
        jvmTarget = JavaVersion.VERSION_17.toString() 
    }
    
    defaultConfig {
        applicationId = "store.adverune.aps"
        minSdk = 23
        targetSdk = 35
        versionCode = 2
        versionName = "2.0.0"
    }

    signingConfigs {
        create("release") {
            if (keyProps.getProperty("storeFile") != null) {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter { source = "../.." }

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.10.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}
