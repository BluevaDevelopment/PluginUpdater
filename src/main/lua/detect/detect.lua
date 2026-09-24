--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Looks for installed plugins in every store: by the jar's hash where the store
-- can tell (an exact match), otherwise by name. GitHub is only asked about
-- repositories the plugin itself, or another store, links to. A plugin found
-- only by name is confirmed by downloading the store's jar and comparing the
-- main class, since unrelated plugins often share a name.
local curseforge = use('sources/curseforge')
local descriptor = use('server/descriptor')
local errors = use('core/errors')
local github = use('sources/github')
local net = use('core/net')
local stores = use('core/stores')
local tasks = use('core/tasks')
local text = use('core/text')

local detect = {}

-- The stores searched directly, then the rows shown, then the order a link is chosen in.
local SEARCHED = { 'hangar', 'modrinth', 'spigot', 'bukkit' }
detect.SHOWN = { 'hangar', 'modrinth', 'spigot', 'github', 'bukkit', 'curseforge' }
local PREFERRED = { 'hangar', 'modrinth', 'github', 'spigot', 'bukkit', 'curseforge' }

local function outcome(result)
  if not result.ok then return { error = errors.message(result.error) } end
  return { match = result.value }
end

-- The link to configure: an exact match first, then a confirmed one, in PREFERRED order.
function detect.choose(found)
  for _, wanted in ipairs({ 'exact', 'confirmed' }) do
    for _, name in ipairs(PREFERRED) do
      local match = found[name] and found[name].match
      if match and not match.unusable and match[wanted] then return name, match end
    end
  end
end

-- Whether the store's newest jar is the same plugin: same name and main class.
local function confirm(plugin, match, context, folder)
  local store, ref = stores.resolve(match.link)
  local release = store.latest(ref, setmetatable({ name = plugin.name, entry = match.asset and { asset = match.asset } }, { __index = context }))
  if not release or not release.url then return false end
  local target = fs:join(folder, text.safeFileName(plugin.name .. '-' .. store.name) .. '.jar')
  net.download(release.url, target, { headers = release.headers })
  local found = descriptor.read(target)
  fs:delete(target)
  return found ~= nil and text.key(found.name) == text.key(plugin.name) and found.main == plugin.main
end

-- Confirms name-only matches, in PREFERRED order, until one holds.
local function settle(plugin, found, context, folder)
  if detect.choose(found) then return end
  for _, name in ipairs(PREFERRED) do
    local match = found[name].match
    if match and not match.unusable and name ~= 'curseforge' then
      local ok, same = pcall(confirm, plugin, match, context, folder)
      if ok and same then
        match.confirmed = true
        if name == 'bukkit' and found.curseforge.match then found.curseforge.match.confirmed = true end
        return
      elseif ok then
        match.other = true
        match.unusable = true
      end
    end
  end
end

-- For each plugin: { plugin, found = { [store] = { match } or { error } or {} }, store, match }.
function detect.run(plugins, context, parallel, progress)
  local jobs = {}
  for index, plugin in ipairs(plugins) do
    for _, name in ipairs(SEARCHED) do jobs[#jobs + 1] = { index = index, plugin = plugin, store = stores.get(name) } end
  end
  local total = #jobs + #plugins * 2
  local report = function(done) if progress then progress(done, total) end end

  local results = tasks.map(jobs, function(job) return job.store.search(job.plugin, context) end, parallel, report)
  local found = {}
  for index in ipairs(plugins) do found[index] = {} end
  for position, job in ipairs(jobs) do found[job.index][job.store.name] = outcome(results[position]) end

  local repositories = tasks.map(plugins, function(plugin, index)
    local hints = { plugin.website }
    for _, name in ipairs(SEARCHED) do
      local match = found[index][name].match
      for _, hint in ipairs(match and match.hints or {}) do hints[#hints + 1] = hint end
    end
    local scoped = setmetatable({ hints = hints }, { __index = context })
    return github.search(plugin, scoped)
  end, parallel, function(done) report(#jobs + done) end)

  for index in ipairs(plugins) do
    local stores = found[index]
    stores.github = outcome(repositories[index])
    local bukkit = stores.bukkit
    stores.curseforge = bukkit.match and { match = curseforge.fromBukkit(bukkit.match) } or { error = bukkit.error }
  end

  local folder = fs:temporary('pluginupdater-detect')
  tasks.map(plugins, function(plugin, index) settle(plugin, found[index], context, folder) end, parallel,
    function(done) report(#jobs + #plugins + done) end)
  fs:delete(folder)

  local list = {}
  for index, plugin in ipairs(plugins) do
    local store, match = detect.choose(found[index])
    list[index] = { plugin = plugin, found = found[index], store = store, match = match }
  end
  return list
end

return detect
