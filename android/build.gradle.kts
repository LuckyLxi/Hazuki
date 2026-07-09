import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
        // 国内环境无法访问官方仓库时，使用阿里云镜像作为回退。
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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
    val newSubprojectBuildDir: Directory =
        if (project.projectDir.toPath().root == rootProject.projectDir.toPath().root) {
            newBuildDir.dir(project.name)
        } else {
            project.layout.projectDirectory.dir("build")
        }
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects { project.evaluationDependsOn(":app") }

tasks.register<Delete>("clean") { delete(rootProject.layout.buildDirectory) }
