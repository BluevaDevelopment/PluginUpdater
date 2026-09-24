--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

local changelog = use('server/changelog')
local check = use('support/check')

local suite = {}

function suite.eachRunAddsASectionOnTop()
  local first = changelog.prepend(nil, '2026-09-24 10:00', {
    { name = 'LuckPerms', from = '5.4.137', to = '5.5.71' },
    { name = 'Vault', to = '1.7.3' },
  })
  check.equals('# Changelog\n\n## 2026-09-24 10:00\n\n- LuckPerms 5.4.137 -> 5.5.71\n- Vault (new) -> 1.7.3\n', first)

  local second = changelog.prepend(first, '2026-09-25 10:00', { { name = 'Vault', from = '1.7.3', to = '1.7.4' } })
  check.equals('# Changelog\n\n## 2026-09-25 10:00\n\n- Vault 1.7.3 -> 1.7.4\n\n## 2026-09-24 10:00\n\n'
    .. '- LuckPerms 5.4.137 -> 5.5.71\n- Vault (new) -> 1.7.3\n', second)
end

return suite
