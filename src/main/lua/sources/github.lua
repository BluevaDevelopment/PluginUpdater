--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- GitHub releases.
local errors = use('core/errors')
local installed = use('server/installed')
local net = use('core/net')
local text = use('core/text')

local API = 'https://api.github.com'

-- Words in a file name that say which platform a jar is for.
local OWN = {
  paper = { 'paper', 'bukkit', 'spigot', 'folia', 'purpur' },
  velocity = { 'velocity' },
  waterfall = { 'bungee', 'waterfall' },
}
local ALL = { 'paper', 'bukkit', 'spigot', 'folia', 'purpur', 'velocity', 'bungee', 'waterfall',
  'fabric', 'forge', 'neoforge', 'quilt', 'sponge', 'standalone' }

local github = {
  name = 'github',
  label = 'GitHub',
  example = 'https://github.com/<owner>/<repository>',
}

function github.parse(url)
  local owner, repository = url:match('^https?://github%.com/([^/?#]+)/([^/?#]+)')
  if owner then return { owner = owner, repository = (repository:gsub('%.git$', '')) } end
end

function github.link(ref)
  return 'https://github.com/' .. ref.owner .. '/' .. ref.repository
end

local function get(url, context)
  local headers = { Accept = 'application/vnd.github+json', ['X-GitHub-Api-Version'] = '2022-11-28' }
  if context.tokens and context.tokens.github then headers.Authorization = 'Bearer ' .. context.tokens.github end
  local response = net.request('GET', url, { headers = headers })
  if response.status == 404 then return nil end
  if (response.status == 403 or response.status == 429) and response.header('x-ratelimit-remaining') == '0' then
    errors.fail("GitHub's hourly request limit is used up; set tokens.github in the configuration or GITHUB_TOKEN to raise it")
  end
  if response.status < 200 or response.status > 299 then errors.fail(url .. ' answered HTTP ' .. response.status) end
  return json:decode(response.text)
end

-- The newest release: the one GitHub marks latest, or with a beta or alpha channel, any non-draft one.
local function release(ref, context)
  local base = API .. '/repos/' .. ref.owner .. '/' .. ref.repository .. '/releases'
  if context.channel == 'release' then return get(base .. '/latest', context) end
  for _, candidate in ipairs(get(base .. '?per_page=20', context) or {}) do
    if not candidate.draft then return candidate end
  end
end

-- How well a jar fits the plugin and platform, and the length of its name
-- without the version: the main jar usually has the shortest one.
local function score(fileName, name, platform)
  local stem = fileName:lower():gsub('%.jar$', '')
  local own = {}
  for _, word in ipairs(OWN[platform]) do own[word] = true end
  local points = 0
  for _, word in ipairs(ALL) do
    if stem:find(word, 1, true) then points = points + (own[word] and 3 or -10) end
  end
  local base = text.key((stem:gsub('[%-_]?v?%d.*$', '')))
  if base == text.key(name) then
    points = points + 5
  elseif base:sub(1, #text.key(name)) == text.key(name) then
    points = points + 2
  end
  return points, #base
end

-- The jar of a release the plugin needs: the one matching the entry's asset glob,
-- the only jar, or the one whose name best fits the plugin and platform.
function github.pickAsset(assets, name, context)
  local jars = {}
  for _, asset in ipairs(assets) do
    local lower = asset.name:lower()
    if lower:match('%.jar$') and not lower:match('sources%.jar$') and not lower:match('javadoc%.jar$') then
      jars[#jars + 1] = asset
    end
  end
  local names = {}
  for _, asset in ipairs(jars) do names[#names + 1] = asset.name end
  local shown = table.concat(names, ', ')

  local pattern = context.entry and context.entry.asset
  if pattern then
    local matches = {}
    for _, asset in ipairs(jars) do
      if text.glob(pattern, asset.name) then matches[#matches + 1] = asset end
    end
    if #matches == 1 then return matches[1] end
    errors.fail((#matches == 0 and 'no jar' or 'several jars') .. " of the release match asset '" .. pattern .. "' (" .. shown .. ')')
  end
  if #jars <= 1 then return jars[1] end

  local best, top, shortest, tied = nil, nil, nil, false
  for _, asset in ipairs(jars) do
    local points, length = score(asset.name, name, context.platform)
    if not top or points > top or (points == top and length < shortest) then
      best, top, shortest, tied = asset, points, length, false
    elseif points == top and length == shortest then
      tied = true
    end
  end
  if tied then errors.fail('the release has several jars (' .. shown .. "); set asset to the one to use, such as asset = \"" .. best.name:gsub('%d[%w%.%-]*%.jar$', '*.jar') .. '"') end
  return best
end

local function asRelease(found, asset)
  local sha256 = asset.digest and asset.digest:match('^sha256:(%x+)$')
  return {
    id = tostring(found.id) .. '/' .. tostring(asset.id),
    version = found.tag_name,
    url = asset.browser_download_url,
    fileName = asset.name,
    hashes = { sha256 = sha256 },
  }
end

function github.latest(ref, context)
  local found = release(ref, context)
  if not found then return nil end
  local asset = github.pickAsset(found.assets or {}, context.name, context)
  if not asset then errors.fail(github.link(ref) .. ' release ' .. found.tag_name .. ' has no jar') end
  return asRelease(found, asset)
end

-- The installed file name with its version as a wildcard, as in 'EssentialsX-*.jar'.
local function installedGlob(plugin)
  if not plugin.version then return nil end
  local first, last = plugin.fileName:find(plugin.version, 1, true)
  if first then return plugin.fileName:sub(1, first - 1) .. '*' .. plugin.fileName:sub(last + 1) end
end

-- The release's jar for an installed plugin, and the asset glob to configure
-- when picking by name alone would choose another jar.
local function assetFor(found, plugin, context)
  local picked, automatic = pcall(github.pickAsset, found.assets or {}, plugin.name, context)
  local glob = installedGlob(plugin)
  if glob then
    local ok, byName = pcall(github.pickAsset, found.assets or {}, plugin.name, setmetatable({ entry = { asset = glob } }, { __index = context }))
    if ok and byName and not (picked and automatic and automatic.id == byName.id) then return byName, glob end
  end
  if picked then return automatic end
end

-- Only follows repositories the plugin or another store links to: context.hints.
function github.search(plugin, context)
  local seen = {}
  for _, hint in ipairs(context.hints or {}) do
    local ref = type(hint) == 'string' and github.parse(hint)
    local link = ref and github.link(ref):lower()
    if ref and not seen[link] then
      seen[link] = true
      local found = release(ref, context)
      local asset, glob = found and assetFor(found, plugin, context)
      if asset then
        local sha256 = asRelease(found, asset).hashes.sha256
        return {
          link = github.link(ref),
          title = ref.owner .. '/' .. ref.repository,
          exact = sha256 ~= nil and sha256 == installed.digest(plugin, 'sha256'),
          asset = glob,
        }
      end
    end
  end
end

return github
