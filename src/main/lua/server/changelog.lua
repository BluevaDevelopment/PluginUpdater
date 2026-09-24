--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- The changelog: one section per run that changed something, newest first,
-- with a line per plugin: '- Name old -> new'.
local changelog = {}

local TITLE = '# Changelog'

-- The line for one change; a plugin that was not installed before shows '(new)'.
function changelog.line(change)
  return '- ' .. change.name .. ' ' .. (change.from or '(new)') .. ' -> ' .. change.to
end

-- The section for one run.
function changelog.section(date, changes)
  local lines = { '## ' .. date, '' }
  for _, change in ipairs(changes) do lines[#lines + 1] = changelog.line(change) end
  return table.concat(lines, '\n')
end

-- The changelog text with a new section on top of what previous runs wrote.
function changelog.prepend(existing, date, changes)
  local section = changelog.section(date, changes)
  local body = existing or ''
  if body:sub(1, #TITLE) == TITLE then body = body:sub(#TITLE + 1) end
  body = body:gsub('^%s+', '')
  if body == '' then return TITLE .. '\n\n' .. section .. '\n' end
  return TITLE .. '\n\n' .. section .. '\n\n' .. body
end

-- Adds a section to the file at path.
function changelog.write(path, date, changes)
  local existing = fs:isFile(path) and fs:read(path) or nil
  fs:write(path, changelog.prepend(existing, date, changes))
end

return changelog
