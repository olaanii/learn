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
