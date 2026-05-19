import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        // 优先使用阿里云镜像源加速国内 Gradle 库依赖的下载
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
}

subprojects {
    plugins.withId("com.android.library") {
        extensions.findByType(LibraryExtension::class.java)?.let { ext ->
            if (ext.namespace == null) {
                ext.namespace = "com.lxi.hazuki.generated.${project.name.replace('-', '_')}"
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects { project.evaluationDependsOn(":app") }

tasks.register<Delete>("clean") { delete(rootProject.layout.buildDirectory) }
