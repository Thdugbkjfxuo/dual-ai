# Shared file list: Round 1

Paths are relative to the project root (`~/RobloxGame`, or Hayk's copy at
`/Users/goat/claude/MidnightHatch`). "In Studio" means Rojo syncs the file into the place.
`.DS_Store` files are excluded.

| File | In Studio | What it is | Last changed by |
|---|---|---|---|
| `default.project.json` | (config) | Rojo project, unchanged | Previous editor unknown (copied unchanged by ChatGPT) |
| `README.md` | no | setup, what you should see, test steps | Claude (Round 1) |
| `FILE_LIST.md` | no | this list | Claude (Round 1) |
| `docs/DESIGN.md` | no | the combined design | Claude (Round 1), new |
| `docs/ROUNDS.md` | no | round log; ChatGPT's Round 0 kept word for word | Claude (Round 1), new |
| `src/ReplicatedStorage/Modules/GameConfig.lua` | yes | every tunable number | Claude (Round 1), new |
| `src/ReplicatedStorage/Modules/PetCatalog.lua` | yes | six pets, their jobs, key parsing | Claude (Round 1), new |
| `src/ReplicatedStorage/Modules/RarityTable.lua` | yes | rarity tiers and the weighted roll | Claude (Round 1), rewritten |
| `src/ReplicatedStorage/Modules/PetModels.lua` | yes | builds pets and eggs from parts | Claude (Round 1), new |
| `src/ReplicatedStorage/Modules/Net.lua` | yes | creates or waits for the RemoteEvents | Claude (Round 1), new |
| `src/ServerScriptService/Main.server.lua` | yes | starts the services; routes and rate-limits requests | Claude (Round 1), new |
| `src/ServerScriptService/Services/MapService.lua` | yes | builds the forest, Hatchery and nest | Claude (Round 1), new (replaces MapGenerator) |
| `src/ServerScriptService/Services/PlayerDataService.lua` | yes | Shells, pets, stats, leaderstats (in memory) | Claude (Round 1), new (replaces Currency) |
| `src/ServerScriptService/Services/CycleService.lua` | yes | Dusk and Midnight clock | Claude (Round 1), new |
| `src/ServerScriptService/Services/PetService.lua` | yes | equipping pets, pet perks | Claude (Round 1), new |
| `src/ServerScriptService/Services/GuardianService.lua` | yes | Mama Moss: model, Wake meter, chase AI | Claude (Round 1), new |
| `src/ServerScriptService/Services/EggService.lua` | yes | claim, carry, help, drop, bank, hatch | Claude (Round 1), new (replaces EggSystem) |
| `src/ServerScriptService/Services/EggLedger.lua` | yes | pure egg rules: one claim, one reward | Claude (Round 1), new |
| `src/StarterPlayer/StarterPlayerScripts/MainUI.client.lua` | yes | HUD, action buttons, reveal, pets panel | Claude (Round 1), rewritten |
| `src/StarterPlayer/StarterPlayerScripts/WorldFX.client.lua` | yes | lighting, pet followers, guardian cues, effects | Claude (Round 1), new |
| `tests/run.luau` | no | unit tests (Lune) | Claude (Round 1), new |
| `tests/smoke.luau` | no | integration test (Lune) | Claude (Round 1), new |
| `selene.toml` | no | lint settings | Claude (Round 1), new |
| `roblox_lite.yml` | no | Roblox globals for selene | Claude (Round 1), new |
| `stylua.toml` | no | formatting settings | Claude (Round 1), new |
| `.gitignore` | no | git ignore rules | Claude (Round 1), new |

**Deleted in Round 1** (remove them from your folder; Rojo then removes them from Studio):

| File | Replaced by |
|---|---|
| `src/ServerScriptService/Currency.server.lua` | `PlayerDataService.lua` |
| `src/ServerScriptService/EggSystem.server.lua` | `EggService.lua` + `EggLedger.lua` |
| `src/ServerScriptService/MapGenerator.server.lua` | `MapService.lua` |
| `src/ServerScriptService/PlotManager.server.lua` | `MapService.lua` (one shared Hatchery; no plots in this design) |
