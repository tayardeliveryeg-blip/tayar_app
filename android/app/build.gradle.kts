import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ====== بيقرأ بيانات توقيع الإصدار (release signing) من android/key.properties
// اللي هو ملف محلي مش متتبع في git (موجود في .gitignore أصلاً). لو الملف مش
// موجود (زي بيئة CI أو جهاز مطور جديد لسه معملش الـ keystore)، بيرجع تلقائيًا
// لتوقيع الـ debug عشان الـ build يفضل شغال بدون كسر أي حاجة ======
val keystorePropertiesFile = rootProject.file("app/key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tayar.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.tayar.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // ====== R8 صريح: تصغير + obfuscation + إزالة الموارد غير المستخدمة.
            // الـ mapping بيترفع تلقائي لـ Crashlytics عبر الـ gradle plugin ======
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // ====== لو key.properties موجود بيستخدم توقيع الإصدار الحقيقي،
            // لو مش موجود بيرجع مؤقتًا لتوقيع الـ debug (عشان الـ build مايفشلش) ======
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// ====== أي build إصدار (assemble/bundle Release) من غير key.properties
// بيفشل بدل ما يتوقّع بصمت بمفتاح الـ debug (APK/AAB بالتوقيع ده مرفوض في
// Play Console، وأسوأ - ممكن يتسلّم بالغلط). للتجارب المحلية بس:
//   flutter build apk --release -PallowDebugSigning=true ======
gradle.taskGraph.whenReady {
    val isReleaseBuild = allTasks.any {
        (it.name.startsWith("assemble") || it.name.startsWith("bundle")) &&
            it.name.endsWith("Release")
    }
    if (isReleaseBuild && !hasKeystoreProperties &&
        !project.hasProperty("allowDebugSigning")
    ) {
        throw GradleException(
            "android/app/key.properties مش موجود - مينفعش نبني release " +
                "بتوقيع debug. اعمل الـ keystore أو استخدم " +
                "-PallowDebugSigning=true للتجارب المحلية بس.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}