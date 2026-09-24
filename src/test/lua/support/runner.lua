--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

-- Runs one test, turning a failure raised with errors.fail into its message so the report can show it.
local errors = use('core/errors')

return function(test)
  local ok, failure = pcall(test)
  if not ok then error(errors.isFailure(failure) and failure.message or failure, 0) end
end
