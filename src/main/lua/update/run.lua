--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- A whole run over the configured plugins: check them all at once, print what
-- each needs, then (unless it is only a check) install, write the changelog
-- and remember what was installed.
local apply = use('update/apply')
local changelog = use('server/changelog')
local errors = use('core/errors')
local installed = use('server/installed')
local plan = use('update/plan')
local state = use('server/state')
local system = use('core/system')
local tasks = use('core/tasks')
local ui = use('core/ui')

local run = {}

-- The entries to look at: enabled ones, or only the ones named.
local function chosen(loaded, only)
  if not only or #only == 0 then
    local list = {}
    for _, entry in ipairs(loaded.plugins) do
      if entry.enabled then list[#list + 1] = entry end
    end
    return list
  end
  local list = {}
  for _, name in ipairs(only) do
    local found
    for _, entry in ipairs(loaded.plugins) do
      if entry.name:lower() == name:lower() then found = entry end
    end
    if not found then errors.usage("there is no plugin '" .. name .. "' in " .. fs:name(loaded.path)) end
    list[#list + 1] = found
  end
  return list
end

local function row(width, name, detail, code)
  ui.info(ui.pad(name, width) .. '  ' .. (code and ui.style(detail, code) or detail))
end

local function show(width, outcome)
  if outcome.action == 'current' then
    row(width, outcome.name, (outcome.version or '?') .. '  up to date', '2')
  elseif outcome.action == 'update' then
    row(width, outcome.name, outcome.from .. ' -> ' .. outcome.to .. '  (' .. outcome.store .. ')', '32')
  elseif outcome.action == 'install' then
    row(width, outcome.name, 'not installed -> ' .. outcome.to .. '  (' .. outcome.store .. ')', '32')
  elseif outcome.action == 'skip' then
    row(width, outcome.name, 'skipped: ' .. outcome.message, '33')
  else
    row(width, outcome.name, 'failed: ' .. outcome.message, '31')
  end
end

-- Checks every chosen plugin and, when install is true, applies what changed.
-- Returns the outcomes; the run has failed when any of them has action 'failed'.
function run.execute(loaded, options)
  if not fs:isDirectory(loaded.pluginsFolder) then
    errors.fail('there is no plugins folder at ' .. loaded.pluginsFolder .. '; set plugins-folder in ' .. fs:name(loaded.path))
  end
  local entries = chosen(loaded, options.only)
  if #entries == 0 then
    ui.say('No plugins to check. Add them under [plugins] in ' .. fs:name(loaded.path) .. ", or run 'pluginupdater detect --write'.")
    return {}
  end

  local plugins = installed.scan(loaded.pluginsFolder)
  local remembered = state.load(fs:join(loaded.data, 'state.json'))
  local staging = fs:join(loaded.data, 'staging')
  fs:delete(staging)
  fs:mkdirs(staging)

  ui.step('Checking ' .. #entries .. ' plugin' .. (#entries == 1 and '' or 's') .. ' in ' .. loaded.pluginsFolder)
  local counter = ui.counter('Checking')
  local results = tasks.map(entries, function(entry, index)
    return plan.entry(loaded, plugins, remembered, entry, staging, index)
  end, loaded.parallel, counter.set)
  counter.close()

  local outcomes, width = {}, 0
  for index, entry in ipairs(entries) do
    local result = results[index]
    outcomes[index] = result.ok and result.value
      or { name = entry.name, action = 'failed', message = errors.message(result.error) }
    width = math.max(width, #entry.name)
  end

  local changes = {}
  local backups = loaded.backups > 0 and fs:join(fs:join(loaded.data, 'backups'), system.date('yyyy-MM-dd_HH-mm-ss')) or nil
  for _, outcome in ipairs(outcomes) do
    if options.install and (outcome.action == 'update' or outcome.action == 'install') then
      local ok, failure = pcall(apply.install, loaded.pluginsFolder, outcome, backups)
      if ok then
        changes[#changes + 1] = { name = outcome.name, from = outcome.from, to = outcome.to }
      else
        outcome.action, outcome.message = 'failed', errors.message(failure)
      end
    end
    if outcome.remember and (options.install or outcome.action == 'current') then
      state.set(remembered, outcome.name, outcome.remember.release, outcome.remember.sha1)
    end
    show(width, outcome)
  end

  if #changes > 0 then
    changelog.write(loaded.changelog, system.date('yyyy-MM-dd HH:mm'), changes)
    if backups then apply.prune(fs:parent(backups), loaded.backups) end
  end
  state.save(remembered)
  fs:delete(staging)
  return outcomes, changes
end

-- How many outcomes have each action.
function run.count(outcomes)
  local counts = { current = 0, update = 0, install = 0, skip = 0, failed = 0 }
  for _, outcome in ipairs(outcomes) do counts[outcome.action] = counts[outcome.action] + 1 end
  return counts
end

-- Prints how the run went and returns its exit code: 1 when a plugin failed.
function run.summary(loaded, outcomes, changes, install)
  local counts = run.count(outcomes)
  local parts = {}
  local function add(count, text) if count > 0 then parts[#parts + 1] = count .. ' ' .. text end end
  if install then
    add(counts.update, 'updated')
    add(counts.install, 'installed')
  else
    add(counts.update, 'to update')
    add(counts.install, 'to install')
  end
  add(counts.current, 'up to date')
  add(counts.skip, 'skipped')
  add(counts.failed, 'failed')
  if #parts == 0 then return 0 end
  local line = table.concat(parts, ', ')
  line = line:sub(1, 1):upper() .. line:sub(2)
  if counts.failed > 0 then ui.error(line) else ui.success(line) end
  if install and #changes > 0 then ui.info('Changes added to ' .. loaded.changelog) end
  if not install and counts.update + counts.install > 0 then ui.info("Run 'pluginupdater update' to install them") end
  return counts.failed > 0 and 1 or 0
end

return run
