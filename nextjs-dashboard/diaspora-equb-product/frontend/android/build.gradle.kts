allprojects {
    repositories {
        google()
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "sentry_flutter") {
        tasks.matching { it.name.contains("compile", ignoreCase = true) && it.name.contains("Kotlin", ignoreCase = true) }.configureEach {
            val kotlinCompileClass = try {
                Class.forName("org.jetbrains.kotlin.gradle.tasks.KotlinCompile")
            } catch (_: Throwable) {
                null
            }
            if (kotlinCompileClass != null && kotlinCompileClass.isInstance(this)) {
                val getCompilerOptions = kotlinCompileClass.getMethod("getCompilerOptions")
                val compilerOptions = getCompilerOptions.invoke(this)
                val kotlinVersionClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.KotlinVersion")
                val getLanguageVersion = compilerOptions.javaClass.getMethod("getLanguageVersion")
                val getApiVersion = compilerOptions.javaClass.getMethod("getApiVersion")
                val languageVersionProperty = getLanguageVersion.invoke(compilerOptions)
                val apiVersionProperty = getApiVersion.invoke(compilerOptions)
                val setMethod = languageVersionProperty.javaClass.getMethod("set", Any::class.java)
                val kotlin18 = kotlinVersionClass.getField("KOTLIN_1_8").get(null)
                setMethod.invoke(languageVersionProperty, kotlin18)
                setMethod.invoke(apiVersionProperty, kotlin18)
            }
        }
    }
}
// Disable lint release tasks on all subprojects (app + plugins) to avoid
// BuiltinIssueRegistry / PsiMember errors with some Flutter plugin AGP versions.
// Register before evaluation so afterEvaluate is valid (Gradle 8.x can evaluate subprojects early).
gradle.beforeProject(org.gradle.api.Action<org.gradle.api.Project> {
    if (this != rootProject) {
        afterEvaluate {
            listOf("lintVitalAnalyzeRelease", "lintVitalReportRelease", "lintAnalyzeRelease").forEach { taskName ->
                tasks.findByName(taskName)?.let { it.enabled = false }
            }
        }
        tasks.whenTaskAdded(org.gradle.api.Action<org.gradle.api.Task> {
            if (name == "lintVitalAnalyzeRelease" || name == "lintVitalReportRelease" || name == "lintAnalyzeRelease") {
                enabled = false
            }
        })
    }
})

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
