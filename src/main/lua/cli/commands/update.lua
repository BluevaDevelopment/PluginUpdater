--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- pluginupdater update: replace outdated plugins and write the changelog.
local common = use('cli/common')
local config = use('server/config')
local run = use('update/run')

return {
  name = 'update',
  summary = 'Replace outdated plugins with their newest builds and write the changelog',
  options = {
    common.CONFIG,
    { long = 'only', short = 'o', value = 'plugin', multiple = true, help = 'Only this plugin, by its name in the configuration. Repeatable' },
  },
  run = function(values)
    local loaded = config.load(values.config)
    local outcomes, changes = run.execute(loaded, { install = true, only = values.only })
    return run.summary(loaded, outcomes, changes or {}, true)
  end,
}
