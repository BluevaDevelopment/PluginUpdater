--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Everything PluginUpdater prints. The status line is redrawn in place on a
-- terminal; elsewhere it is left out, so logs stay readable.
local ui = { verbose = false }

local function style(text, code)
  if term:color() then return '\27[' .. code .. 'm' .. text .. '\27[0m' end
  return text
end

ui.style = style

function ui.say(text) term:out(text) end

-- A stage of the run.
function ui.step(text) term:out(style('==> ', '34') .. style(text, '1')) end

function ui.info(text) term:out('    ' .. text) end

-- Only with --verbose.
function ui.detail(text)
  if ui.verbose then term:out(style('    ' .. text, '2')) end
end

function ui.warn(text) term:out(style('    warning: ', '33') .. text) end

function ui.success(text) term:out(style('==> ', '32') .. style(text, '1')) end

function ui.error(text) term:err(style('error: ', '31') .. text) end

-- Pads text to width, counting what is printed rather than escape codes.
function ui.pad(text, width)
  local shown = text:gsub('\27%[[%d;]*m', '')
  return text .. string.rep(' ', math.max(width - #shown, 0))
end

-- A live 'label 3/10' counter for work done in the background.
function ui.counter(label)
  return {
    set = function(done, total) term:live('    ' .. label .. ' ' .. done .. '/' .. total) end,
    close = function() term:clear() end,
  }
end

return ui
