--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

local check = use('support/check')
local config = use('server/config')
local writer = use('server/writer')

local suite = {}

local function parse(source)
  return config.parse('/srv/mc/pluginupdater.toml', source)
end

function suite.linksAndTablesBecomeEntries()
  local loaded = parse([[
[settings]
channel = "beta"
backups = 0

[plugins]
Vault = "https://www.spigotmc.org/resources/vault.34315/"

[plugins."My Plugin"]
url = "https://github.com/owner/repo"
asset = "MyPlugin-*.jar"
channel = "release"
enabled = false
]])
  check.equals('/srv/mc/plugins', loaded.pluginsFolder)
  check.equals('/srv/mc/changelog.md', loaded.changelog)
  check.equals(0, loaded.backups)
  check.equals({ 'My Plugin', 'Vault' }, { loaded.plugins[1].name, loaded.plugins[2].name })
  local mine, vault = loaded.plugins[1], loaded.plugins[2]
  check.equals({ 'github', 'MyPlugin-*.jar', 'release', false }, { mine.store.name, mine.asset, mine.channel, mine.enabled })
  check.equals({ 'spigot', 'beta', true }, { vault.store.name, vault.channel, vault.enabled })
end

function suite.mistakesNameTheFileAndTheKey()
  check.fails("pluginupdater.toml: unknown setting 'plugin-folder'", parse, '[settings]\nplugin-folder = "x"')
  check.fails("settings.channel can't be 'stable'", parse, '[settings]\nchannel = "stable"')
  check.fails('plugins.X needs a url', parse, '[plugins.X]\nasset = "a"')
  check.fails("no store understands 'LuckPerms'", parse, '[plugins]\nX = "LuckPerms"')
  check.fails('pluginupdater.toml: line 1', parse, 'plugins = ')
end

function suite.theWrittenFilesAreValidConfigurations()
  local template = parse(writer.TEMPLATE)
  check.equals({ 'paper', 'release', 5, 0 }, { template.platform, template.channel, template.backups, #template.plugins })

  local text = writer.add(nil, {
    writer.entry('LuckPerms', { { 'url', 'https://hangar.papermc.io/LuckPerms/LuckPerms' } }),
    writer.entry('Odd "Name"', { { 'url', 'https://github.com/o/r' }, { 'asset', 'Odd-*.jar' } }),
  })
  local loaded = parse(text)
  check.equals({ 'LuckPerms', 'Odd "Name"' }, { loaded.plugins[1].name, loaded.plugins[2].name })
  check.equals('Odd-*.jar', loaded.plugins[2].asset)
end

return suite
