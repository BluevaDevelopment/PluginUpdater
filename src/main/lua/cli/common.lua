--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Options more than one command takes.
local config = use('server/config')

local common = {}

common.CONFIG = {
  long = 'config', short = 'c', value = 'file', default = config.FILE,
  help = 'The configuration file, in the server folder. Defaults to ' .. config.FILE,
}

return common
