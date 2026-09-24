--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- dev.bukkit.org, which is CurseForge's Bukkit plugin catalog, through its
-- public ServerMods API (no key needed).
local errors = use('core/errors')
local installed = use('server/installed')
local net = use('core/net')
local text = use('core/text')
local versions = use('core/versions')

local API = 'https://servermods.forgesvc.net/servermods'
local RANKS = { release = 0, beta = -2, alpha = -3 }

local bukkit = {
  name = 'bukkit',
  label = 'BukkitDev',
  example = 'https://dev.bukkit.org/projects/<project>',
}

function bukkit.parse(url)
  local slug = url:match('^https?://dev%.bukkit%.org/projects/([^/?#]+)')
    or url:match('^https?://dev%.bukkit%.org/bukkit%-plugins/([^/?#]+)')
  if slug then return { slug = slug } end
end

function bukkit.link(ref)
  return 'https://dev.bukkit.org/projects/' .. ref.slug
end

local function projects(query)
  -- The search only matches lower case.
  return net.jsonOrNil(API .. '/projects?search=' .. net.encode(query:lower())) or {}
end

-- The project id behind a slug.
function bukkit.project(slug)
  for _, project in ipairs(projects(slug)) do
    if project.slug == slug then return project.id end
  end
  errors.fail('dev.bukkit.org has no project ' .. slug)
end

-- A project's files, oldest first.
function bukkit.files(id)
  return net.json(API .. '/files?projectIds=' .. id)
end

-- The newest file at least as stable as the channel.
function bukkit.pick(files, channel)
  local wanted = versions.channelRank(channel)
  for index = #files, 1, -1 do
    local file = files[index]
    if (RANKS[file.releaseType] or 0) >= wanted then
      return {
        id = file.fileUrl or file.downloadUrl,
        version = versions.find(file.name),
        url = file.downloadUrl,
        fileName = file.fileName,
        hashes = { md5 = file.md5 },
      }
    end
  end
end

function bukkit.latest(ref, context)
  return bukkit.pick(bukkit.files(bukkit.project(ref.slug)), context.channel)
end

-- Titles here often end in ' for Bukkit'.
local function title(name)
  return text.key(name):gsub('forbukkit$', '')
end

function bukkit.search(plugin)
  local key = text.key(plugin.name)
  for _, project in ipairs(projects(plugin.name)) do
    if title(project.name) == key or text.key(project.slug) == key then
      local md5 = installed.digest(plugin, 'md5')
      local exact = false
      for _, file in ipairs(bukkit.files(project.id)) do exact = exact or file.md5 == md5 end
      return { link = bukkit.link({ slug = project.slug }), title = project.name, exact = exact, slug = project.slug }
    end
  end
end

return bukkit
