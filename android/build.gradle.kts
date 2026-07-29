allprojects {
    repositories {
        
        maven { url = uri("https://maven.aliyun.com/nexus/content/groups/public/") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        mavenCentral()
        google()
    }
}
buildscript {
    repositories {
 		maven{ url = uri("https://maven.aliyun.com/nexus/content/groups/public/") }
		mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Fix inconsistent JVM target compatibility for plugins
    afterEvaluate {
        val androidExtension = project.extensions.findByType(
            com.android.build.gradle.BaseExtension::class.java
        )
        if (androidExtension != null) {
            androidExtension.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            // 将 CMake 的 .cxx 缓存目录重定向到项目 build 目录，
            // 避免向 pub cache 中的只读包目录写入（AGP 8.x 默认在模块源码目录创建 .cxx）。
            try {
                val nativeBuild = androidExtension.externalNativeBuild
                val cmake = nativeBuild?.cmake
                if (cmake != null && cmake.path != null) {
                    cmake.buildStagingDirectory =
                        file("${rootProject.layout.buildDirectory.get()}/cxx/${project.name}")
                }
            } catch (e: Exception) {
                // 忽略不支持 externalNativeBuild 的模块
            }
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java) {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
