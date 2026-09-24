--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- CurseForge's Bukkit plugins. With an API key the CurseForge API is used;
-- without one, the same catalog is read through dev.bukkit.org's public API.
local bukkit = use('sources/bukkit')
local errors = use('core/errors')
local net = use('core/net')
local versions = use('core/versions')

local API = 'https://api.curseforge.com/v1'
local MINECRAFT, BUKKIT_PLUGINS = 432, 5
local RANKS = { [1] = 0, [2] = -2, [3] = -3 }
local HASHES = { [1] = 'sha1', [2] = 'md5' }

local curseforge = {
  name = 'curseforge',
  label = 'CurseForge',
  example = 'https://www.curseforge.com/minecraft/bukkit-plugins/<project>',
}

function curseforge.parse(url)
  local slug = url:match('^https?://[%w%.]*curseforge%.com/minecraft/bukkit%-plugins/([^/?#]+)')
  if slug then return { slug = slug } end
end

function curseforge.link(ref)
  return 'https://www.curseforge.com/minecraft/bukkit-plugins/' .. ref.slug
end

-- CurseForge's own address for a file, for authors who turned off downloads through the API.
local function cdn(file)
  return 'https://edge.forgecdn.net/files/' .. (file.id // 1000) .. '/' .. (file.id % 1000) .. '/' .. net.encode(file.fileName)
end

function curseforge.latest(ref, context)
  local key = context.tokens and context.tokens.curseforge
  if not key then return bukkit.latest(ref, context) end
  local headers = { ['x-api-key'] = key, Accept = 'application/json' }
  local found = errors.context('CurseForge', net.json, API .. '/mods/search?gameId=' .. MINECRAFT .. '&classId='
    .. BUKKIT_PLUGINS .. '&slug=' .. net.encode(ref.slug), headers)
  local mod = found.data and found.data[1] or errors.fail('CurseForge has no Bukkit plugin ' .. ref.slug)
  local files = errors.context('CurseForge', net.json, API .. '/mods/' .. mod.id .. '/files?pageSize=50', headers).data or {}

  local wanted, newest = versions.channelRank(context.channel), nil
  for _, file in ipairs(files) do
    if file.isAvailable ~= false and (RANKS[file.releaseType] or 0) >= wanted
      and (not newest or file.fileDate > newest.fileDate) then
      newest = file
    end
  end
  if not newest then return nil end
  local hashes = {}
  for _, hash in ipairs(newest.hashes or {}) do
    if HASHES[hash.algo] then hashes[HASHES[hash.algo]] = hash.value end
  end
  return {
    id = tostring(newest.id),
    version = versions.find(newest.displayName),
    url = newest.downloadUrl or cdn(newest),
    fileName = newest.fileName,
    hashes = hashes,
  }
end

-- CurseForge's Bukkit plugins are dev.bukkit.org's projects, so what detect
-- finds there is found here as well.
function curseforge.fromBukkit(match)
  return { link = curseforge.link({ slug = match.slug }), title = match.title, exact = match.exact, slug = match.slug }
end

return curseforge
