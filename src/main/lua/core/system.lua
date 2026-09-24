--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- The machine PluginUpdater runs on, read straight from the JVM through Mawu's java global.
local System = java.lang.System
local LocalDateTime = java.time.LocalDateTime
local DateTimeFormatter = java.time.format.DateTimeFormatter

local system = {}

-- An environment variable, or nil when it is unset or blank.
function system.env(name)
  local value = System:getenv(name)
  if value == nil or value == '' then return nil end
  return value
end

function system.cwd()
  return System:getProperty('user.dir')
end

-- Milliseconds; a Java long arrives as a float, so it is turned back into an integer.
function system.now()
  return math.floor(System:currentTimeMillis())
end

-- The local date and time in a DateTimeFormatter pattern, such as 'yyyy-MM-dd HH:mm'.
function system.date(pattern)
  return DateTimeFormatter:ofPattern(pattern):format(LocalDateTime:now())
end

return system
