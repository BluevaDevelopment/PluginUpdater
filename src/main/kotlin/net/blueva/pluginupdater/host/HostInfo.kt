/*
 * PluginUpdater
 * https://github.com/BluevaDevelopment/PluginUpdater
 *
 * Copyright (c) 2026 Blueva Development
 *
 * SPDX-License-Identifier: MIT
 */
package net.blueva.pluginupdater.host

import net.blueva.luak.LuaTable
import net.blueva.mawu.runtime.MawuScripts
import java.util.Properties

/** `host`: what only the running build knows about itself. */
class HostInfo(private val classLoader: ClassLoader) {

    private val version: String by lazy {
        val properties = Properties()
        classLoader.getResourceAsStream("pluginupdater.properties")?.use(properties::load)
        properties.getProperty("version") ?: "dev"
    }

    /** The version this build carries, expanded into `pluginupdater.properties` at build time. */
    fun version(): String = version

    /** The ids of the compiled scripts under [prefix], such as every `sources/` script. */
    fun scripts(prefix: String): LuaTable = LuaTables.list(MawuScripts.ids(classLoader).filter { it.startsWith(prefix) }.sorted())
}
