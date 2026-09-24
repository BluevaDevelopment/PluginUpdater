--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Writing pluginupdater.toml: the starting file, and entries added to it.
local errors = use('core/errors')

local writer = {}

writer.TEMPLATE = [[
# PluginUpdater keeps the jars in the plugins folder up to date.
#
# Each entry under [plugins] is named after its plugin (the name in its
# plugin.yml) and links to where the plugin is published. Run
# 'pluginupdater sources' to see the links it understands.

[settings]
# The folder with the plugin jars, relative to this file.
plugins-folder = "plugins"
# Each run that changes something adds a '- Plugin old -> new' line per plugin here.
changelog = "changelog.md"
# Which builds to pick: paper (also Spigot, Bukkit, Folia and Purpur), velocity or waterfall.
platform = "paper"
# The least stable builds accepted: release, beta or alpha.
channel = "release"
# Only builds made for this Minecraft version, where the store says (Hangar, Modrinth).
# minecraft = "1.21.8"
# How many runs of replaced jars to keep in .pluginupdater/backups; 0 keeps none.
backups = 5
# Install a build even when its version looks older than the installed one.
allow-downgrade = false

[tokens]
# Optional. GitHub answers 60 requests an hour without one. GITHUB_TOKEN works too.
# github = ""
# Optional. The CurseForge API needs a key (or CURSEFORGE_API_KEY); without one,
# CurseForge links are read through dev.bukkit.org's public API.
# curseforge = ""

[plugins]
# LuckPerms = "https://hangar.papermc.io/LuckPerms/LuckPerms"
# Vault = "https://www.spigotmc.org/resources/vault.34315/"
#
# [plugins.EssentialsX]
# url = "https://github.com/EssentialsX/Essentials"
# asset = "EssentialsX-*.jar"   # which file of the release, when it has several
]]

function writer.string(value)
  local escaped = value:gsub('[\\"]', '\\%0'):gsub('%c', function(char) return string.format('\\u%04X', string.byte(char)) end)
  return '"' .. escaped .. '"'
end

function writer.key(name)
  if name:match('^[%w_%-]+$') then return name end
  return writer.string(name)
end

-- A [plugins.<name>] table; fields is a list of { key, value } with string values.
function writer.entry(name, fields)
  local lines = { '[plugins.' .. writer.key(name) .. ']' }
  for _, field in ipairs(fields) do lines[#lines + 1] = field[1] .. ' = ' .. writer.string(field[2]) end
  return table.concat(lines, '\n')
end

-- The file's text with entries added at the end, checked to still be valid TOML.
function writer.add(existing, entries)
  local result = (existing or writer.TEMPLATE):gsub('%s*$', '') .. '\n\n' .. table.concat(entries, '\n\n') .. '\n'
  errors.context('the configuration would not be valid', function() return toml:decode(result) end)
  return result
end

return writer
