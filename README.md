# Midnight Hatch

Steal an egg from a sleeping monster, run it home before she catches you, and hatch a weird pet
that makes you better at the next heist. A Roblox game for ages 10 to 17, phone first, built round
by round by Claude and ChatGPT, with Hayk passing the messages.

**Status: Round 1, the first playable build.** It has one moonlit forest, one guardian (Mama Moss),
three eggs, six pets with jobs, the Dusk and Midnight cycle, Giant-egg helpers, the HUD, the hatch
reveal and the pets panel. Data lives in memory only; saving comes in Round 2.

- Design: [`docs/DESIGN.md`](docs/DESIGN.md)
- Every round, including ChatGPT's Round 0 word for word: [`docs/ROUNDS.md`](docs/ROUNDS.md)
- Every file and who last changed it: [`FILE_LIST.md`](FILE_LIST.md)

## Put it in Studio (Rojo 7.7)

1. Copy this folder over your project folder (`~/RobloxGame`, or `/Users/goat/claude/MidnightHatch`).
   Keep the `src/` layout: `default.project.json` maps it to the Roblox services and is unchanged.
2. **Delete these four prototype files**, which this build replaces. Rojo then removes them from
   Studio too:
   - `src/ServerScriptService/Currency.server.lua`
   - `src/ServerScriptService/EggSystem.server.lua`
   - `src/ServerScriptService/MapGenerator.server.lua`
   - `src/ServerScriptService/PlotManager.server.lua`
3. In Studio, delete the objects the prototype asked you to make by hand, if they exist:
   `Workspace > Egg` and `ReplicatedStorage > RemoteEvents`. The game now makes its own remotes. If
   you forget, the old egg is also removed while you play.
4. Run `rojo serve default.project.json` and connect the Rojo plugin.
5. Press **Play**.

No other Studio settings are needed for Round 1 (no DataStores yet). R6 and R15 avatars both work.

## What you should see

- **Output:** `[MapService] Built the forest: 496 parts.` and
  `[Main] Midnight Hatch 0.1.0 (Round 1 first playable) is running.`, with no red errors.
- **The Hatchery:** you spawn inside a warm, lantern-lit enclosure. The top of the screen shows
  "🌆 Midnight in 4:00" and the Wake meter ("😴 Mama Moss is asleep"). Shells and the 🐾 PETS button
  sit on the left. The bottom line says to grab an egg.
- **A practice egg:** walk out through the gate. A small egg sits on the trail. The **GRAB** button
  appears (on a phone, just left of the jump button). Tap it (or press E). The egg rides above your
  head, you slow down, and a **DROP** button appears (Q).
- **Hatching:** walk back inside the fence. The egg wobbles, flashes and reveals a pet with its job
  and "+5 🐚". The pet now follows you.
- **The nest:** follow the trail to Mama Moss (purple "MAMA MOSS'S NEST" label).
  - Grab a Pebble: the meter barely moves.
  - Grab a Moss egg: it climbs to about 40%.
  - Grab the Giant egg: the meter fills, she roars ("!" over her head, the screen shakes) and she
    chases you. The edges of your screen glow red and the status line says "RUN!".
- **Getting caught:** you drop the egg, get shoved and are dizzy for 1.6 seconds. Anyone can grab
  the dropped egg after a moment.

## Two-player checks (Test > Clients and Servers > 2 players)

- Both players stand at the same egg and tap GRAB together: exactly one gets it, and the other sees
  "Too slow!".
- Player 1 grabs the Giant egg. Player 2 walks up and taps **HELP**: a glowing rope links them and
  Player 1 speeds up. Walk into the Hatchery together and **both** get a hatch.
- One player drops an egg (Q): nobody can grab it for a moment, then anyone can.

## Studio-only test keys

| Key | Does |
|---|---|
| F6 | Midnight now (purple sky, glowing eggs, Mama Moss patrols) |
| F7 | Back to Dusk |
| F8 | Wake Mama Moss |
| F9 | +1000 Shells |

The server ignores these outside Studio.

## Phone layout

Use the **Device emulator** (Test > Device). Try a small phone (for example iPhone SE) and a large
one. The GRAB button must not cover the jump button, and every label must fit.

## Automated checks (no Studio needed)

They need [Lune](https://github.com/lune-org/lune), [selene](https://github.com/Kampfkarren/selene)
and [StyLua](https://github.com/JohnnyMorganz/StyLua) (`cargo install lune selene stylua`).

```sh
lune run tests/run.luau     # 26 unit tests: odds, pets, noise meter, egg ledger (contention, one reward, locks, helpers)
lune run tests/smoke.luau   # 66 integration checks: real server + client scripts in a simulated DataModel (~80 s)
selene src                  # lint
stylua --check src tests    # formatting
```

`tests/` and the tool configs are not part of the Roblox place; Rojo ignores them.

## Layout

```
default.project.json                      Rojo: src/ -> ReplicatedStorage.Modules, ServerScriptService, StarterPlayerScripts
src/ReplicatedStorage/Modules/            shared: GameConfig (every number), PetCatalog, RarityTable, PetModels, Net
src/ServerScriptService/Main.server.lua   starts the services, routes and rate-limits client requests
src/ServerScriptService/Services/         MapService, PlayerDataService, CycleService, PetService, GuardianService,
                                          EggService, EggLedger (pure rules, unit-tested)
src/StarterPlayer/StarterPlayerScripts/   MainUI (HUD, buttons, reveal, pets panel), WorldFX (lighting, pets, effects)
tests/                                    run.luau (unit), smoke.luau (integration)
docs/                                     DESIGN.md, ROUNDS.md
```
