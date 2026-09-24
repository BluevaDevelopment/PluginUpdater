--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- pluginupdater init: write a starting configuration.
local common = use('cli/common')
local errors = use('core/errors')
local ui = use('core/ui')
local writer = use('server/writer')

return {
  name = 'init',
  summary = 'Write a commented configuration file to start from',
  options = {
    common.CONFIG,
    { long = 'force', short = 'f', flag = true, help = 'Replace the file when it already exists' },
  },
  run = function(values)
    if fs:exists(values.config) and not values.force then
      errors.fail(values.config .. ' already exists; add --force to replace it')
    end
    fs:write(values.config, writer.TEMPLATE)
    ui.success('Wrote ' .. fs:absolute(values.config))
    ui.info("Add plugins under [plugins], or run 'pluginupdater detect --write' to add the ones installed.")
  end,
}
