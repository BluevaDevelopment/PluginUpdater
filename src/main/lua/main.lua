--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- The entry point: reads the command line, runs a command, and turns any
-- failure into a message and an exit code. Returns the function the host calls.
local config = use('server/config')
local errors = use('core/errors')
local help = use('cli/help')
local parser = use('cli/parser')
local ui = use('core/ui')

local OK, FAILED, USAGE = 0, 1, 2

local function commands()
  local list = {}
  for _, id in ipairs({ 'update', 'check', 'detect', 'init', 'sources' }) do
    list[#list + 1] = use('cli/commands/' .. id)
  end
  return list
end

local function run(args)
  local rest = {}
  for _, arg in ipairs(args) do rest[#rest + 1] = arg end

  -- Options before the command belong to pluginupdater itself; --verbose is also accepted after it.
  while rest[1] == '-V' or rest[1] == '--version' or rest[1] == '-h' or rest[1] == '--help'
    or rest[1] == '-v' or rest[1] == '--verbose' do
    local option = table.remove(rest, 1)
    if option == '-V' or option == '--version' then
      ui.say('pluginupdater version ' .. host:version())
      return OK
    elseif option == '-h' or option == '--help' then
      ui.say(help.root(commands()))
      return OK
    else
      ui.verbose = true
    end
  end
  for index = #rest, 1, -1 do
    if rest[index] == '-v' or rest[index] == '--verbose' then
      ui.verbose = true
      table.remove(rest, index)
    end
  end

  -- With no command, a server folder with a configuration is updated; anywhere else, help is shown.
  local name = rest[1]
  if not name or name:sub(1, 1) == '-' then
    if not fs:isFile(config.FILE) and not name then
      ui.say(help.root(commands()))
      ui.say("\nThere is no " .. config.FILE .. " here. Run 'pluginupdater init' or 'pluginupdater detect --write' to start.")
      return USAGE
    end
    name = 'update'
  else
    table.remove(rest, 1)
  end

  for _, command in ipairs(commands()) do
    if command.name == name then
      local ok, values = pcall(parser.parse, command, rest)
      if not ok then
        if errors.isFailure(values) and values.usage then
          ui.say(help.usage(command) .. '\n')
          ui.error(values.message)
          return USAGE
        end
        error(values, 0)
      end
      if values.help then
        ui.say(help.command(command))
        return OK
      end
      return command.run(values) or OK
    end
  end
  errors.usage("no such command '" .. name .. "'. See 'pluginupdater --help'.")
end

return function(args)
  local ok, result = pcall(run, args)
  if ok then return result end
  ui.error(errors.message(result))
  return (errors.isFailure(result) and result.usage) and USAGE or FAILED
end
