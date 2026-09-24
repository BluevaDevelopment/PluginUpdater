/*
 * PluginUpdater
 * https://github.com/BluevaDevelopment/PluginUpdater
 *
 * Copyright (c) 2026 Blueva Development
 *
 * SPDX-License-Identifier: MIT
 */
package net.blueva.pluginupdater

import net.blueva.pluginupdater.host.Host
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    exitProcess(Host.run(args.toList()))
}
