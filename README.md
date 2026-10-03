# Deathmatch server

An ET: Legacy deathmatch server: everybody is an enemy, Omni-bot bots fill the server up, and
players spawn in hand-drawn spawn squares. Maps can be played as smaller variants with their own
mapscripts (barriers), e.g. `etl_adlernest_first_stage`.

## Files

| Path | What it is |
|---|---|
| `compose.yaml` | The server container (`oksii/etlegacy` image). Mounts the folders below. |
| `maps/` | Map pk3s. |
| `qagame/qagame.mp.x86_64.so` | Custom qagame, see [Building qagame](#building-qagame). |
| `homepath/legacy/maps/<variant>.variant` | Map variant definitions, see [Map variants](#map-variants). |
| `homepath/legacy/deathmatch/<map>.txt` | Spawn squares, one file per BSP, shared by its variants. The server writes these when you draw squares in game. |
| `omni-nav/` | Omni-bot waypoints for maps the image has none for. Each file is mounted in `compose.yaml`. |
| `../legacy-configs/configs/deathmatch.config` | The server config: cvars, Lua modules, map vote settings, `g_excludedMaps`. |
| `../legacy-configs/mapscripts/<map or variant>.script` | Mapscripts. Variants and barriers live here. |
| `../legacy-configs/luascripts/deathmatch_*.lua` | Lua modules: bots and map vote rules, spawns, and the in-game dev tools. |

## Deploying

| Command | What it does |
|---|---|
| `./deploy.sh etserver` | Uploads this folder (without `maps/`) and restarts the server. |
| `./deploy.sh maps` | Uploads `maps/` and restarts the server. |
| `./deploy.sh configs` | Uploads `../legacy-configs/` (configs, mapscripts, Lua) and restarts the server. |
| `./fetch_zones.sh` | Downloads the spawn squares (`homepath/legacy/deathmatch/`) from the server. |

Squares drawn in game are saved on the server only, so run `./fetch_zones.sh` before committing
them, and before `./deploy.sh etserver`, which would otherwise overwrite them with your local copy.

The custom qagame (`qagame/qagame.mp.x86_64.so`, built from the `deatchmatch` branch of etlegacy)
adds the commands below. All of it is server side, so players use the stock ET: Legacy client.

## Building qagame

From the root of the etlegacy checkout, this builds a Linux qagame that works on the
`oksii/etlegacy` image:

```sh
docker run --rm --platform linux/amd64 \
  -v "$PWD":/code -w /code \
  etlegacy/lnx-build:latest \
  bash -c "./easybuild.sh build -64 -mod"
```

Then copy `build/legacy/qagame.mp.x86_64.so` to `etserver/qagame/qagame.mp.x86_64.so`. `compose.yaml`
mounts it into the container, and `./deploy.sh etserver` uploads it and restarts the server.

Players call votes with `\callvote <vote> <args>`. Referees run the same votes right away with
`\ref <vote> <args>`, and they can also run votes that the `vote_allow_*` cvars have turned off.
Typing a vote without arguments, or with `?`, prints its usage and current setting.

## Map variants

A map variant is a regular map (the same BSP) with a mapscript of its own, so one map can have
several layouts, e.g. `etl_adlernest_first_stage` and `etl_adlernest_second_stage`.

- Define a variant with `maps/<variant>.variant` in the homepath. The file holds just the name of
  the regular map, e.g. `homepath/legacy/maps/etl_adlernest_first_stage.variant` contains
  `etl_adlernest`.
- The variant's mapscript is `mapscripts/<variant>.script` (`g_mapScriptDirectory`), or else
  `maps/<variant>.script`. If neither exists, the regular map's script is used.
- The Omni-bot waypoints of the regular map are shared by all of its variants.

### Commands

| Command | Who | What it does |
|---|---|---|
| `mapvariant <variant>` | server console / rcon | Loads the regular map with the variant's mapscript. Prints `Can't find map variant` if the `.variant` file or its BSP is missing. |
| `\callvote mapvariant <variant>` | players (needs `vote_allow_map 1`) | Vote to load a variant. The variant is checked before the vote starts. When the vote passes, the match is reset, the variant loads and `nextmap` is kept. |
| `\ref mapvariant <variant>` | referees | Same as the vote, but runs right away. Works even with `vote_allow_map 0`. |

- A `map_restart` keeps the current variant. Loading a map in any other way (`map`, `\callvote map`,
  `nextmap`) loads the regular map.
- The end-of-map map vote lists the variants next to the regular maps. Only the map or variant
  that was just played is held back from the next vote, not its other variants.
- If a variant's regular map is missing, the variant is skipped and a message is printed in the
  server log.

### Cvars

| Cvar | Description |
|---|---|
| `g_mapVariant` | Read only. The variant being played, empty for the regular map. Lua scripts can read it. |
| `g_mapVariantNext` | Read only. Used internally to pass the variant on to the next map load. |

The server log gets a `mapvariant: <variant>` line after the `map:` line when a variant loads.

## Bots vote

| Command | Who | What it does |
|---|---|---|
| `\callvote bots <0\|1>` | players (needs `vote_allow_bots 1`) | Vote to turn the bots on or off. Sets `g_bots`. |
| `\ref bots <0\|1>` | referees | Same, but runs right away. |

| Cvar | Default | Description |
|---|---|---|
| `g_bots` | `1` | Bots on (1) or off (0). The game doesn't act on it by itself: whatever manages the bots (e.g. a Lua module) has to read it. |
| `vote_allow_bots` | `1` | Allows players to vote on `bots`. |

## Start match vote

| Command | Who | What it does |
|---|---|---|
| `\callvote startmatch` | players (needs `vote_allow_startmatch 1`) | Vote to set everybody ready and start the match. |
| `\ref startmatch` | referees | Same, but runs right away. |

| Cvar | Default | Description |
|---|---|---|
| `vote_allow_startmatch` | `1` | Allows players to vote on `startmatch`. Before this, the vote couldn't be turned off. |

## Removed votes and commands

These have no meaning when everybody is an enemy, so they were removed:

- Votes `shuffleteams`, `shuffleteams_norestart`, `friendlyfire`, `surrender`. Their buttons are
  hidden from players' in-game vote menu. Referees still see them, because the stock client shows
  referees every button, but clicking one does nothing.
- Player command `readyteam`.
- Cvar `g_syringeHealing`.

`\callvote kick` can now target any player. Before, players could only vote to kick
teammates or spectators. The kick vote counts the votes of everybody on the server, not just one team.

## Map vote and bots

`luascripts/deathmatch_bots.lua` has a `MAP_RULES` table, keyed by map or variant name in lower
case. It decides:

- `players = { min, max }`: how many humans must be connected (spectators count) for the map to be
  offered in the end-of-map vote. `-1` means no limit. The script writes these limits to
  `mapvoteplayerscount.cfg`, which the mod reads when a map loads, so a change applies from the
  map after next.
- `bots = { [humans] = bots }`: how many bots to keep while that many humans are on a team. A count
  that isn't listed uses the nearest lower entry.

Current rules:

| Maps | Offered | Bots |
|---|---|---|
| Stage variants (`etl_adlernest_first_stage`, `etl_adlernest_second_stage`, `operation_first_stage`, `supply_last_stage`, `missile_first_stage`) | always | `STAGE_BOTS`: 8 minus 2 per human |
| Small maps (`mp_sillyctf`, `te_valhalla`) | always, but excluded (see below) | `SMALL_BOTS`: 5 minus 1 per human |
| Full maps (`etl_adlernest`, `et_operation_b8`, ...) | from 10 players (`FULL_MAP`) | `DEFAULT_BOTS` |

Maps in `g_excludedMaps` (`deathmatch.config`) never show up in the vote, whatever `MAP_RULES`
says. That keeps out maps without spawn squares or waypoints yet (e.g. `supply`, `radar`). The list
matches the name in the vote, so excluding a map doesn't exclude its variants.

Players can turn the bots off with `\callvote bots 0`. They stay off while anyone is playing and
come back once nobody is on a team. At intermission the map vote ends as soon as every human has
voted.

## Dev tools: spawn squares and barriers

`luascripts/deathmatch_squares.lua` adds console commands for drawing spawn squares and barriers
in game. It's loaded through `lua_modules` in `deathmatch.config`, and anyone on the server can use
it, so take it out once the maps are done. `/phelp` lists the commands in game.

### Spawn squares

Humans respawn at a random spot in one of the map's squares, and bots spawn in squares too
(see `deathmatch_spawns.lua`). Squares are saved to `homepath/legacy/deathmatch/<map>.txt`, one
per line: `x1 y1 x2 y2 z [variant ...]`. A regular map uses every square in its file. A variant
uses only the squares tagged with its name.

| Command | What it does |
|---|---|
| `/phelp` | Lists the commands and shows which map or variant is being played. |
| `/pshow` | Turns the outlines on or off for you (off at first). Green: the square you're in. Red: other squares. Yellow: the one being drawn. Blue: squares this variant doesn't use. |
| `/ppos` | Prints your position. |
| `/pcorner [variant] [label]` | Stand in one corner and use it, then walk to the opposite corner and use it again to add the square. With a variant name, the square is tagged with it. |
| `/pcancel` | Forgets the first corner. |
| `/pinfo` | Shows the square you're in, or the nearest one. |
| `/ptest` | Teleports you to a random spot in that square. |
| `/ptag <variant> [...]` | Tags the square you're in with variants. |
| `/puntag <variant> [...]` | Removes those tags. |
| `/pdel` | Deletes the square you're in. |
| `/preload` | Re-reads the file after you've edited it by hand. |

### Barriers

Barriers are invisible walls (`func_fakebrush`) in a variant's mapscript. They aren't saved by the
server: each one is printed as a `create` block to paste into the mapscript.

| Command | What it does |
|---|---|
| `/bcorner [height] [solid]` | Stand in one corner, then in the opposite one. The barrier spans between the two spots, from the lower floor up to `height` (default 256) above the higher one. It blocks players only, or shots too with `solid`. |
| `/bcancel` | Forgets the first corner. |
| `/btest` | Turns the barriers made this level on or off, to try them. |
| `/bundo` | Drops the last barrier made this level. |
| `/blist` | Prints the barriers made this level again. |

Outlines (with `/pshow`): magenta for barriers already in the mapscript, cyan for ones made this
level.

Copy the `create` blocks from the server console or `etconsole.log`, since the client console shows
`'` instead of `"`. Paste them into `game_manager` → `spawn` in
`../legacy-configs/mapscripts/<variant>.script`, under the barriers comment. The origin's z is the
floor height, and `maxs` is the size. To leave a gap in a barrier, split it into boxes around the
gap.

## Adding a map variant

Using `supply_last_stage` as the example:

1. Create `homepath/legacy/maps/supply_last_stage.variant` containing the BSP name, `supply`.
2. Copy the map's mapscript to `../legacy-configs/mapscripts/supply_last_stage.script`. The base
   script must already have the `deathmatch_removals` block, which removes doors, windows and
   objectives.
3. Add it to `MAP_RULES` in `deathmatch_bots.lua`, e.g. `supply_last_stage = { bots = STAGE_BOTS }`.
4. Make sure the BSP has Omni-bot waypoints: the image's own, or files in `omni-nav/` mounted in
   `compose.yaml`.
5. Deploy (`./deploy.sh configs` and `./deploy.sh etserver`), then load it: `\ref mapvariant
   supply_last_stage` or `rcon mapvariant supply_last_stage`.
6. In game, draw squares with `/pcorner supply_last_stage` (or tag existing ones with `/ptag`), and
   barriers with `/bcorner`. Paste the barriers into the script and redeploy configs.
7. Run `./fetch_zones.sh` to get the squares back, and commit both repositories.
