/*
 * PluginUpdater
 * https://github.com/BluevaDevelopment/PluginUpdater
 *
 * Copyright (c) 2026 Blueva Development
 *
 * SPDX-License-Identifier: MIT
 */
package net.blueva.pluginupdater

import net.blueva.mawu.runtime.MawuScripts
import net.blueva.pluginupdater.host.Host
import net.blueva.pluginupdater.host.LuaTables
import org.junit.jupiter.api.DynamicContainer
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory

/**
 * Runs the Lua test suites: every script under `src/test/lua/tests/` returns
 * a table of test functions, and each function is one JUnit test. A suite
 * under `tests/network/` only runs with `-Pnetwork`.
 */
class LuaSuites {

    @TestFactory
    fun suites(): List<DynamicContainer> {
        val loader = LuaSuites::class.java.classLoader
        val network = System.getProperty("pluginupdater.network").toBoolean()
        return MawuScripts.ids(loader)
            .filter { it.startsWith("tests/") && (network || !it.startsWith("tests/network/")) }
            .sorted()
            .map { id ->
                val lane = Host.lane(loader)
                val runner = lane.run("support/runner")
                val suite = lane.run(id)
                val tests = LuaTables.stringMap(suite).keys.sorted().map { name ->
                    DynamicTest.dynamicTest(name) { lane.callFunction(runner, LuaTables.field(suite, name)) }
                }
                DynamicContainer.dynamicContainer(id, tests)
            }
    }
}
