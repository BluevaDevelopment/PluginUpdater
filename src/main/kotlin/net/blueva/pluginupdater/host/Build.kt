package net.blueva.pluginupdater.host

import org.quartzlang.embed.api.QuartzFunction
import java.util.Properties

object Build {
    private val version: String by lazy {
        val properties = Properties()
        Build::class.java.classLoader.getResourceAsStream("pluginupdater.properties")?.use(properties::load)
        properties.getProperty("version") ?: "dev"
    }

    /** The version this build carries. */
    @QuartzFunction
    fun version(): String = version
}
