--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Hangar, PaperMC's plugin repository.
local errors = use('core/errors')
local installed = use('server/installed')
local net = use('core/net')
local text = use('core/text')
local versions = use('core/versions')

local API = 'https://hangar.papermc.io/api/v1'
local PLATFORMS = { paper = 'PAPER', velocity = 'VELOCITY', waterfall = 'WATERFALL' }

local hangar = {
  name = 'hangar',
  label = 'Hangar',
  example = 'https://hangar.papermc.io/<owner>/<project>',
}

function hangar.parse(url)
  local owner, slug = url:match('^https?://hangar%.papermc%.io/([^/?#]+)/([^/?#]+)')
  if owner then return { owner = owner, slug = slug } end
end

function hangar.link(ref)
  return 'https://hangar.papermc.io/' .. ref.owner .. '/' .. ref.slug
end

-- A channel counts as unstable by its name, or by the flag its owner set on it.
local function stability(version)
  local channel = version.channel or {}
  local rank = versions.stability(channel.name)
  for _, flag in ipairs(channel.flags or {}) do
    if flag == 'UNSTABLE' and rank == 0 then rank = -2 end
  end
  return rank
end

local PAGE, PAGES = 25, 4

-- One page of a project's builds for the platform, newest first.
local function builds(ref, context, offset)
  local platform = PLATFORMS[context.platform]
  local url = API .. '/projects/' .. net.encode(ref.slug) .. '/versions?limit=' .. PAGE .. '&offset=' .. offset .. '&platform=' .. platform
  if context.minecraft then url = url .. '&platformVersion=' .. net.encode(context.minecraft) end
  local page = net.jsonOrNil(url) or errors.fail('Hangar has no project ' .. ref.owner .. '/' .. ref.slug)
  return page.result or {}, platform
end

-- Projects that publish many snapshots can bury their last release a few pages down.
function hangar.latest(ref, context)
  local wanted = versions.channelRank(context.channel)
  for page = 0, PAGES - 1 do
    local list, platform = builds(ref, context, page * PAGE)
    for _, version in ipairs(list) do
      local download = version.downloads and version.downloads[platform]
      if download and stability(version) >= wanted then
        local info = download.fileInfo or {}
        return {
          id = tostring(version.id),
          version = version.name,
          url = download.downloadUrl or download.externalUrl,
          fileName = info.name,
          hashes = { sha256 = info.sha256Hash },
        }
      end
    end
    if #list < PAGE then return nil end
  end
end

-- Whether the build named like the installed version is the installed file.
local function same(ref, plugin)
  if not plugin.version then return false end
  local version = net.jsonOrNil(API .. '/projects/' .. net.encode(ref.slug) .. '/versions/' .. net.encode(plugin.version))
  local sha256 = installed.digest(plugin, 'sha256')
  for _, download in pairs(version and version.downloads or {}) do
    if download.fileInfo and download.fileInfo.sha256Hash == sha256 then return true end
  end
  return false
end

function hangar.search(plugin)
  local page = net.jsonOrNil(API .. '/projects?limit=10&q=' .. net.encode(plugin.name))
  local key = text.key(plugin.name)
  for _, project in ipairs(page and page.result or {}) do
    if text.key(project.name) == key or text.key(project.namespace.slug) == key then
      local ref = { owner = project.namespace.owner, slug = project.namespace.slug }
      local hints = {}
      for _, group in ipairs(project.settings and project.settings.links or {}) do
        for _, link in ipairs(group.links or {}) do hints[#hints + 1] = link.url end
      end
      return { link = hangar.link(ref), title = project.name, exact = same(ref, plugin), hints = hints }
    end
  end
end

return hangar
