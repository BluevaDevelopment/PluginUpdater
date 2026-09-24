--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Small string helpers shared by stores and commands.
local text = {}

function text.trim(value)
  return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- A name reduced to letters and digits, for comparing 'Luck Perms' with 'luckperms'.
function text.key(value)
  return (tostring(value or ''):lower():gsub('[^%w]', ''))
end

-- True when name matches a glob with * and ?, ignoring case.
function text.glob(pattern, name)
  local lua = pattern:lower():gsub('[%^%$%(%)%%%.%[%]%+%-]', '%%%0'):gsub('%*', '.*'):gsub('%?', '.')
  return name:lower():match('^' .. lua .. '$') ~= nil
end

-- The file name at the end of a URL, without its query.
function text.fileName(url)
  local name = url:match('^[^?#]*/([^/?#]+)')
  return name and name:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end)
end

-- A string safe as a file name.
function text.safeFileName(value)
  return (value:gsub('[^%w%.%-_+]', '_'))
end

return text
