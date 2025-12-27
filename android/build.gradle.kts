buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.2")
        classpath("com.google.gms:google-services:4.4.4")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")

    // --- DÜZELTİLEN KISIM (Burayı değiştirdik) ---
    // Proje zaten değerlendirilmiş mi kontrol et
    if (project.state.executed) {
        // Zaten bitmişse direkt uygula
        applyNamespaceFix(project)
    } else {
        // Bitmemişse bitmesini bekle
        project.afterEvaluate {
            applyNamespaceFix(this)
        }
    }
}

// Bu fonksiyon eski paketlere otomatik kimlik (namespace) atar
fun applyNamespaceFix(project: Project) {
    val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
    if (android != null && android.namespace == null) {
        android.namespace = project.group.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}