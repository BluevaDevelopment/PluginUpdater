--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- The jars in a plugins folder and the plugins they hold.
local descriptor = use('server/descriptor')
local errors = use('core/errors')
local text = use('core/text')

local installed = {}

-- Every jar in folder, sorted by file name: { path, fileName, name, version, website }.
-- A jar with no descriptor has no name.
function installed.scan(folder)
  local plugins = {}
  for _, fileName in ipairs(fs:list(folder)) do
    local path = fs:join(folder, fileName)
    if fileName:lower():match('%.jar$') and fs:isFile(path) then
      local found = descriptor.read(path) or {}
      plugins[#plugins + 1] = {
        path = path,
        fileName = fileName,
        name = found.name,
        version = found.version,
        website = found.website,
        main = found.main,
        digests = {},
      }
    end
  end
  return plugins
end

-- The hex digest of an installed jar, computed once.
function installed.digest(plugin, algorithm)
  plugin.digests[algorithm] = plugin.digests[algorithm] or fs:digest(plugin.path, algorithm)
  return plugin.digests[algorithm]
end

-- The installed jar of a configured plugin: by its file glob when one is
-- given, otherwise by the name in its descriptor. Nil when it is not installed.
function installed.find(plugins, entry)
  local matches = {}
  for _, plugin in ipairs(plugins) do
    local match
    if entry.file then
      match = text.glob(entry.file, plugin.fileName)
    else
      match = plugin.name and text.key(plugin.name) == text.key(entry.name)
    end
    if match then matches[#matches + 1] = plugin end
  end
  if #matches > 1 then
    local names = {}
    for _, plugin in ipairs(matches) do names[#names + 1] = plugin.fileName end
    errors.fail('several jars hold ' .. entry.name .. ' (' .. table.concat(names, ', ')
      .. '); remove the extra ones or set file to pick one')
  end
  return matches[1]
end

return installed
