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
import java.io.IOException
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.time.Duration

/** How a download ended: [status] is 0 when no answer came, and [failure] says why a file was refused. */
data class Download(
    val status: Long,
    val url: String?,
    val disposition: String?,
    val failure: String?,
)

/** Large files are streamed to disk and checked against a checksum, which the http kit's in-memory bodies do not do. */
object Downloads {

    private val client: HttpClient = HttpClient.newBuilder()
        .followRedirects(HttpClient.Redirect.NORMAL)
        .connectTimeout(Duration.ofSeconds(30))
        .build()

    private val digests = mapOf("md5" to "MD5", "sha1" to "SHA-1", "sha256" to "SHA-256", "sha512" to "SHA-512")

    /**
     * Downloads [url] into [target], which is only written when the answer is a success. With an [algorithm]
     * (`sha1`, `sha256`, `sha512` or `md5`) the file must match [hex], or it is discarded.
     */
    @QuartzFunction
    fun download(url: String, target: String, headers: Map<String, String>, algorithm: String?, hex: String?): Download {
        val destination = Path.of(target)
        var partial: Path? = null
        try {
            val request = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofMinutes(5)).GET()
            headers.forEach { (name, value) -> request.header(name, value) }
            val response = client.send(request.build(), HttpResponse.BodyHandlers.ofInputStream())
            val answer = Download(
                response.statusCode().toLong(),
                response.uri().toString(),
                response.headers().firstValue("Content-Disposition").orElse(null),
                null,
            )
            if (response.statusCode() !in 200..299) {
                response.body().close()
                return answer
            }
            destination.parent?.let(Files::createDirectories)
            // Unique, so two transfers of one file never share a partial file.
            partial = Files.createTempFile(destination.parent, destination.fileName.toString(), ".part")
            val digest = algorithm?.let {
                MessageDigest.getInstance(digests[it] ?: return answer.copy(failure = "unknown checksum '$it'"))
            }
            response.body().use { input ->
                Files.newOutputStream(partial).use { output ->
                    val buffer = ByteArray(1 shl 16)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        digest?.update(buffer, 0, read)
                    }
                }
            }
            if (digest != null) {
                val actual = digest.digest().joinToString("") { "%02x".format(it) }
                if (!actual.equals(hex, ignoreCase = true)) {
                    return answer.copy(failure = "the file does not match its $algorithm (expected $hex, got $actual)")
                }
            }
            Files.move(partial, destination, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
            return answer
        } catch (exception: IOException) {
            return Download(0, null, null, exception.message ?: exception.toString())
        } catch (exception: IllegalArgumentException) {
            return Download(0, null, null, exception.message ?: exception.toString())
        } finally {
            partial?.let { Files.deleteIfExists(it) }
        }
    }
}
