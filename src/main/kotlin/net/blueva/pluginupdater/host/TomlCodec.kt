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
import net.blueva.luak.LuaValue
import org.tomlj.Toml
import org.tomlj.TomlArray
import org.tomlj.TomlTable

/** `toml`: TOML text to Lua tables. */
class TomlCodec {

    /** The document as a table; a syntax error fails with every problem and where it is. */
    fun decode(text: String): LuaValue {
        val result = Toml.parse(text)
        if (result.hasErrors()) {
            throw IllegalArgumentException(result.errors().joinToString("; ") { error ->
                val position = error.position()
                if (position != null) "line ${position.line()}, column ${position.column()}: ${error.message}" else error.message ?: "invalid TOML"
            })
        }
        return table(result)
    }

    private fun table(table: TomlTable): LuaTable = LuaTable().also { lua ->
        for (key in table.keySet()) lua.set(key, value(table.get(listOf(key))))
    }

    private fun value(value: Any?): LuaValue = when (value) {
        null -> LuaValue.NIL
        is TomlTable -> table(value)
        is TomlArray -> LuaTable().also { lua -> for (index in 0 until value.size()) lua.set(index + 1, value(value.get(index))) }
        is String -> LuaValue.valueOf(value)
        is Boolean -> if (value) LuaValue.TRUE else LuaValue.FALSE
        is Long -> LuaValue.valueOf(value)
        is Double -> LuaValue.valueOf(value)
        else -> LuaValue.valueOf(value.toString())
    }
}
