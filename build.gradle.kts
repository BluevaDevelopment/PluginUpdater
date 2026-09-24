plugins {
    kotlin("jvm") version "2.4.20"
    id("net.blueva.mawu") version "26.3"
    id("com.gradleup.shadow") version "9.6.1"
    application
}

group = "net.blueva"
version = providers.gradleProperty("version")
    .orElse(providers.environmentVariable("RELEASE_VERSION"))
    .get()

repositories {
    mavenCentral()
    maven("https://repo.blueva.net/releases")
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
    implementation("org.tomlj:tomlj:1.3.0")

    testImplementation(kotlin("test"))
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

mawu {
    // The primitives the Kotlin host installs before any script runs (see host/Host.kt).
    knownGlobals.addAll("use", "host", "term", "http", "fs", "zip", "json", "toml")
}

kotlin {
    jvmToolchain(21)
}

application {
    applicationName = "pluginupdater"
    mainClass.set("net.blueva.pluginupdater.PluginUpdaterKt")
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
    // The Lua suites under tests/network/ talk to the real stores, so they only run with -Pnetwork.
    systemProperty("pluginupdater.network", providers.gradleProperty("network").isPresent)
}
