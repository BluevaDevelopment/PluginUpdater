--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Runs work concurrently on one Lua lane. Each task is a coroutine; when it
-- waits on the network it yields, and the scheduler resumes whichever task's
-- request has answered. Outside a task, waiting simply blocks.
local tasks = {}

local active = setmetatable({}, { __mode = 'k' })

-- Waits until a pending call (an http request or transfer) is over.
function tasks.await(pending)
  if active[coroutine.running()] then
    while not pending:await(0) do coroutine.yield(pending) end
  else
    while not pending:await(100) do end
  end
  return pending
end

-- Calls fn(item, index) for every item, at most limit at once, and returns one
-- result per item in order: { ok = true, value = ... } or { ok = false, error = ... }.
-- progress(done, total) is called as items finish.
function tasks.map(items, fn, limit, progress)
  limit = math.max(limit or 8, 1)
  local results, running, upcoming, done = {}, {}, 1, 0

  local function step(job)
    local ok, value = coroutine.resume(job.co)
    if not ok then
      results[job.index] = { ok = false, error = value }
    elseif coroutine.status(job.co) == 'dead' then
      results[job.index] = { ok = true, value = value }
    else
      job.waiting = value
      return false
    end
    done = done + 1
    if progress then progress(done, #items) end
    return true
  end

  while true do
    while #running < limit and upcoming <= #items do
      local index = upcoming
      local co = coroutine.create(function() return fn(items[index], index) end)
      active[co] = true
      local job = { co = co, index = index }
      upcoming = upcoming + 1
      if not step(job) then running[#running + 1] = job end
    end
    if #running == 0 then break end
    running[1].waiting:await(20)
    for position = #running, 1, -1 do
      local job = running[position]
      if job.waiting:await(0) and step(job) then table.remove(running, position) end
    end
  end
  return results
end

return tasks
