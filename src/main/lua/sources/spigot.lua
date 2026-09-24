--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- SpigotMC, read through the Spiget API: spigotmc.org itself sits behind a
-- browser check that tools cannot pass.
local errors = use('core/errors')
local net = use('core/net')
local stores = use('core/stores')
local text = use('core/text')

local API = 'https://api.spiget.org/v2'

local spigot = {
  name = 'spigot',
  label = 'SpigotMC',
  example = 'https://www.spigotmc.org/resources/<name>.<id>/',
}

function spigot.parse(url)
  local path = url:match('^https?://[%w%.]*spigotmc%.org/resources/([^/?#]+)')
  local id = path and (path:match('%.(%d+)$') or path:match('^(%d+)$'))
  if id then return { id = id } end
end

function spigot.link(ref)
  return 'https://www.spigotmc.org/resources/' .. ref.id .. '/'
end

-- A resource hosted elsewhere is followed when its link belongs to another store, or is a jar.
local function external(resource, context)
  local url = resource.file and resource.file.externalUrl or ''
  local store, ref = stores.resolve(url)
  if store and store.name ~= 'direct' and store.name ~= 'spigot' then return store.latest(ref, context) end
  if url:lower():match('%.jar$') then return { url = url } end
  errors.fail(resource.name .. ' is hosted outside SpigotMC (' .. url .. '); use that page as its link instead')
end

function spigot.latest(ref, context)
  local resource = net.jsonOrNil(API .. '/resources/' .. ref.id) or errors.fail('SpigotMC has no resource ' .. ref.id)
  if resource.premium then
    errors.fail(resource.name .. ' is a premium resource; SpigotMC only lets buyers download it, from a browser')
  end
  -- Spiget's mirror names files by resource id, so the name comes from the jar's plugin.yml instead.
  local release = { url = API .. '/resources/' .. ref.id .. '/download', unnamed = true }
  if resource.external then
    release = external(resource, context)
    if release.id then return release end
  end
  local latest = net.json(API .. '/resources/' .. ref.id .. '/versions/latest')
  release.id = tostring(latest.id)
  release.version = latest.name
  return release
end

-- Resource titles often carry tags, as in 'Name [1.8 - 1.21]' or 'Name | Short pitch'.
local function title(name)
  return (name:gsub('%b[]', ''):gsub('%b()', ''):match('^[^|:]*') or name)
end

function spigot.search(plugin)
  local url = API .. '/search/resources/' .. net.encode(plugin.name)
    .. '?field=name&size=10&sort=-downloads&fields=id,name,premium,external'
  local key = text.key(plugin.name)
  for _, resource in ipairs(net.jsonOrNil(url) or {}) do
    if text.key(title(resource.name)) == key then
      return {
        link = spigot.link({ id = tostring(resource.id) }),
        title = resource.name,
        exact = false,
        note = resource.premium and 'premium, cannot be downloaded' or nil,
        unusable = resource.premium,
      }
    end
  end
end

return spigot
