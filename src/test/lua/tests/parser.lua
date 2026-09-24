--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

local check = use('support/check')
local parser = use('cli/parser')

local suite = {}

local command = {
  name = 'update',
  options = {
    { long = 'config', short = 'c', value = 'file', default = 'pluginupdater.toml' },
    { long = 'only', short = 'o', multiple = true },
    { long = 'write', short = 'w', flag = true },
  },
}

function suite.optionsAndDefaults()
  local values = parser.parse(command, { '-o', 'Vault', '--only=LuckPerms', '-w' })
  check.equals({ 'Vault', 'LuckPerms' }, values.only)
  check.equals('pluginupdater.toml', values.config)
  check.equals(true, values.write)
end

function suite.mistakesAreUsageErrors()
  check.fails('no such option: --nope', parser.parse, command, { '--nope' })
  check.fails('--config needs a value', parser.parse, command, { '--config' })
  check.fails('unexpected argument: extra', parser.parse, command, { 'extra' })
  check.equals({ help = true }, parser.parse(command, { '--nope', '-h' }))
end

return suite
