--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

local check = use('support/check')
local descriptor = use('server/descriptor')

local suite = {}

function suite.topLevelScalarsAreRead()
  local values = descriptor.parseYaml(table.concat({
    'name: "LuckPerms"',
    "version: '5.4.137' # the build",
    'main: me.lucko.luckperms.bukkit.loader.BukkitLoaderPlugin',
    'website: https://luckperms.net',
    'authors: [Luck, Other]',
    'commands:',
    '  name: nested, not the plugin name',
    'description: |',
    '  A long text',
  }, '\r\n'))
  check.equals('LuckPerms', values.name)
  check.equals('5.4.137', values.version)
  check.equals('https://luckperms.net', values.website)
  check.equals('Luck', values.authors)
  check.equals(nil, values.description)
end

function suite.jarsOfEveryPlatformAreRecognised()
  local folder = check.folder()
  local paper = fs:join(folder, 'paper.jar')
  zip:write(paper, { ['paper-plugin.yml'] = 'name: Paperish\nversion: 2.0\n', ['plugin.yml'] = 'name: Legacy\nversion: 1.0\n' })
  check.equals('Paperish', descriptor.read(paper).name)

  local velocity = fs:join(folder, 'velocity.jar')
  zip:write(velocity, { ['velocity-plugin.json'] = '{"id":"proxied","name":"Proxied","version":"3.1","url":"https://example.com"}' })
  local found = descriptor.read(velocity)
  check.equals({ 'Proxied', '3.1', 'https://example.com' }, { found.name, found.version, found.website })

  local library = fs:join(folder, 'library.jar')
  zip:write(library, { ['META-INF/MANIFEST.MF'] = 'Manifest-Version: 1.0\n' })
  check.equals(nil, descriptor.read(library))
  fs:delete(folder)
end

return suite
