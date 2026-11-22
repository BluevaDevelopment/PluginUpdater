pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
    // Embed is not published yet: it is built from a checkout, the sibling clone by default.
    includeBuild(providers.gradleProperty("quartz.embed").getOrElse("../Embed"))
}

includeBuild(providers.gradleProperty("quartz.embed").getOrElse("../Embed"))

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

rootProject.name = "pluginupdater"
