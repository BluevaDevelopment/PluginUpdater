--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Help text for the root command and for each command.
local ui = use('core/ui')

local help = {}

local function rows(list)
  local width = 0
  for _, row in ipairs(list) do width = math.max(width, #row[1]) end
  local lines = {}
  for _, row in ipairs(list) do lines[#lines + 1] = '  ' .. ui.pad(row[1], width) .. '  ' .. row[2] end
  return table.concat(lines, '\n')
end

function help.usage(command)
  local text = 'Usage: pluginupdater ' .. command.name
  if command.options and #command.options > 0 then text = text .. ' [<options>]' end
  for _, argument in ipairs(command.arguments or {}) do
    text = text .. (argument.optional and (' [<' .. argument.name .. '>]') or (' <' .. argument.name .. '>'))
  end
  return text
end

function help.command(command)
  local options = {}
  for _, option in ipairs(command.options or {}) do
    local names = (option.short and ('-' .. option.short .. ', ') or '') .. '--' .. option.long
    if not option.flag then names = names .. '=<' .. (option.value or 'value') .. '>' end
    options[#options + 1] = { names, option.help or '' }
  end
  options[#options + 1] = { '-h, --help', 'Show this message and exit' }

  local text = help.usage(command) .. '\n\n  ' .. command.summary .. '\n\nOptions:\n' .. rows(options)
  local arguments = {}
  for _, argument in ipairs(command.arguments or {}) do
    arguments[#arguments + 1] = { '<' .. argument.name .. '>', argument.help or '' }
  end
  if #arguments > 0 then text = text .. '\n\nArguments:\n' .. rows(arguments) end
  return text
end

function help.root(commands)
  local list = {}
  for _, command in ipairs(commands) do list[#list + 1] = { command.name, command.summary } end
  return 'Usage: pluginupdater [<options>] [<command>] [<args>]...\n\n'
    .. '  Keep the plugins of a Minecraft server up to date from Hangar, Modrinth, SpigotMC,\n'
    .. '  GitHub, BukkitDev, CurseForge or direct links. With no command, runs update.\n\n'
    .. 'Options:\n' .. rows({
      { '-v, --verbose', 'Print more about each step' },
      { '-V, --version', 'Show the version and exit' },
      { '-h, --help', 'Show this message and exit' },
    }) .. '\n\nCommands:\n' .. rows(list)
end

return help
