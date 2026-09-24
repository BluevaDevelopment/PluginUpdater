--
-- PluginUpdater
-- https://github.com/BluevaDevelopment/PluginUpdater
--
-- Copyright (c) 2026 Blueva Development
--
-- SPDX-License-Identifier: MIT
--

local check = use('support/check')
local versions = use('core/versions')

local suite = {}

function suite.numbersCompareOneByOne()
  check.equals(-1, versions.compare('5.4.137', '5.4.145'))
  check.equals(1, versions.compare('2.10.0', '2.9.9'))
  check.equals(0, versions.compare('1.0', '1.0.0'))
  check.equals(0, versions.compare('v2.22.0', '2.22.0'))
end

function suite.aReleaseIsNewerThanItsPreReleases()
  check.equals(-1, versions.compare('2.20.1-SNAPSHOT', '2.20.1'))
  check.equals(-1, versions.compare('7.4.6-beta-01', '7.4.6'))
  check.equals(-1, versions.compare('1.0.0-beta.2', '1.0.0-beta.10'))
  check.equals(-1, versions.compare('1.0.0-alpha', '1.0.0-rc1'))
end

function suite.storeSuffixesAndBuildTagsDoNotMakeAVersionOlder()
  check.equals(0, versions.compare('v5.5.71-bukkit', '5.5.71'))
  check.equals(0, versions.compare('2.20.1-b456', '2.20.1'))
end

function suite.textWithoutNumbersCannotBeCompared()
  check.equals(nil, versions.compare('latest', '1.0'))
  check.equals('7.4.6-beta-01', versions.find('worldedit-bukkit-7.4.6-beta-01'))
  check.equals('7.4.6', versions.find('WorldEdit 7.4.6 Beta 1 (Bukkit for 1.21.4-26.3)'))
end

return suite
