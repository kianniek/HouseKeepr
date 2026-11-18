import java.io.File

plugins {
    id("com.android.dynamic-feature")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.kianhamidi.housekeepr.opengym"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    defaultConfig {
        minSdk = 24
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir(layout.buildDirectory.dir("generated/flutterJniLibs"))
        }
    }
}

dependencies {
    implementation(project(":app"))
}

val syncDeferredFlutterLibsRelease = tasks.register("syncDeferredFlutterLibsRelease") {
    dependsOn(":app:compileFlutterBuildRelease")

    val flutterReleaseDir = rootProject.layout.buildDirectory.dir("app/intermediates/flutter/release")
    val outJniDir = layout.buildDirectory.dir("generated/flutterJniLibs")
    val unitId = 2
    val targetLibName = "libapp.so-$unitId.so"
    val abis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")
    val unitPathRegex = Regex("\"id\"\\s*:\\s*$unitId\\s*,\\s*\"path\"\\s*:\\s*\"([^\"]+)\"")

    val pubspecFile = rootProject.file("../pubspec.yaml")
    val deferredEnabledRegex = Regex("(?m)^\\s*deferred-components\\s*:")

    outputs.dir(outJniDir)
    outputs.upToDateWhen { false }

    doLast {
        val baseOut = outJniDir.get().asFile
        if (baseOut.exists()) {
            baseOut.deleteRecursively()
        }
        if (!pubspecFile.exists() || !deferredEnabledRegex.containsMatchIn(pubspecFile.readText())) {
            return@doLast
        }
        for (abi in abis) {
            val manifestFile = flutterReleaseDir.get().file("$abi/manifest.json").asFile
            if (!manifestFile.exists()) continue

            val match = unitPathRegex.find(manifestFile.readText()) ?: continue
            val rawPath = match.groupValues[1].replace("\\\\", "\\")
            val sourceSo = File(rawPath)
            if (!sourceSo.exists()) {
                throw GradleException("Deferred Flutter library not found for $abi at: $rawPath")
            }

            val destDir = File(baseOut, abi)
            destDir.mkdirs()
            sourceSo.copyTo(File(destDir, targetLibName), overwrite = true)
        }
    }
}

tasks.matching { it.name == "mergeReleaseJniLibFolders" }.configureEach {
    dependsOn(syncDeferredFlutterLibsRelease)
}
