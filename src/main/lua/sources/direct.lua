--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Any other link to a jar, or a jar on disk. Without a store to ask, the file
-- is downloaded and its plugin.yml read, unless the server says it has not
-- changed since the last run.
local errors = use('core/errors')
local net = use('core/net')
local text = use('core/text')

local direct = {
  name = 'direct',
  label = 'Direct link',
  example = 'https://example.com/Plugin.jar, or a path such as /opt/jars/Plugin.jar',
}

function direct.parse(url)
  if url:match('^https?://') then return { url = url } end
  if url:match('^file://') then return { path = url:gsub('^file://', '') } end
  if url:sub(1, 1) == '/' or url:match('^%.%.?/') or url:match('^%a:[\\/]') then return { path = url } end
end

function direct.link(ref)
  return ref.url or ref.path
end

function direct.latest(ref, context)
  if ref.path then
    local path = ref.path
    if path:match('^%.') and context.root then path = fs:join(context.root, path) end
    if not fs:isFile(path) then errors.fail('there is no file at ' .. path) end
    local sha1 = fs:digest(path, 'sha1')
    return { id = 'sha1:' .. sha1, path = path, fileName = fs:name(path), hashes = { sha1 = sha1 } }
  end

  local head = net.request('HEAD', ref.url)
  local id
  if head.status >= 200 and head.status <= 299 then
    local tag = head.header('ETag') or head.header('Last-Modified')
    if tag then id = tag .. '|' .. (head.header('Content-Length') or '') end
  end
  local name = text.fileName(head.url or ref.url)
  return { id = id, url = ref.url, fileName = name and name:lower():match('%.jar$') and name or nil }
end

return direct
