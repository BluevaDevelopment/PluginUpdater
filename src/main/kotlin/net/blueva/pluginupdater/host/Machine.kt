/*
 * PluginUpdater
 * https://github.com/BluevaDevelopment/PluginUpdater
 *
 * Copyright (c) 2026 Blueva Development
 *
 * SPDX-License-Identifier: MIT
 */

package net.blueva.pluginupdater.host

import org.quartzlang.embed.api.QuartzFunction
import java.nio.file.Files
import java.nio.file.Path
import java.security.MessageDigest
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/** What only the running machine knows: the clock, the working directory and pauses. */
object Machine {

    /** The working directory, absolute. */
    @QuartzFunction
    fun cwd(): String = Path.of("").toAbsolutePath().normalize().toString()

    /** The local date and time in a DateTimeFormatter pattern, such as `yyyy-MM-dd HH:mm`. */
    @QuartzFunction
    fun date(pattern: String): String = DateTimeFormatter.ofPattern(pattern).format(LocalDateTime.now())

    /** Waits, for the pause between attempts at a request. */
    @QuartzFunction
    fun sleep(milliseconds: Long) {
        Thread.sleep(milliseconds)
    }

    /** The hex digest of a file, streamed: `sha1`, `sha256`, `sha512` or `md5`. */
    @QuartzFunction
    fun digest(path: String, algorithm: String): String {
        val digest = MessageDigest.getInstance(algorithm.uppercase().replace("SHA", "SHA-"))
        Files.newInputStream(Path.of(path)).use { input ->
            val buffer = ByteArray(1 shl 16)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
