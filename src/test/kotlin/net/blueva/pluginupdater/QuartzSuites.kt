/*
 * PluginUpdater
 * https://github.com/BluevaDevelopment/PluginUpdater
 *
 * Copyright (c) 2026 Blueva Development
 *
 * SPDX-License-Identifier: MIT
 */
package net.blueva.pluginupdater

import org.junit.jupiter.api.DynamicContainer
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import org.quartzlang.embed.EmbedLimits
import org.quartzlang.embed.Kits
import org.quartzlang.embed.QuartzEmbed
import java.nio.file.Files
import java.nio.file.Path

/**
 * Runs the Quartz tests: every `@test` function of the test module (src/test/quartz plus the program's own sources)
 * is one JUnit test in a fresh sandbox. Tests of a `network` package only run with -Pnetwork.
 */
class QuartzSuites {

    @TestFactory
    fun suites(): List<DynamicContainer> {
        val network = System.getProperty("pluginupdater.network").toBoolean()
        val root = Path.of("build", "quartz-test").toAbsolutePath().also(Files::createDirectories)
        val embed = QuartzEmbed.builder()
            .classLoader(QuartzSuites::class.java.classLoader)
            .grant(Kits.terminal(), Kits.http(), Kits.fileSystem(root), Kits.process(), Kits.archives(root))
            .limits(EmbedLimits.CLI)
            .build()
        val probe = embed.module("pluginupdater-test")
        val tests = probe.functions("test").map { it.function() }.filter { network || !it.contains(".network.") }
        probe.close()
        return tests.groupBy { it.substringBeforeLast('.') }.toSortedMap().map { (suite, names) ->
            DynamicContainer.dynamicContainer(suite, names.sorted().map { name ->
                DynamicTest.dynamicTest(name.substringAfterLast('.')) {
                    embed.module("pluginupdater-test").use { it.invoke(name) }
                }
            })
        }
    }
}
