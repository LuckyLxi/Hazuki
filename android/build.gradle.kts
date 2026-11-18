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
            // Flutter 3.50 会用 initWith 把 app 的 profile 构建类型复制给插件库，
            // 连带复制 applicationIdSuffix，AGP 9 会拒绝库模块设置该属性。
            // 预先按 Flutter 自身的方式创建库的 profile，Flutter 检测到已存在后就跳过复制。
            if (ext.buildTypes.findByName("profile") == null) {
                ext.buildTypes.create("profile") {
                    initWith(ext.buildTypes.getByName("debug"))
                    matchingFallbacks.clear()
                    matchingFallbacks.addAll(listOf("debug", "release"))
                }
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
