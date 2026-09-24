--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

local check = use('support/check')
local github = use('sources/github')
local stores = use('core/stores')

local suite = {}

local function resolved(url)
  local store, ref = stores.resolve(url)
  return store and store.name, ref
end

function suite.everyStoreKnowsItsLinks()
  check.equals({ 'hangar', { owner = 'ViaVersion', slug = 'ViaVersion' } }, { resolved('https://hangar.papermc.io/ViaVersion/ViaVersion/versions') })
  check.equals({ 'modrinth', { project = 'luckperms' } }, { resolved('https://modrinth.com/plugin/luckperms/versions') })
  check.equals({ 'spigot', { id = '34315' } }, { resolved('https://www.spigotmc.org/resources/vault.34315/updates') })
  check.equals({ 'spigot', { id = '34315' } }, { resolved('https://spigotmc.org/resources/34315/') })
  check.equals({ 'github', { owner = 'EssentialsX', repository = 'Essentials' } }, { resolved('https://github.com/EssentialsX/Essentials.git') })
  check.equals({ 'bukkit', { slug = 'worldedit' } }, { resolved('https://dev.bukkit.org/projects/worldedit/files') })
  check.equals({ 'curseforge', { slug = 'worldedit' } }, { resolved('https://www.curseforge.com/minecraft/bukkit-plugins/worldedit') })
end

function suite.anyOtherLinkOrPathIsDirect()
  check.equals({ 'direct', { url = 'https://ci.example.com/job/x/lastSuccessfulBuild/artifact/X.jar' } },
    { resolved('https://ci.example.com/job/x/lastSuccessfulBuild/artifact/X.jar') })
  check.equals({ 'direct', { path = '/opt/jars/X.jar' } }, { resolved('file:///opt/jars/X.jar') })
  check.equals({ 'direct', { path = './jars/X.jar' } }, { resolved('./jars/X.jar') })
  check.equals(nil, (resolved('LuckPerms')))
end

local function assets(...)
  local list = {}
  for index, name in ipairs({ ... }) do list[index] = { id = index, name = name } end
  return list
end

local function picked(list, name, platform, asset)
  return github.pickAsset(list, name, { platform = platform, entry = asset and { asset = asset } or nil }).name
end

function suite.theJarOfAReleaseIsPickedForThePluginAndPlatform()
  local essentials = assets('EssentialsX-2.22.0.jar', 'EssentialsXChat-2.22.0.jar', 'EssentialsXSpawn-2.22.0.jar')
  check.equals('EssentialsX-2.22.0.jar', picked(essentials, 'Essentials', 'paper'))
  check.equals('EssentialsXChat-2.22.0.jar', picked(essentials, 'EssentialsChat', 'paper', 'EssentialsXChat-*.jar'))

  local geyser = assets('Geyser-Spigot.jar', 'Geyser-Velocity.jar', 'Geyser-Fabric.jar', 'Geyser-Standalone.jar')
  check.equals('Geyser-Spigot.jar', picked(geyser, 'Geyser-Spigot', 'paper'))
  check.equals('Geyser-Velocity.jar', picked(geyser, 'Geyser', 'velocity'))

  check.equals('Plugin-1.0.jar', picked(assets('Plugin-1.0.jar', 'Plugin-1.0-sources.jar', 'Plugin-1.0-javadoc.jar'), 'Plugin', 'paper'))
  check.fails('set asset', picked, assets('One.jar', 'Two.jar'), 'Other', 'paper')
  check.fails("no jar of the release match asset 'Nope*'", picked, essentials, 'Essentials', 'paper', 'Nope*')
end

return suite
