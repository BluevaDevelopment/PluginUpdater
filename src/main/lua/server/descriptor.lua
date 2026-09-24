--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- What a plugin jar says about itself: its name, version and website, read
-- from paper-plugin.yml, plugin.yml, bungee.yml or velocity-plugin.json.
local text = use('core/text')

local descriptor = {}

local YAML = { 'paper-plugin.yml', 'plugin.yml', 'bungee.yml' }

local function scalar(value)
  value = text.trim(value)
  local quote = value:sub(1, 1)
  if quote == '"' or quote == "'" then
    local closing = value:find(quote, 2, true)
    return closing and value:sub(2, closing - 1) or value:sub(2)
  end
  return text.trim((value:gsub('%s+#.*$', '')))
end

-- The top-level scalar keys of a plugin descriptor. Nested blocks and lists
-- are skipped; only what identifies the plugin is needed.
function descriptor.parseYaml(source)
  local values = {}
  for line in (source .. '\n'):gmatch('([^\n]*)\n') do
    local key, value = line:gsub('\r$', ''):match('^([%w_%-]+):%s*(.*)$')
    if key and value ~= '' and values[key] == nil then
      local first = value:sub(1, 1)
      if first == '[' then
        values[key] = scalar(value:match('^%[%s*([^,%]]*)') or '')
      elseif first ~= '|' and first ~= '>' and first ~= '&' then
        values[key] = scalar(value)
      end
    end
  end
  return values
end

local function fromYaml(values, file)
  if not values.name or values.name == '' then return nil end
  return {
    name = values.name,
    version = values.version,
    website = values.website,
    main = values.main,
    file = file,
  }
end

-- The descriptor of a jar, or nil when it is not a plugin.
function descriptor.read(jar)
  for _, file in ipairs(YAML) do
    local source = zip:read(jar, file)
    if source then
      local found = fromYaml(descriptor.parseYaml(source), file)
      if found then return found end
    end
  end
  local velocity = zip:read(jar, 'velocity-plugin.json')
  if velocity then
    local ok, values = pcall(function() return json:decode(velocity) end)
    if ok and type(values) == 'table' and values.id then
      return {
        name = values.name or values.id,
        version = values.version,
        website = values.url,
        main = values.main,
        file = 'velocity-plugin.json',
      }
    end
  end
  return nil
end

return descriptor
