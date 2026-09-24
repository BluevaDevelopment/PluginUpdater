/*
 * PluginUpdater
 * https://github.com/BluevaDevelopment/PluginUpdater
 *
 * Copyright (c) 2026 Blueva Development
 *
 * SPDX-License-Identifier: MIT
 */
package net.blueva.pluginupdater.host

import net.blueva.luak.LuaValue
import java.io.IOException
import java.io.InputStream
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.time.Duration
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * `http`: requests and file transfers. Both run in the background, so a
 * script can keep several going while it waits on them.
 */
class Http {

    private val client: HttpClient = HttpClient.newBuilder()
        .followRedirects(HttpClient.Redirect.NORMAL)
        .connectTimeout(Duration.ofSeconds(30))
        .build()

    private var userAgent = "pluginupdater"

    /** Sent with every request; some APIs refuse generic agents. */
    fun userAgent(value: String) {
        userAgent = value
    }

    /** Starts a request; [headers] is a table of header names to values, [body] is sent as it is. */
    fun request(method: String, url: String, headers: LuaValue?, body: String?): Request {
        val request = Request()
        val built = build(method, url, LuaTables.stringMap(headers), body)
        Thread.ofVirtual().start { request.run(built) }
        return request
    }

    /**
     * Starts downloading [url] into [target]. With an [algorithm] (`sha1`,
     * `sha256`, `sha512`, `md5`) the file must match [hex], or it is discarded.
     * The file is only written when the answer is a success.
     */
    fun download(url: String, target: String, headers: LuaValue?, algorithm: String?, hex: String?): Transfer {
        val transfer = Transfer()
        val built = build("GET", url, LuaTables.stringMap(headers), null)
        Thread.ofVirtual().start { transfer.run(built, Path.of(target), algorithm, hex) }
        return transfer
    }

    /** What every pending call answers: whether it is over, and how it ended. */
    abstract class Pending internal constructor() {

        protected val done = CountDownLatch(1)

        @Volatile
        protected var answer: HttpResponse<*>? = null

        @Volatile
        protected var error: String? = null

        /** Waits up to [milliseconds]; true once the call is over, either way. */
        fun await(milliseconds: Int): Boolean = done.await(milliseconds.toLong(), TimeUnit.MILLISECONDS)

        /** The HTTP status, or 0 when no answer came. */
        fun status(): Int = answer?.statusCode() ?: 0

        /** The first value of a response header, or null. */
        fun header(name: String): String? = answer?.headers()?.firstValue(name)?.orElse(null)

        /** The address that answered, after redirects. */
        fun url(): String? = answer?.uri()?.toString()

        /** Why no answer came, or why the answer was refused, or null. */
        fun failure(): String? = error
    }

    inner class Request internal constructor() : Pending() {

        @Volatile
        private var body: String? = null

        fun text(): String? = body

        internal fun run(request: HttpRequest) {
            try {
                val response = send(request, HttpResponse.BodyHandlers.ofString())
                answer = response
                body = response.body()
            } catch (exception: Exception) {
                error = exception.message ?: exception.toString()
            } finally {
                done.countDown()
            }
        }
    }

    inner class Transfer internal constructor() : Pending() {

        @Volatile
        private var received = 0L

        fun received(): Long = received

        /** The size the server announced, or -1. */
        fun total(): Long = answer?.headers()?.firstValueAsLong("Content-Length")?.orElse(-1) ?: -1

        internal fun run(request: HttpRequest, target: Path, algorithm: String?, hex: String?) {
            var partial: Path? = null
            try {
                val response = send(request, HttpResponse.BodyHandlers.ofInputStream())
                answer = response
                if (response.statusCode() !in 200..299) {
                    response.body().close()
                    return
                }
                Files.createDirectories(target.parent)
                // Unique, so two transfers of one file never share a partial file.
                partial = Files.createTempFile(target.parent, target.fileName.toString(), ".part")
                val digest = algorithm?.let { MessageDigest.getInstance(DIGESTS[it] ?: error("Unknown checksum '$it'")) }
                copy(response.body(), partial, digest)
                if (digest != null) {
                    val actual = digest.digest().joinToString("") { "%02x".format(it) }
                    if (!actual.equals(hex, ignoreCase = true)) {
                        error = "the file does not match its $algorithm (expected $hex, got $actual)"
                        return
                    }
                }
                Files.move(partial, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
            } catch (exception: Exception) {
                error = exception.message ?: exception.toString()
            } finally {
                partial?.let { Files.deleteIfExists(it) }
                done.countDown()
            }
        }

        private fun copy(body: InputStream, target: Path, digest: MessageDigest?) {
            body.use { input ->
                Files.newOutputStream(target).use { output ->
                    val buffer = ByteArray(1 shl 16)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        digest?.update(buffer, 0, read)
                        received += read
                    }
                }
            }
        }
    }

    private fun build(method: String, url: String, headers: Map<String, String>, body: String?): HttpRequest {
        val builder = HttpRequest.newBuilder(URI.create(url))
            .header("User-Agent", userAgent)
            .timeout(Duration.ofMinutes(5))
            .method(method, body?.let(HttpRequest.BodyPublishers::ofString) ?: HttpRequest.BodyPublishers.noBody())
        headers.forEach { (name, value) -> builder.header(name, value) }
        return builder.build()
    }

    /** Sends [request], trying again when the connection fails or the server is briefly unavailable. */
    private fun <T> send(request: HttpRequest, handler: HttpResponse.BodyHandler<T>): HttpResponse<T> {
        var failure: IOException? = null
        for (attempt in 1..ATTEMPTS) {
            try {
                val response = client.send(request, handler)
                if (response.statusCode() !in RETRIED || attempt == ATTEMPTS) return response
                (response.body() as? InputStream)?.close()
            } catch (exception: IOException) {
                failure = exception
            }
            Thread.sleep(PAUSE * attempt)
        }
        throw IOException("could not reach ${request.uri()}: ${failure?.message}", failure)
    }

    private companion object {
        const val ATTEMPTS = 3
        const val PAUSE = 1000L
        val RETRIED = setOf(429, 502, 503, 504)
        val DIGESTS = mapOf("md5" to "MD5", "sha1" to "SHA-1", "sha256" to "SHA-256", "sha512" to "SHA-512")
    }
}
