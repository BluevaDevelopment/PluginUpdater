--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Modrinth.
local errors = use('core/errors')
local installed = use('server/installed')
local net = use('core/net')
local text = use('core/text')
local versions = use('core/versions')

local API = 'https://api.modrinth.com/v2'

-- The loaders whose builds run on each platform.
local LOADERS = {
  paper = { 'paper', 'spigot', 'bukkit', 'purpur', 'folia' },
  velocity = { 'velocity' },
  waterfall = { 'waterfall', 'bungeecord' },
}

local modrinth = {
  name = 'modrinth',
  label = 'Modrinth',
  example = 'https://modrinth.com/plugin/<project>',
}

function modrinth.parse(url)
  local project = url:match('^https?://modrinth%.com/%a+/([^/?#]+)')
  if project then return { project = project } end
end

function modrinth.link(ref)
  return 'https://modrinth.com/plugin/' .. ref.project
end

local function array(values)
  return '["' .. table.concat(values, '","') .. '"]'
end

-- The file of a build: its primary one, or its first jar.
local function file(version)
  for _, candidate in ipairs(version.files or {}) do
    if candidate.primary then return candidate end
  end
  for _, candidate in ipairs(version.files or {}) do
    if candidate.filename:lower():match('%.jar$') then return candidate end
  end
end

function modrinth.latest(ref, context)
  local url = API .. '/project/' .. net.encode(ref.project) .. '/version?loaders=' .. net.encode(array(LOADERS[context.platform]))
  if context.minecraft then url = url .. '&game_versions=' .. net.encode(array({ context.minecraft })) end
  local list = net.jsonOrNil(url) or errors.fail('Modrinth has no project ' .. ref.project)
  table.sort(list, function(a, b) return (a.date_published or '') > (b.date_published or '') end)
  local wanted = versions.channelRank(context.channel)
  for _, version in ipairs(list) do
    local chosen = file(version)
    if chosen and (versions.channelRank(version.version_type) or 0) >= wanted then
      return {
        id = version.id,
        version = version.version_number,
        url = chosen.url,
        fileName = chosen.filename,
        hashes = { sha1 = chosen.hashes and chosen.hashes.sha1, sha512 = chosen.hashes and chosen.hashes.sha512 },
      }
    end
  end
end

-- By the jar's sha1 first, which names the exact project; then by name among the platform's plugins.
function modrinth.search(plugin, context)
  local exact = net.jsonOrNil(API .. '/version_file/' .. installed.digest(plugin, 'sha1') .. '?algorithm=sha1')
  local id = exact and exact.project_id
  if not id then
    local categories = {}
    for _, loader in ipairs(LOADERS[context.platform]) do categories[#categories + 1] = 'categories:' .. loader end
    local facets = '[' .. array(categories) .. ']'
    local found = net.jsonOrNil(API .. '/search?limit=10&query=' .. net.encode(plugin.name) .. '&facets=' .. net.encode(facets))
    local key = text.key(plugin.name)
    for _, hit in ipairs(found and found.hits or {}) do
      if text.key(hit.title) == key or text.key(hit.slug) == key then
        id = hit.project_id
        break
      end
    end
  end
  if not id then return nil end
  local project = net.json(API .. '/project/' .. id)
  return {
    link = modrinth.link({ project = project.slug }),
    title = project.title,
    exact = exact ~= nil,
    hints = { project.source_url },
  }
end

return modrinth
