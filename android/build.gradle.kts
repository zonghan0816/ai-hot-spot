import com.android.build.api.dsl.CommonExtension

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

    // Defer configuration until after project evaluation.
    afterEvaluate {
        // Find the 'android' extension and configure it only if it exists.
        project.extensions.findByName("android")?.let { androidExtension ->
            // Safely cast to CommonExtension and configure.
            if (androidExtension is CommonExtension<*, *, *, *, *, *>) {
                androidExtension.compileSdk = 36
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
