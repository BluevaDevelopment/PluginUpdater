--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Decides what one configured plugin needs: nothing, an update, a first
-- install, or nothing because the store only offers something older. The
-- new jar is downloaded into the staging folder when it has to be looked at.
local config = use('server/config')
local descriptor = use('server/descriptor')
local errors = use('core/errors')
local installed = use('server/installed')
local net = use('core/net')
local state = use('server/state')
local text = use('core/text')
local ui = use('core/ui')
local versions = use('core/versions')

local plan = {}

-- The file name a download announces in Content-Disposition, if any.
local function disposition(answer)
  local header = answer and answer.header('Content-Disposition')
  local name = header and (header:match('filename%*?=%s*"([^"]+)"') or header:match("filename%*?=%s*[%w%-]*''([^;]+)")
    or header:match('filename%*?=%s*([^;]+)'))
  return name and name:lower():match('%.jar%s*$') and text.trim(name) or nil
end

-- Puts the release's jar at target and returns the file name it came with, if it had one.
local function fetch(release, target)
  if release.path then
    fs:copy(release.path, target)
    return release.fileName
  end
  local hashes = release.hashes or {}
  local answer = net.download(release.url, target, {
    headers = release.headers,
    sha512 = hashes.sha512, sha256 = hashes.sha256, sha1 = hashes.sha1, md5 = hashes.md5,
  })
  if release.fileName or release.unnamed then return release.fileName end
  local name = disposition(answer) or text.fileName(answer.url or release.url)
  return name and name:lower():match('%.jar%s*$') and name or nil
end

local function current(entry, plugin, release, remember)
  return {
    name = entry.name, action = 'current', version = plugin.version,
    remember = remember and release.id and { release = release.id, sha1 = installed.digest(plugin, 'sha1') } or nil,
  }
end

-- Whether a store's own version name agrees with the one inside its jar. When
-- it does not, the store may be serving a stale file, so the build is not
-- remembered and the next run looks again.
local function agrees(release, version)
  return not release.version or versions.compare(release.version, version) == 0
end

-- One entry's outcome: { name, action, version, from, to, store, staged, fileName, plugin, remember, message }.
-- action is 'current', 'update', 'install' or 'skip'; errors are raised.
function plan.entry(loaded, plugins, remembered, entry, staging, index)
  local plugin = installed.find(plugins, entry)
  local release = entry.store.latest(entry.ref, config.context(loaded, entry))
  if not release then
    return {
      name = entry.name, action = 'skip', version = plugin and plugin.version,
      message = 'no ' .. entry.channel .. ' build for ' .. loaded.platform,
    }
  end

  if plugin then
    local last = state.get(remembered, entry.name)
    if last and release.id and last.release == release.id and last.sha1 == installed.digest(plugin, 'sha1') then
      ui.detail(entry.name .. ': the store still offers the build installed last time')
      return current(entry, plugin, release, false)
    end
    for algorithm, hex in pairs(release.hashes or {}) do
      if hex and installed.digest(plugin, algorithm) == hex:lower() then return current(entry, plugin, release, true) end
    end
  end

  local staged = fs:join(staging, index .. '-' .. text.safeFileName(entry.name) .. '.jar')
  ui.detail(entry.name .. ': fetching ' .. (release.url or release.path))
  local fileName = fetch(release, staged)
  local found = descriptor.read(staged)
  if not found then errors.fail('the file from ' .. (release.url or release.path) .. ' is not a plugin jar') end
  local expected = plugin and plugin.name or entry.name
  if text.key(found.name) ~= text.key(expected) then
    errors.fail("the download is the plugin '" .. found.name .. "', not '" .. expected .. "'; check its link"
      .. (entry.store.name == 'github' and ' or set asset' or ''))
  end
  found.version = found.version or release.version or '?'
  fileName = fileName or text.safeFileName(found.name .. '-' .. found.version) .. '.jar'
  local sha1 = fs:digest(staged, 'sha1')

  if plugin then
    if sha1 == installed.digest(plugin, 'sha1') or found.version == plugin.version then
      fs:delete(staged)
      return current(entry, plugin, release, agrees(release, found.version))
    end
    local order = versions.compare(found.version, plugin.version)
    if order and order < 0 and not entry.allowDowngrade then
      fs:delete(staged)
      return {
        name = entry.name, action = 'skip', version = plugin.version,
        message = 'the newest build, ' .. found.version .. ', is older than the installed ' .. plugin.version,
      }
    end
  end

  return {
    name = entry.name,
    action = plugin and 'update' or 'install',
    from = plugin and plugin.version,
    to = found.version,
    store = entry.store.name,
    staged = staged,
    fileName = fileName,
    plugin = plugin,
    remember = release.id and agrees(release, found.version) and { release = release.id, sha1 = sha1 } or { sha1 = sha1 },
  }
end

return plan
