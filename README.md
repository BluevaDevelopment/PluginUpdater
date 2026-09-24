<h1 align="center">PluginUpdater</h1>

<p align="center">
  <strong>Keeps the plugins of a Minecraft server up to date, from every store they are published on. Written in Lua, running on the JVM.</strong>
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-26.1-blue">
  <img alt="Lua" src="https://img.shields.io/badge/Lua-5.5.1-000080?logo=lua&logoColor=white">
  <img alt="Mawu" src="https://img.shields.io/badge/Mawu-26.3-000080">
  <img alt="Kotlin" src="https://img.shields.io/badge/Kotlin-2.4.20-7F52FF?logo=kotlin&logoColor=white">
  <img alt="Java" src="https://img.shields.io/badge/Java-21+-ED8B00?logo=openjdk&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

## Overview

PluginUpdater is a command line tool you drop into the folder of a Paper,
Spigot, Velocity or Waterfall server. Run it, and it replaces every outdated
plugin jar with the newest build from where that plugin is published, keeps
the old jars as a backup, and adds what changed to `changelog.md`:

```markdown
## 2026-09-24 14:07

- Essentials 2.21.0 -> 2.22.0
- LuckPerms 5.5.0 -> 5.5.71
- ViaVersion 5.11.0 -> 5.12.0
```

It does nothing on its own: each plugin is listed in `pluginupdater.toml` with
a link to its page. `pluginupdater detect` finds those links for you.

