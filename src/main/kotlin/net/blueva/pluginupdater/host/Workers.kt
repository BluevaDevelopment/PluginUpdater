/*
 * PluginUpdater
 * https://github.com/BluevaDevelopment/PluginUpdater
 *
 * Copyright (c) 2026 Blueva Development
 *
 * SPDX-License-Identifier: MIT
 */
package net.blueva.pluginupdater.host

import org.quartzlang.embed.QuartzEmbed
import org.quartzlang.embed.api.QuartzFunction
import org.quartzlang.embed.api.QuartzHandle
import org.quartzlang.jvm.Result
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Work in flight: the same Quartz function run over many text inputs, a few at a time. */
@QuartzHandle
class Job internal constructor(private val total: Int) {

    private val finished = AtomicInteger()
    private val answers = arrayOfNulls<Result<String, String>>(total)
    private val over = CountDownLatch(total)

    internal fun complete(index: Int, answer: Result<String, String>) {
        answers[index] = answer
        finished.incrementAndGet()
        over.countDown()
    }

    /** How many inputs are done. */
    @QuartzFunction
    fun done(): Long = finished.get().toLong()

    @QuartzFunction
    fun total(): Long = total.toLong()

    /** Waits up to [milliseconds], less when everything finishes. */
    @QuartzFunction
    fun waitFor(milliseconds: Long) {
        over.await(milliseconds, TimeUnit.MILLISECONDS)
    }

    /** One answer per input, in order; an error says why a call trapped. */
    @QuartzFunction
    fun results(): List<Result<String, String>> {
        over.await()
        return answers.map { it!! }
    }
}

/**
 * Runs a function of the Quartz module on worker threads. A sandbox is used by one thread at a time, so each worker
 * opens its own; what crosses is text, which the module encodes and decodes itself.
 */
class Workers(private val moduleId: String) {

    lateinit var embed: QuartzEmbed

    /** Starts [function] over [inputs], at most [limit] at once, and returns at once. */
    @QuartzFunction
    fun startJob(function: String, inputs: List<String>, limit: Long): Job {
        val job = Job(inputs.size)
        val next = AtomicInteger()
        repeat(minOf(limit.toInt().coerceAtLeast(1), inputs.size)) {
            Thread.ofPlatform().daemon().start {
                runCatching { embed.module(moduleId) }.fold(
                    onSuccess = { module -> module.use { work(it, function, inputs, next, job) } },
                    onFailure = { failure -> drain(inputs, next, job, failure) },
                )
            }
        }
        return job
    }

    private fun work(module: org.quartzlang.embed.QuartzModule, function: String, inputs: List<String>, next: AtomicInteger, job: Job) {
        while (true) {
            val index = next.getAndIncrement()
            if (index >= inputs.size) return
            job.complete(
                index,
                try {
                    Result.ok(module.invoke(function, inputs[index]) as String)
                } catch (failure: Exception) {
                    Result.err(failure.message ?: failure.toString())
                },
            )
        }
    }

    private fun drain(inputs: List<String>, next: AtomicInteger, job: Job, failure: Throwable) {
        while (true) {
            val index = next.getAndIncrement()
            if (index >= inputs.size) return
            job.complete(index, Result.err(failure.message ?: failure.toString()))
        }
    }
}
