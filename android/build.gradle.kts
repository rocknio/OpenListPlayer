allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// media_kit 系及部分设备能力插件（如 screen_brightness_android）Java 侧仍为 1.8，
// 与 app 及 audio_session 的 17 不一致，Gradle 9 的 JVM-target 校验会直接失败，统一强制到 17。
val unifiedJavaVersion = JavaVersion.VERSION_17
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            compileOptions {
                sourceCompatibility = unifiedJavaVersion
                targetCompatibility = unifiedJavaVersion
            }
            // 部分老插件默认 compileSdk 31，与 wakelock_plus 等要求 API 36 的插件冲突，统一提升到 36
            setCompileSdkVersion(36)
        }
    }
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
