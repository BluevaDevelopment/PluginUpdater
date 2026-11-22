import org.quartzlang.embed.gradle.QuartzSeverity
import org.gradle.api.file.SourceDirectorySet

plugins {
    kotlin("jvm") version "2.4.21"
    id("org.quartzlang.embed")
    id("com.gradleup.shadow") version "9.6.1"
    application
}

group = "net.blueva"
version = providers.gradleProperty("version")
    .orElse(providers.environmentVariable("RELEASE_VERSION"))
    .get()

dependencies {
    testImplementation(kotlin("test"))
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

kotlin {
    jvmToolchain(25)
}

quartz {
    hostPackage = "host"
    moduleName = "pluginupdater"
    warnings = QuartzSeverity.ERROR
}

// The tests see the program's own Quartz sources, so a test imports net.blueva.pluginupdater.* directly.
(sourceSets["test"].extensions.getByName("quartz") as SourceDirectorySet).srcDir("src/main/quartz")

application {
    applicationName = "pluginupdater"
    mainClass.set("net.blueva.pluginupdater.PluginUpdaterKt")
    applicationDefaultJvmArgs = listOf("--enable-native-access=ALL-UNNAMED")
}

// `./gradlew run` works on run/, a scratch server folder git ignores.
tasks.named<JavaExec>("run") {
    val directory = layout.projectDirectory.dir("run").asFile
    workingDir = directory
    doFirst { directory.mkdirs() }
}

// The jar users download: everything inside, runnable with `java -jar pluginupdater-<version>.jar`.
tasks.shadowJar {
    archiveBaseName.set("pluginupdater")
    archiveClassifier.set("")
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA", "META-INF/*.EC")
    mergeServiceFiles()
    filesMatching("META-INF/*.kotlin_module") { duplicatesStrategy = DuplicatesStrategy.INCLUDE }
    manifest { attributes("Main-Class" to "net.blueva.pluginupdater.PluginUpdaterKt", "Enable-Native-Access" to "ALL-UNNAMED") }
}

tasks.jar {
    // The thin jar only feeds installDist; keep its name apart from the one users get.
    archiveClassifier.set("thin")
}

tasks.build {
    dependsOn(tasks.shadowJar)
}

tasks.processResources {
    filesMatching("pluginupdater.properties") {
        expand("version" to project.version)
    }
}

tasks.test {
    useJUnitPlatform()
    jvmArgs("--enable-native-access=ALL-UNNAMED")
    // The suites under src/test/kotlin/.../network talk to the real stores, so they only run with -Pnetwork.
    systemProperty("pluginupdater.network", providers.gradleProperty("network").isPresent)
    providers.gradleProperty("quartz.library").orNull?.let { systemProperty("quartz.library", it) }
}