PluginUpdater is also a showcase for [Mawu](https://github.com/BluevaDevelopment/Mawu):
the tool itself is written in Lua, with Kotlin only as a thin host (see
[Written in Lua](#written-in-lua)).

## Stores

| Store | Link to use |
|---|---|
| [Hangar](https://hangar.papermc.io) | `https://hangar.papermc.io/<owner>/<project>` |
| [Modrinth](https://modrinth.com) | `https://modrinth.com/plugin/<project>` |
| [SpigotMC](https://www.spigotmc.org) | `https://www.spigotmc.org/resources/<name>.<id>/` |
| [GitHub](https://github.com) releases | `https://github.com/<owner>/<repository>` |
| [BukkitDev](https://dev.bukkit.org) | `https://dev.bukkit.org/projects/<project>` |
| [CurseForge](https://www.curseforge.com/minecraft/bukkit-plugins) | `https://www.curseforge.com/minecraft/bukkit-plugins/<project>` |
| Direct link | Any other URL to a jar, such as a CI artifact, or a path to a jar on disk |

Notes:

- **SpigotMC** is read through the [Spiget](https://spiget.org) API, since
  spigotmc.org does not let tools download. Premium resources cannot be
  downloaded. A resource hosted elsewhere is followed when its link is another
  store (such as GitHub) or a jar.
- **CurseForge** only serves its API with a key. Without one, CurseForge links
  are read through dev.bukkit.org's public API, which is the same catalog.
- **GitHub** answers 60 requests an hour without a token. Set `tokens.github`
  or `GITHUB_TOKEN` if you have many GitHub plugins.

## Getting started

Download `pluginupdater-26.1.jar` from the
[latest release](https://github.com/BluevaDevelopment/PluginUpdater/releases/latest)
into the server folder (the one with `plugins/`). It needs Java 21 or newer.

```text
java -jar pluginupdater-26.1.jar detect --write   # find your plugins and write pluginupdater.toml
java -jar pluginupdater-26.1.jar check            # see what would be updated
java -jar pluginupdater-26.1.jar                  # update
```

Stop the server before updating, or restart it afterwards: a running server
keeps using the jars it loaded.

## Commands

| Command | What it does |
|---|---|
| `update` | Replaces outdated plugins, installs configured plugins that are missing, and writes the changelog. This is what runs with no command |
| `check` | Shows what `update` would do, without changing anything |
| `detect` | Looks for every installed plugin in every store and says where it was found and where it was not. `--write` adds what was found to the configuration |
| `init` | Writes a commented `pluginupdater.toml` to start from |
| `sources` | Lists the stores and the links each one takes |

| Option | Meaning |
|---|---|
| `-c`, `--config FILE` | The configuration file. The server folder is the folder it is in. Defaults to `pluginupdater.toml` |
| `-o`, `--only PLUGIN` | With `update` and `check`: only this plugin. Repeatable |
| `-w`, `--write` | With `detect`: add what was found to the configuration |
| `-p`, `--plugins DIR` | With `detect`: the plugins folder, when there is no configuration yet |
| `-v`, `--verbose` | Print more about each step |

The exit code is 0 when everything went well, 1 when a plugin failed, and 2
for a mistake on the command line, so a scheduled run can alert you.

### Detecting plugins

`detect` reads the `plugin.yml` (or `paper-plugin.yml`, `bungee.yml`,
`velocity-plugin.json`) of each jar and asks every store about it:

```text
ViaVersion 5.11.0  ViaVersion-5.11.0.jar
    hangar       same file     https://hangar.papermc.io/ViaVersion/ViaVersion
    modrinth     same file     https://modrinth.com/plugin/viaversion
    spigot       by name       https://www.spigotmc.org/resources/19254/
    github       by name       https://github.com/ViaVersion/ViaVersion
    bukkit       not found
    curseforge   not found
                 -> https://hangar.papermc.io/ViaVersion/ViaVersion
```

- **same file**: the store has this exact jar (matched by its hash).
- **same plugin**: found by name, and the store's newest jar has the same
  main class, so it is the same plugin.
- **by name**: only the name matches. Unrelated plugins often share a name,
  so these are never written to the configuration on their own.
- **other plugin**: a plugin with the same name, but a different one.

GitHub is only asked about repositories the plugin itself or another store
links to. The link chosen for the configuration is the first exact match, then
the first confirmed one, preferring Hangar, Modrinth, GitHub, SpigotMC,
BukkitDev and CurseForge in that order.

## Configuration

```toml
[settings]
plugins-folder = "plugins"   # relative to this file
changelog = "changelog.md"
platform = "paper"           # paper (also Spigot, Bukkit, Folia, Purpur), velocity or waterfall
channel = "release"          # the least stable builds accepted: release, beta or alpha
# minecraft = "1.21.8"       # only builds made for this version, where the store says (Hangar, Modrinth)
backups = 5                  # runs of replaced jars kept in .pluginupdater/backups; 0 keeps none
allow-downgrade = false

[tokens]
# github = ""                # or GITHUB_TOKEN
# curseforge = ""            # or CURSEFORGE_API_KEY

[plugins]
LuckPerms = "https://hangar.papermc.io/LuckPerms/LuckPerms"
Vault = "https://www.spigotmc.org/resources/vault.34315/"

[plugins.EssentialsX]
url = "https://github.com/EssentialsX/Essentials"
asset = "EssentialsX-*.jar"
```

Each entry is named after its plugin, as its `plugin.yml` names it, which is
how the installed jar is found. An entry is either a link, or a table with:

| Key | Meaning |
|---|---|
| `url` | The plugin's page, in any of the forms under [Stores](#stores) |
| `asset` | For GitHub releases with several jars: which one, as a glob such as `Geyser-Spigot.jar` or `EssentialsX-*.jar`. Without it, the jar whose name best fits the plugin and platform is picked |
| `file` | A glob for the installed jar, when its `plugin.yml` name differs from the entry's name |
| `channel` | `release`, `beta` or `alpha` for this plugin only |
| `allow-downgrade` | For this plugin only |
| `enabled` | `false` to leave the plugin alone for now |

## How an update is decided

For each plugin, the store is asked for its newest build that fits the
platform and channel. The build is skipped without downloading when it is the
one installed last time, or when the store publishes a hash that matches the
installed jar. Otherwise it is downloaded (and checked against the store's
hash), and its `plugin.yml` is read:

- A jar of another plugin is refused, which catches wrong links and assets.
- The same file, or the same version, means the plugin is up to date.
- A version older than the installed one is skipped, unless
  `allow-downgrade` is on.
- Otherwise the old jar moves to `.pluginupdater/backups/<date>/`, outside
  the plugins folder, and the new one takes its place.

Every plugin is checked at once, so a run over dozens of plugins takes seconds.
What was installed is kept in `.pluginupdater/state.json`.

## Written in Lua

PluginUpdater is a Lua program. [Mawu](https://github.com/BluevaDevelopment/Mawu)
compiles the scripts under `src/main/lua` into Lua bytecode at build time and
packs them into the jar; at run time they execute on
[Luak](https://github.com/BluevaDevelopment/Luak), a Lua 5.5 runtime for the
JVM.

- **Lua decides everything**: the command line, the configuration, each
  store's API, detection, version comparison, the update plan, backups and
  the changelog. Requests run as coroutines, so every plugin is checked at
  once from a single Lua state. The tests are Lua as well.
- **Kotlin only provides primitives** (`src/main/kotlin/.../host`), installed
  as globals: `http` (background requests and downloads), `fs`, `zip`,
  `json`, `toml`, `term` and `host`. None of them knows about plugins or
  stores.

| Folder | Contents |
|---|---|
| `cli/` | Option parsing, help, and one file per command |
| `core/` | Errors, console output, the coroutine scheduler, requests, version comparison, the store registry |
| `server/` | The configuration, plugin descriptors, the plugins folder, state and changelog |
| `sources/` | One file per store |
| `update/` | Planning and applying a run |
| `detect/` | Finding installed plugins in the stores |

## Building

```text
./gradlew build            # compiles, runs the tests, and writes build/libs/pluginupdater-<version>.jar
./gradlew test -Pnetwork   # also runs the tests that ask the real stores
./gradlew run --args="check"   # runs against run/, a scratch server folder
```

## License

[MIT](LICENSE)
