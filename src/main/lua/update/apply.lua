--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Puts planned jars in place. A replaced jar is moved into the run's backup
-- folder, outside the plugins folder so the server never loads it.
local errors = use('core/errors')

local apply = {}

-- Installs one planned jar; backups is the run's backup folder, or nil to keep none.
function apply.install(folder, outcome, backups)
  local target = fs:join(folder, outcome.fileName)
  local old = outcome.plugin
  if fs:exists(target) and not (old and old.path == target) then
    errors.fail(outcome.fileName .. ' is already in ' .. folder .. ' and holds another plugin')
  end
  if old then
    if backups then fs:move(old.path, fs:join(backups, old.fileName)) else fs:delete(old.path) end
  end
  fs:move(outcome.staged, target)
end

-- Keeps the newest keep run folders under folder. Their names are timestamps, so they sort by age.
function apply.prune(folder, keep)
  local runs = fs:list(folder)
  for index = 1, #runs - keep do fs:delete(fs:join(folder, runs[index])) end
end

return apply
