--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Requests and downloads, waiting through the task scheduler so several
-- plugins can be asked about at once.
local errors = use('core/errors')
local tasks = use('core/tasks')

local net = {}

-- Some stores refuse generic agents: name the tool, its version and where to reach it.
http:userAgent('pluginupdater/' .. host:version() .. ' (https://github.com/BluevaDevelopment/PluginUpdater)')

local function answered(pending, url)
  local failure = pending:failure()
  if failure then errors.fail('Could not reach ' .. url .. ': ' .. failure) end
  return pending
end

-- Sends a request and returns { status, text, url, header(name) }.
-- options: headers (a table), body (a string).
function net.request(method, url, options)
  options = options or {}
  local pending = answered(tasks.await(http:request(method, url, options.headers, options.body)), url)
  return {
    status = pending:status(),
    text = pending:text(),
    url = pending:url(),
    header = function(name) return pending:header(name) end,
  }
end

local function success(response, url)
  if response.status < 200 or response.status > 299 then
    errors.fail(url .. ' answered HTTP ' .. response.status)
  end
  return response
end

-- The parsed JSON of a GET, or nil when it answers 404.
function net.jsonOrNil(url, headers)
  local response = net.request('GET', url, { headers = headers })
  if response.status == 404 then return nil end
  success(response, url)
  return errors.context('Could not read ' .. url, function() return json:decode(response.text) end)
end

function net.json(url, headers)
  return net.jsonOrNil(url, headers) or errors.fail(url .. ' was not found (404)')
end

-- POSTs a table as JSON and returns the parsed answer.
function net.postJson(url, body, headers)
  local all = { ['Content-Type'] = 'application/json' }
  for name, value in pairs(headers or {}) do all[name] = value end
  local response = success(net.request('POST', url, { headers = all, body = json:encode(body) }), url)
  return json:decode(response.text)
end

-- Percent-encodes a query parameter.
function net.encode(text)
  return (tostring(text):gsub('[^%w%-%._~]', function(char) return string.format('%%%02X', string.byte(char)) end))
end

-- Downloads url into target. options: headers, and one of sha1/sha256/sha512/md5 to verify.
-- Returns { url, header(name) } of the answer.
function net.download(url, target, options)
  options = options or {}
  local algorithm, hex
  for _, name in ipairs({ 'sha512', 'sha256', 'sha1', 'md5' }) do
    if options[name] then algorithm, hex = name, options[name] break end
  end
  local transfer = tasks.await(http:download(url, target, options.headers, algorithm, hex))
  local failure = transfer:failure()
  if failure then errors.fail('Could not download ' .. url .. ': ' .. failure) end
  if transfer:status() == 404 then errors.fail(url .. ' was not found (404)') end
  if transfer:status() < 200 or transfer:status() > 299 then
    errors.fail('Could not download ' .. url .. ': HTTP ' .. transfer:status())
  end
  return { url = transfer:url(), header = function(name) return transfer:header(name) end }
end

return net
