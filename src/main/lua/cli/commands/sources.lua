--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- pluginupdater sources: the stores and the links each one understands.
local stores = use('core/stores')
local ui = use('core/ui')

return {
  name = 'sources',
  summary = 'List the stores plugins can come from, with the links they take',
  run = function()
    local width = 0
    for _, store in ipairs(stores.all()) do width = math.max(width, #store.name) end
    for _, store in ipairs(stores.all()) do
      ui.say(ui.pad(store.name, width) .. '  ' .. ui.pad(store.label, 12) .. '  ' .. store.example)
    end
  end,
}
