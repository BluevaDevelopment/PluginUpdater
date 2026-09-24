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
import java.nio.file.Files
import java.nio.file.Path
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/** `zip`: reading entries out of jars, and writing small ones. */
class Archives {

    /** The names of every file entry, in archive order; empty when the file is not a readable zip. */
    fun entries(archive: String): LuaTable = runCatching {
        ZipFile(archive).use { zip -> LuaTables.list(zip.entries().asSequence().filterNot { it.isDirectory }.map { it.name }.toList()) }
    }.getOrElse { LuaTable() }

    /** The text of one entry, or null when the entry is missing or the file is not a readable zip. */
    fun read(archive: String, name: String): String? = runCatching {
        ZipFile(archive).use { zip -> zip.getEntry(name)?.let { entry -> zip.getInputStream(entry).use { String(it.readAllBytes()) } } }
    }.getOrNull()

    /** Writes a jar from entry names and their text content. */
    fun write(archive: String, entries: LuaTable) {
        val path = Path.of(archive)
        path.parent?.let(Files::createDirectories)
        ZipOutputStream(Files.newOutputStream(path)).use { zip ->
            for ((name, content) in LuaTables.stringMap(entries).toSortedMap()) {
                zip.putNextEntry(ZipEntry(name))
                zip.write(content.toByteArray())
                zip.closeEntry()
            }
        }
    }
}
