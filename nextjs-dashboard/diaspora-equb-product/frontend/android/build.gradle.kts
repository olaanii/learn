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
subprojects {
    afterEvaluate {
        listOf("lintVitalAnalyzeRelease", "lintVitalReportRelease", "lintAnalyzeRelease").forEach { taskName ->
            tasks.findByName(taskName)?.let { it.enabled = false }
        }
    }
    tasks.whenTaskAdded {
        if (name == "lintVitalAnalyzeRelease" || name == "lintVitalReportRelease" || name == "lintAnalyzeRelease") {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
