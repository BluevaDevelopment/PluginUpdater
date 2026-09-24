--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Asks the real stores for well-known plugins, so a change in their APIs shows up here.
local check = use('support/check')
local stores = use('core/stores')
local system = use('core/system')

local suite = {}

local function latest(url, name)
  local store, ref = stores.resolve(url)
  local release = store.latest(ref, {
    name = name, platform = 'paper', channel = 'release',
    tokens = { github = system.env('GITHUB_TOKEN'), curseforge = system.env('CURSEFORGE_API_KEY') },
  })
  check.truthy(release, url .. ' has no release')
  check.truthy(release.id and release.url, url .. ' gave no build id or download')
  return release
end

function suite.hangar()
  local release = latest('https://hangar.papermc.io/ViaVersion/ViaVersion', 'ViaVersion')
  check.truthy(release.hashes.sha256 and release.fileName:match('%.jar$'))
end

function suite.modrinth()
  local release = latest('https://modrinth.com/plugin/luckperms', 'LuckPerms')
  check.truthy(release.hashes.sha1 and release.fileName:match('^LuckPerms%-Bukkit'), release.fileName)
end

function suite.spigot()
  local release = latest('https://www.spigotmc.org/resources/vault.34315/', 'Vault')
  check.truthy(release.version)
end

function suite.github()
  local release = latest('https://github.com/EssentialsX/Essentials', 'Essentials')
  check.truthy(release.fileName:match('^EssentialsX%-[%d%.]+%.jar$'), release.fileName)
end

function suite.bukkitAndCurseforge()
  local bukkit = latest('https://dev.bukkit.org/projects/worldedit', 'WorldEdit')
  check.truthy(bukkit.hashes.md5 and bukkit.fileName:match('^worldedit%-bukkit'), bukkit.fileName)
  local curseforge = latest('https://www.curseforge.com/minecraft/bukkit-plugins/worldedit', 'WorldEdit')
  check.equals(bukkit.fileName, curseforge.fileName)
end

return suite
