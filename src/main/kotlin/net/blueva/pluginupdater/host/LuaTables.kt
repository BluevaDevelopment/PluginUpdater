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

/** Moving lists and maps of strings between Lua tables and Kotlin. */
object LuaTables {

    fun list(values: List<String>): LuaTable =
        LuaTable().also { table -> values.forEachIndexed { index, value -> table.set(index + 1, LuaValue.valueOf(value)) } }

    fun field(table: LuaValue, key: String): LuaValue = table.get(key) ?: LuaValue.NIL

    /** Every string key of a table with its value as a string; anything but a table is an empty map. */
    fun stringMap(value: LuaValue?): Map<String, String> {
        if (value == null || !value.istable()) return emptyMap()
        val map = LinkedHashMap<String, String>()
        var key: LuaValue = LuaValue.NIL
        while (true) {
            val next = value.next(key) ?: break
            key = next.arg1()
            if (key.isnil()) break
            map[key.tojstring()] = next.arg(2).tojstring()
        }
        return map
    }
}
