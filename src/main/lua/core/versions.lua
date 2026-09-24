--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Reading and comparing the version strings plugins carry, which follow no
-- single scheme: '5.4.137', 'v2.22.0', '7.4.6-beta-01', '2.20.1-SNAPSHOT'.
local versions = {}

-- Lower is less stable; a version with none of these words is a release.
local RANKS = {
  snapshot = -4, nightly = -4, dev = -4,
  alpha = -3,
  beta = -2,
  pre = -1, rc = -1, cr = -1,
}

-- The numbers, stability and trailing build number of a version, or nil when it has no number.
function versions.parse(text)
  if type(text) ~= 'string' then return nil end
  local lower = text:lower()
  local start = lower:find('%d')
  if not start then return nil end
  local head, rest = lower:sub(start):match('^([%d%.]*%d)(.*)$')
  local numbers = {}
  for number in head:gmatch('%d+') do numbers[#numbers + 1] = tonumber(number) end
  local rank = 0
  for word in rest:gmatch('%a+') do
    if RANKS[word] and RANKS[word] < rank then rank = RANKS[word] end
  end
  return { numbers = numbers, rank = rank, build = tonumber(rest:match('(%d+)%D*$')) }
end

-- -1, 0 or 1 as a is older, the same as, or newer than b; nil when either cannot be read.
function versions.compare(a, b)
  local left, right = versions.parse(a), versions.parse(b)
  if not left or not right then return nil end
  for index = 1, math.max(#left.numbers, #right.numbers) do
    local x, y = left.numbers[index] or 0, right.numbers[index] or 0
    if x ~= y then return x < y and -1 or 1 end
  end
  if left.rank ~= right.rank then return left.rank < right.rank and -1 or 1 end
  if left.rank < 0 and left.build and right.build and left.build ~= right.build then
    return left.build < right.build and -1 or 1
  end
  return 0
end

-- The first thing that looks like a version inside a longer text, such as a file's title.
function versions.find(text)
  if type(text) ~= 'string' then return nil end
  return text:match('%d+%.%d+[%w%.%-]*') or text:match('%d+')
end

-- The stability words a store might use, as a rank: 0 release, -2 beta, -3 alpha.
function versions.channelRank(name)
  if name == 'release' then return 0 end
  if name == 'beta' then return -2 end
  if name == 'alpha' then return -3 end
end

-- The rank of a channel or tag name a store shows, such as 'Release' or 'Snapshot'.
function versions.stability(text)
  local rank = 0
  for word in tostring(text or ''):lower():gmatch('%a+') do
    if RANKS[word] and RANKS[word] < rank then rank = RANKS[word] end
  end
  return rank
end

return versions
