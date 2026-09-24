--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- pluginupdater check: what update would do, without changing anything.
local common = use('cli/common')
local config = use('server/config')
local run = use('update/run')

return {
  name = 'check',
  summary = 'Show which plugins have newer builds, without installing them',
  options = {
    common.CONFIG,
    { long = 'only', short = 'o', value = 'plugin', multiple = true, help = 'Only this plugin, by its name in the configuration. Repeatable' },
  },
  run = function(values)
    local loaded = config.load(values.config)
    local outcomes, changes = run.execute(loaded, { install = false, only = values.only })
    return run.summary(loaded, outcomes, changes or {}, false)
  end,
}
