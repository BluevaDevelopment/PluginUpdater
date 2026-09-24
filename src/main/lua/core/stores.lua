--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- The stores plugins are downloaded from. Each script under sources/ is one:
--
--   name, label, example        what it is called and a link it understands
--   parse(url)                  the store's reference from a link, or nil
--   link(ref)                   the link back from a reference
--   latest(ref, context)        the newest build, or nil when none fits:
--                               { id, version, url, fileName, hashes, headers, unnamed }
--   search(plugin, context)     optional, for detect: { link, exact, title, hints }
--
-- context carries the plugin's entry, the platform, channel, tokens and settings.
local errors = use('core/errors')

local stores = {}

-- Order matters: the first store that understands a link owns it, and direct takes any URL.
local ORDER = { 'hangar', 'modrinth', 'spigot', 'github', 'bukkit', 'curseforge', 'direct' }

local loaded

function stores.all()
  if not loaded then
    loaded = {}
    for _, name in ipairs(ORDER) do loaded[#loaded + 1] = use('sources/' .. name) end
  end
  return loaded
end

function stores.get(name)
  for _, store in ipairs(stores.all()) do
    if store.name == name then return store end
  end
  errors.fail('no such store: ' .. name)
end

-- The store and reference a link points to, or nil.
function stores.resolve(url)
  for _, store in ipairs(stores.all()) do
    local ref = store.parse(url)
    if ref then return store, ref end
  end
end

return stores
