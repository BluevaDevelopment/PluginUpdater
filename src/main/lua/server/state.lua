--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- What previous runs installed, so a store is not downloaded from again when
-- its latest build is the one already in place.
local state = {}

-- The state kept in a file; missing or unreadable is an empty state.
function state.load(path)
  local data = {}
  if fs:isFile(path) then
    local ok, decoded = pcall(function() return json:decode(fs:read(path)) end)
    if ok and type(decoded) == 'table' and type(decoded.plugins) == 'table' then data = decoded.plugins end
  end
  return { path = path, plugins = data }
end

function state.get(current, name)
  return current.plugins[name]
end

-- Remembers the store build a plugin's jar came from, and that jar's sha1.
function state.set(current, name, release, sha1)
  current.plugins[name] = { release = release, sha1 = sha1 }
end

function state.save(current)
  fs:write(current.path, json:encode({ plugins = current.plugins }) .. '\n')
end

return state
