--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- pluginupdater detect: find where the installed plugins are published, and
-- optionally add them to the configuration.
local common = use('cli/common')
local config = use('server/config')
local detect = use('detect/detect')
local errors = use('core/errors')
local installed = use('server/installed')
local system = use('core/system')
local text = use('core/text')
local ui = use('core/ui')
local writer = use('server/writer')

local function describe(result)
  if result.error then return ui.style('error: ' .. result.error, '31') end
  local match = result.match
  if not match then return ui.style('not found', '2') end
  local how, color = 'by name     ', '33'
  if match.exact then how, color = 'same file   ', '32'
  elseif match.confirmed then how, color = 'same plugin ', '32'
  elseif match.other then how, color = 'other plugin', '31' end
  local line = ui.style(how, color) .. '  ' .. match.link
  if match.note then line = line .. '  (' .. match.note .. ')' end
  return line
end

local function show(entry, configured)
  local plugin = entry.plugin
  local head = ui.style(plugin.name, '1') .. ' ' .. (plugin.version or '?') .. '  ' .. ui.style(plugin.fileName, '2')
  if configured then head = head .. '  ' .. ui.style('[configured]', '36') end
  ui.say(head)
  for _, name in ipairs(detect.SHOWN) do
    ui.info(ui.pad(name, 11) .. '  ' .. describe(entry.found[name]))
  end
end

-- The entries to add for what was found and is not configured yet.
local function additions(list, configured)
  local blocks, names = {}, {}
  for _, entry in ipairs(list) do
    if entry.match and not configured[text.key(entry.plugin.name)] then
      local fields = { { 'url', entry.match.link } }
      if entry.match.asset then fields[2] = { 'asset', entry.match.asset } end
      blocks[#blocks + 1] = writer.entry(entry.plugin.name, fields)
      names[#names + 1] = entry.plugin.name
    end
  end
  return blocks, names
end

return {
  name = 'detect',
  summary = 'Find the installed plugins in every store, and say where each one is and is not',
  options = {
    common.CONFIG,
    { long = 'write', short = 'w', flag = true, help = 'Add what was found to the configuration, writing it when there is none' },
    { long = 'plugins', short = 'p', value = 'folder', help = 'The plugins folder, when there is no configuration yet. Defaults to plugins' },
  },
  run = function(values)
    local loaded = fs:isFile(values.config) and config.load(values.config) or nil
    local folder = (values.plugins and fs:absolute(values.plugins)) or (loaded and loaded.pluginsFolder) or fs:absolute('plugins')
    if not fs:isDirectory(folder) then errors.fail('there is no plugins folder at ' .. folder .. '; point to it with --plugins') end

    local context = {
      platform = loaded and loaded.platform or 'paper',
      channel = loaded and loaded.channel or 'release',
      minecraft = loaded and loaded.minecraft,
      tokens = loaded and loaded.tokens or { github = system.env('GITHUB_TOKEN'), curseforge = system.env('CURSEFORGE_API_KEY') },
    }
    local configured = {}
    for _, entry in ipairs(loaded and loaded.plugins or {}) do configured[text.key(entry.name)] = true end

    local plugins, others = {}, {}
    for _, plugin in ipairs(installed.scan(folder)) do
      if plugin.name then plugins[#plugins + 1] = plugin else others[#others + 1] = plugin.fileName end
    end
    if #plugins == 0 then
      ui.say('There are no plugin jars in ' .. folder .. '.')
      return
    end

    ui.step('Looking for ' .. #plugins .. ' plugin' .. (#plugins == 1 and '' or 's') .. ' in ' .. #detect.SHOWN .. ' stores')
    local counter = ui.counter('Searching')
    local list = detect.run(plugins, context, loaded and loaded.parallel or 8, counter.set)
    counter.close()

    local missing = {}
    for _, entry in ipairs(list) do
      ui.say('')
      show(entry, configured[text.key(entry.plugin.name)])
      if entry.match then ui.info(ui.pad('', 11) .. '  -> ' .. entry.match.link) end
      if not entry.match then missing[#missing + 1] = entry.plugin.name end
    end
    ui.say('')

    ui.success('Found ' .. (#list - #missing) .. ' of ' .. #list .. ' plugins in at least one store')
    if #missing > 0 then ui.info('Not found anywhere, or only plugins with the same name: ' .. table.concat(missing, ', ')) end
    ui.detail("'same file': the store has this exact jar. 'same plugin': its newest jar has the same main class."
      .. " 'by name' alone is not trusted.")
    if #others > 0 then ui.info('Not plugins (no plugin.yml): ' .. table.concat(others, ', ')) end

    local blocks, names = additions(list, configured)
    if #blocks == 0 then
      if values.write then ui.info('Nothing new to add to ' .. values.config) end
      return
    end
    if not values.write then
      ui.info("Run 'pluginupdater detect --write' to add " .. #blocks .. ' of them to ' .. values.config)
      return
    end
    local existing = fs:isFile(values.config) and fs:read(values.config) or nil
    if not existing and values.plugins then
      existing = writer.TEMPLATE:gsub('plugins%-folder = "plugins"', 'plugins-folder = ' .. writer.string(values.plugins))
    end
    fs:write(values.config, writer.add(existing, blocks))
    ui.success('Added ' .. table.concat(names, ', ') .. ' to ' .. fs:absolute(values.config))
  end,
}
