import com.android.build.gradle.BaseExtension
import org.gradle.api.JavaVersion
import org.gradle.api.plugins.JavaPluginExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force every subproject (including Flutter plugins like
// flutter_local_notifications) to compile to Java 11 bytecode. Without
// this, transitive plugin sources default to Java 8, which the modern
// JDK (17+) flags as obsolete: "source value 8 is obsolete and will
// be removed in a future release". Java 8 bytecode still runs on every
// Android device today, so the warning is purely future-proofing —
// but silencing it here keeps the build log clean and removes the risk
// that a future JDK actually drops the flag.
//
// We use the `withType<BaseExtension>` matcher so we cover both
// `com.android.application` (the app) and `com.android.library` (every
// plugin's android module) with a single block, regardless of which
// version of AGP is in play.
subprojects {
    plugins.withId("java") {
        extensions.configure(JavaPluginExtension::class.java) {
            sourceCompatibility = JavaVersion.VERSION_11
            targetCompatibility = JavaVersion.VERSION_11
        }
    }
    plugins.withType<com.android.build.gradle.AppPlugin>().configureEach {
        extensions.configure<BaseExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
    plugins.withType<com.android.build.gradle.LibraryPlugin>().configureEach {
        extensions.configure<BaseExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
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
