--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

local check = use('support/check')
local errors = use('core/errors')
local tasks = use('core/tasks')

local suite = {}

-- Stands in for an http call: over after a number of polls.
local function pending(polls)
  return { await = function(self) polls = polls - 1; return polls <= 0 end }
end

function suite.tasksInterleaveAndKeepTheirOrder()
  local finished = {}
  local results = tasks.map({ 5, 1, 3 }, function(polls, index)
    tasks.await(pending(polls))
    finished[#finished + 1] = index
    return polls * 10
  end, 3)
  check.equals({ 2, 3, 1 }, finished)
  check.equals({ { ok = true, value = 50 }, { ok = true, value = 10 }, { ok = true, value = 30 } }, results)
end

function suite.aFailingTaskDoesNotStopTheOthers()
  local results = tasks.map({ 'a', 'b' }, function(item)
    tasks.await(pending(2))
    if item == 'a' then errors.fail('a broke') end
    return item
  end, 1)
  check.equals(false, results[1].ok)
  check.equals('a broke', errors.message(results[1].error))
  check.equals({ ok = true, value = 'b' }, results[2])
end

return suite
