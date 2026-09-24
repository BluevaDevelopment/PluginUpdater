--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- pluginupdater.toml: where the plugins are, and where each one comes from.
local errors = use('core/errors')
local stores = use('core/stores')
local system = use('core/system')

local config = {}

config.FILE = 'pluginupdater.toml'

local PLATFORMS = { paper = true, velocity = true, waterfall = true }
local CHANNELS = { release = true, beta = true, alpha = true }

-- Each setting with its default and the type it must have.
local SETTINGS = {
  ['plugins-folder'] = { default = 'plugins', type = 'string' },
  changelog = { default = 'changelog.md', type = 'string' },
  platform = { default = 'paper', type = 'string', allowed = PLATFORMS },
  channel = { default = 'release', type = 'string', allowed = CHANNELS },
  minecraft = { type = 'string' },
  backups = { default = 5, type = 'number' },
  ['allow-downgrade'] = { default = false, type = 'boolean' },
  parallel = { default = 8, type = 'number' },
}

local ENTRY = {
  url = 'string', channel = 'string', asset = 'string', file = 'string',
  enabled = 'boolean', ['allow-downgrade'] = 'boolean',
}

local function keys(allowed)
  local list = {}
  for key in pairs(allowed) do list[#list + 1] = key end
  table.sort(list)
  return table.concat(list, ', ')
end

local function check(file, where, value, kind, allowed)
  if type(value) ~= kind then errors.fail(file .. ': ' .. where .. ' must be a ' .. kind) end
  if allowed and not allowed[value] then
    errors.fail(file .. ': ' .. where .. " can't be '" .. value .. "' (choose from " .. keys(allowed) .. ')')
  end
end

-- A path from the file, relative to the server's folder.
local function under(root, path)
  if path:sub(1, 1) == '/' or path:match('^%a:[\\/]') then return path end
  return fs:join(root, path)
end

local function entry(file, name, raw, settings)
  local where = 'plugins.' .. name
  if type(raw) == 'string' then raw = { url = raw } end
  if type(raw) ~= 'table' then errors.fail(file .. ': ' .. where .. ' must be a link or a table') end
  for key, value in pairs(raw) do
    if not ENTRY[key] then errors.fail(file .. ': ' .. where .. " has no setting '" .. key .. "' (known: " .. keys(ENTRY) .. ')') end
    check(file, where .. '.' .. key, value, ENTRY[key], key == 'channel' and CHANNELS or nil)
  end
  if not raw.url then errors.fail(file .. ': ' .. where .. ' needs a url') end
  local store, ref = stores.resolve(raw.url)
  if not store then
    errors.fail(file .. ': ' .. where .. ": no store understands '" .. raw.url .. "'. See 'pluginupdater sources'.")
  end
  local allowDowngrade = raw['allow-downgrade']
  if allowDowngrade == nil then allowDowngrade = settings['allow-downgrade'] end
  return {
    name = name,
    url = raw.url,
    store = store,
    ref = ref,
    channel = raw.channel or settings.channel,
    asset = raw.asset,
    file = raw.file,
    enabled = raw.enabled ~= false,
    allowDowngrade = allowDowngrade,
  }
end

-- Reads and checks a configuration, from the text of the file at path.
function config.parse(path, source)
  local file = fs:name(path)
  local document = errors.context(file, function() return toml:decode(source) end)
  for key in pairs(document) do
    if key ~= 'settings' and key ~= 'tokens' and key ~= 'plugins' then
      errors.fail(file .. ": unknown section '" .. key .. "' (known: plugins, settings, tokens)")
    end
  end

  local settings = {}
  for key, value in pairs(document.settings or {}) do
    local setting = SETTINGS[key]
    if not setting then errors.fail(file .. ": unknown setting '" .. key .. "' (known: " .. keys(SETTINGS) .. ')') end
    check(file, 'settings.' .. key, value, setting.type, setting.allowed)
    settings[key] = value
  end
  for key, setting in pairs(SETTINGS) do
    if settings[key] == nil then settings[key] = setting.default end
  end

  local tokens = document.tokens or {}
  for key, value in pairs(tokens) do
    if key ~= 'github' and key ~= 'curseforge' then errors.fail(file .. ": unknown token '" .. key .. "' (known: curseforge, github)") end
    check(file, 'tokens.' .. key, value, 'string')
  end

  local plugins = {}
  for name, raw in pairs(document.plugins or {}) do plugins[#plugins + 1] = entry(file, name, raw, settings) end
  table.sort(plugins, function(a, b) return a.name:lower() < b.name:lower() end)

  local root = fs:parent(fs:absolute(path)) or system.cwd()
  return {
    path = fs:absolute(path),
    root = root,
    pluginsFolder = under(root, settings['plugins-folder']),
    changelog = under(root, settings.changelog),
    data = fs:join(root, '.pluginupdater'),
    platform = settings.platform,
    channel = settings.channel,
    minecraft = settings.minecraft,
    backups = math.floor(settings.backups),
    parallel = math.floor(settings.parallel),
    tokens = {
      github = (tokens.github ~= '' and tokens.github) or system.env('GITHUB_TOKEN'),
      curseforge = (tokens.curseforge ~= '' and tokens.curseforge) or system.env('CURSEFORGE_API_KEY'),
    },
    plugins = plugins,
  }
end

-- The configuration at path; fails with a hint when there is none.
function config.load(path)
  if not fs:isFile(path) then
    errors.fail('there is no ' .. path .. ". Run 'pluginupdater init' to write one, or 'pluginupdater detect --write' to fill it from the plugins you have.")
  end
  return config.parse(path, fs:read(path))
end

-- What a store needs to pick a build for one entry.
function config.context(loaded, entry)
  return {
    entry = entry,
    name = entry.name,
    root = loaded.root,
    platform = loaded.platform,
    channel = entry.channel,
    minecraft = loaded.minecraft,
    tokens = loaded.tokens,
  }
end

return config
