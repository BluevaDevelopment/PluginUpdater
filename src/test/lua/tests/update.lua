--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Whole runs against a server folder, with plugins published as jars on disk.
local check = use('support/check')
local config = use('server/config')
local run = use('update/run')
local writer = use('server/writer')

local suite = {}

-- A server with plugins/ and a folder of published jars; entries map names to published file names.
local function server(settings, entries)
  local root = check.folder()
  fs:mkdirs(fs:join(root, 'plugins'))
  local published = fs:join(root, 'published')
  local blocks = {}
  for name, fileName in pairs(entries) do
    blocks[#blocks + 1] = writer.entry(name, { { 'url', fs:join(published, fileName) } })
  end
  table.sort(blocks)
  local text = writer.add('[settings]\n' .. (settings or '') .. '\n\n[plugins]', blocks)
  local path = fs:join(root, 'pluginupdater.toml')
  fs:write(path, text)
  return root, published, function() return config.load(path) end
end

local function actions(outcomes)
  local list = {}
  for _, outcome in ipairs(outcomes) do list[outcome.name] = outcome.action end
  return list
end

function suite.outdatedPluginsAreReplacedAndLogged()
  local root, published, load = server(nil, { Alpha = 'Alpha-1.1.jar', Beta = 'Beta.jar', Gamma = 'Gamma-2.0.jar' })
  local plugins = fs:join(root, 'plugins')
  check.jar(plugins, 'Alpha-1.0.jar', 'Alpha', '1.0')
  check.jar(published, 'Alpha-1.1.jar', 'Alpha', '1.1')
  check.jar(plugins, 'Beta.jar', 'Beta', '3.0')
  fs:copy(fs:join(plugins, 'Beta.jar'), fs:join(published, 'Beta.jar'))
  check.jar(published, 'Gamma-2.0.jar', 'Gamma', '2.0')

  local outcomes, changes = run.execute(load(), { install = true })
  check.equals({ Alpha = 'update', Beta = 'current', Gamma = 'install' }, actions(outcomes))
  check.equals({ 'Alpha-1.1.jar', 'Beta.jar', 'Gamma-2.0.jar' }, fs:list(plugins))
  check.equals(2, #changes)

  local log = fs:read(fs:join(root, 'changelog.md'))
  check.truthy(log:find('- Alpha 1.0 -> 1.1\n- Gamma (new) -> 2.0\n', 1, true), log)
  local backups = fs:join(root, '.pluginupdater/backups')
  check.equals({ 'Alpha-1.0.jar' }, fs:list(fs:join(backups, fs:list(backups)[1])))
  check.equals(false, fs:exists(fs:join(root, '.pluginupdater/staging')))

  outcomes = run.execute(load(), { install = true })
  check.equals({ Alpha = 'current', Beta = 'current', Gamma = 'current' }, actions(outcomes))
  fs:delete(root)
end

function suite.aCheckChangesNothing()
  local root, published, load = server(nil, { Alpha = 'Alpha-1.1.jar' })
  check.jar(fs:join(root, 'plugins'), 'Alpha-1.0.jar', 'Alpha', '1.0')
  check.jar(published, 'Alpha-1.1.jar', 'Alpha', '1.1')
  local outcomes = run.execute(load(), { install = false })
  check.equals({ Alpha = 'update' }, actions(outcomes))
  check.equals({ 'Alpha-1.0.jar' }, fs:list(fs:join(root, 'plugins')))
  check.equals(false, fs:exists(fs:join(root, 'changelog.md')))
  fs:delete(root)
end

function suite.olderBuildsAreOnlyInstalledWhenAllowed()
  local root, published, load = server(nil, { Alpha = 'Alpha-0.9.jar' })
  check.jar(fs:join(root, 'plugins'), 'Alpha-1.0.jar', 'Alpha', '1.0')
  check.jar(published, 'Alpha-0.9.jar', 'Alpha', '0.9')
  local outcomes = run.execute(load(), { install = true })
  check.equals('skip', outcomes[1].action)
  check.truthy(outcomes[1].message:find('older than the installed 1.0', 1, true))

  local path = fs:join(root, 'pluginupdater.toml')
  fs:write(path, fs:read(path):gsub('%[settings%]', '[settings]\nallow-downgrade = true'))
  check.equals('update', run.execute(load(), { install = true })[1].action)
  fs:delete(root)
end

function suite.aDownloadOfAnotherPluginIsRefused()
  local root, published, load = server('backups = 0', { Alpha = 'Other.jar' })
  check.jar(fs:join(root, 'plugins'), 'Alpha-1.0.jar', 'Alpha', '1.0')
  check.jar(published, 'Other.jar', 'Other', '9.0')
  local outcomes = run.execute(load(), { install = true })
  check.equals('failed', outcomes[1].action)
  check.truthy(outcomes[1].message:find("the download is the plugin 'Other', not 'Alpha'", 1, true), outcomes[1].message)
  check.equals({ 'Alpha-1.0.jar' }, fs:list(fs:join(root, 'plugins')))
  fs:delete(root)
end

return suite
