package net.blueva.pluginupdater

import net.blueva.pluginupdater.host.Workers
import org.quartzlang.embed.EmbedLimits
import org.quartzlang.embed.Kits
import org.quartzlang.embed.QuartzEmbed
import java.nio.file.Path
import kotlin.system.exitProcess

/** Runs the `pluginupdater` Quartz module: everything PluginUpdater decides is written there. */
fun main(args: Array<String>) {
    val workers = Workers("pluginupdater")
    val embed = QuartzEmbed.builder()
        .classLoader(Thread.currentThread().contextClassLoader)
        .grant(Kits.terminal(), Kits.http(), Kits.fileSystem(Path.of("."), Kits.argumentPaths(*args)), Kits.process(*args))
        .limits(EmbedLimits.CLI)
        .host(workers)
        .build()
    workers.embed = embed
    exitProcess(embed.module("pluginupdater").use { it.runMain() })
}
