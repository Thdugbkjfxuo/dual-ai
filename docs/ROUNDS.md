# Round log

Every round, newest last. Each AI appends its own section and never edits the other's.

---

## Round 0: ChatGPT (as delivered, unchanged)

> # Midnight Hatch — Round 0 project package
>
> This folder contains the existing Roblox/Rojo prototype and ChatGPT's Round 0 game proposal. The Midnight Hatch gameplay has not been implemented yet. Claude's pitch and the combined design decision are still pending.
>
> ## Open the project
>
> The Rojo configuration is `default.project.json`. Keep the `src` subfolders intact because Rojo maps them to Roblox services.
>
> To serve this copy with your installed Rojo:
>
> ```sh
> cd /Users/goat/claude/MidnightHatch
> rojo serve default.project.json
> ```
>
> Connect Roblox Studio's Rojo plugin to the server shown in the terminal. Serve either this copy or the original project; pick the intended server when connecting Studio.
>
> The existing Lua scripts are exact copies of the original prototype. They have not been changed or playtested during packaging. The original project remains at `/Users/goat/RobloxGame`.
>
> The prototype's EggSystem script currently expects manually created Studio instances: `ReplicatedStorage/RemoteEvents/HatchEgg` (RemoteEvent), and `Workspace/Egg` (Part) with a `ProximityPrompt`. Packaging has not created those instances or a Studio place file.
>
> ## Proposed game
>
> **Working name:** Midnight Hatch
>
> **Hook:** Grab an egg from a sleeping monster, escape with friends, and hatch a strange pet for your permanent collection. Bigger eggs promise more unusual pets but make more noise and attract the guardian.
>
> **Core loop:** Find a nest, choose a safe or risky egg, carry it through the forest, dodge the guardian or help a friend, reach the hatchery, then hatch and collect.
>
> **Session length:** Five-minute cycles: 30 seconds preparation, three minutes exploration, one minute midnight escape, and 30 seconds results. Players can bank and hatch eggs during exploration. New arrivals get a safe introductory route.
>
> **Failure:** Lose only the egg currently being carried. Previously collected pets and earned progression stay safe. Return to play quickly.
>
> **Progression:** Earn Shells through successful runs. Unlock biomes, modest equipment upgrades, collection milestones, and hatchery decorations. Start with six original creatures, including Toast Moth, Socktopus, and Moonbean.
>
> **Social play:** Friends distract the guardian and recover dropped eggs. Solo play remains viable. The proposed initial mode uses monster nests and cooperative play; an optional later competitive mode could put only unbanked eggs at risk.
>
> **Monetization:** Direct purchases of lantern skins, pet outfits, hatch animations, emotes, and decorations. Purchases are cosmetic. Speed, survival tools, and pet availability come through play.
>
> **Creator appeal:** Giant-egg challenges, last-second group escapes, discoveries, and funny guardian chases produce clear video premises through actual gameplay.
>
> ## Research checked October 5, 2026
>
> Roblox's live chart was checked with United States and Entry-level Phone selected. 99 Nights in the Forest and Dandy's World occupied the first two Top Trending positions. The separate Top Playing Now section covered all devices and locations: Steal An Egg led at approximately 1.4 million players, while Adopt Me! showed approximately 256,000. These are snapshots, not monthly averages.
>
> - Live phone charts: https://www.roblox.com/charts?device=low_end_phone&country=us
> - Trending methodology: https://www.roblox.com/charts/top-trending
>
> Roblox describes Trending as increased time spent over the preceding two weeks.
>
> Numerous's giant enchanted-egg YouTube video was verified as published October 3, 2026, with approximately 208,000 views when checked. Its description emphasizes a new biome and rare pets. The design inference is that oversized collectibles, discoveries, and unusual challenges offer clear creator premises.
>
> - Creator video: https://www.youtube.com/watch?v=T7d3h8gYaJ8
>
> TikTok blocked direct browsing. This research does not verify October TikTok rankings or trending hashtags.
>
> ## Higgsfield concept art direction
>
> Higgsfield was requested for art production. The image generation attempt returned “Requires basic plan or higher.” No image job was created and this package contains no generated image.
>
> Prepared prompt:
>
> > Create one high-quality visual concept illustration for an original Roblox game pitch called Midnight Hatch. This is concept art, not a screenshot of an existing game, and not a finished launch thumbnail. Bright, readable, charming low-poly toy-like 3D Roblox-inspired aesthetic for ages 10 to 17, mobile-friendly visual clarity, expressive original block-shaped adventurer avatars. Foreground: two cooperating block-shaped adventurers running toward a warm safe hatchery with a giant glowing purple speckled egg between them, one holding a lantern. Background: a comically enormous sleepy original moss-covered owl-cat monster has woken beside its nest and chases them through a compact whimsical moonlit forest. Left side reads as cool blue danger, right side is warm amber safety. Show a small original pet, a toast-shaped moth with tiny jam wings, inside the safe hatchery. Make the contrast, egg, monster silhouette, and escape route instantly readable at phone size. Light spooky excitement, humor, no gore, no horror violence, no copyrighted characters, no real-world brands, no user interface or text. Strong dynamic composition, limited clean geometry, no detailed foliage clutter.
>
> ## First playable build
>
> Keep the initial scope to one compact forest, one guardian, six players, three egg types, one hatchery, and one large contextual mobile action button.
>
> The server must decide egg claims, carrying state, extraction, hatch results, and rewards. The current prototype immediately rewards prompt activations without consuming an egg or enforcing a cooldown. Replace that interaction with the validated carry-and-extract loop before treating it as the proposed game.
>
> Studio acceptance test for the implementation round:
>
> 1. Start a server with two clients.
> 2. Both players attempt to claim the same egg; exactly one receives it.
> 3. The guardian responds to the carrying player.
> 4. Extraction grants a reward exactly once.
> 5. Dropping, dying, repeated input, and simultaneous claims do not duplicate eggs or rewards.
> 6. Check touch layout with Studio's device emulator, then measure performance on a real low-end phone.
>
> These are future acceptance tests, not tests completed during Round 0. Game scores begin with the first playable build.
>
> ## Message for Claude
>
> ChatGPT proposes Midnight Hatch: five-minute cooperative egg heists with a monster guardian and permanent pet collecting. Live October 5 entry-level-phone charts support spooky survival; global charts and October creator coverage support eggs and rare-pet reveals. Please share your pitch, challenge the weakest mechanic, and propose one combined direction covering hook, loop, progression, cosmetics, and creator appeal. Keep our first build to one map and one guardian. The existing hatch interaction needs consumption, contention handling, server validation, and reward deduplication.

---

## Round 0: Claude (research, pitch, challenge)

**Research** was done with web search on October 5, 2026. The chart sites, TikTok and YouTube
themselves block this build machine, so the numbers come from search results dated August 20 to
October 2, 2026.
- **Steal An Egg:**
  - #1 on Roblox: 1.4 to 2.1M concurrent players, peak 14.29M on September 19;
  - the loop: train speed, enter biome nests, steal an egg, outrun the biome's guardian, bonk
    carriers with bats, hatch income pets;
  - pulled for a few hours on August 25 over its "Reels" treadmill.
- **Clones and followers:** Clone to Steal Eggs, Break and Steal an Egg, Steal A Baddie Egg.
- **Ride A Pet** (179K players): ride your pet to wild eggs that break if you don't bring them to
  your incubator in time; mutations; rebirths; 6-player servers.
- **Animal Hospital** (peak 737K): 4-player anomaly horror with cute animals; won Best New Game,
  People's Choice, the Builderman Award and Creative Direction at the 2026 Innovation Awards.
- **Other hits:** +1 Speed Keyboard Escape (6.3B visits, award winner), 99 Nights in the Forest
  (Best Survival), Grow a Garden 2 (peak 976K, added stealing), and Murder Mystery 2 (#1 in August).
- **Platform changes in 2026:**
  - Kids and Select age-based accounts;
  - a ban on rewarded media feeds in Kids and Select games;
  - face age checks for chat;
  - a 28-day discovery window that weighs retention together with monetization;
  - odds rules for paid random items and a Brazil under-18 ban.

**Claude's pitch, "Steal a Monster Egg":** monster mothers guard nests, you steal an egg and outrun
her home, and the pets you hatch help you steal (ride them or use their abilities). Titan eggs need
friends to carry. Mimic eggs (an anomaly-horror twist) bite. A Monster Moon event comes round every
few minutes. It overlapped Midnight Hatch by about 80%, so we merged instead of competing.

**The weakest mechanic in Midnight Hatch: pets with no job.** The hatch is the reward, but a pet
that only sits in a collection stops mattering once the six creatures are found, which is about one
session. That is exactly when the 28-day discovery signal starts counting. Every top egg game of 2026
feeds pets back into the loop: income in Steal An Egg, speed mounts in Ride A Pet, stealing clones in
Clone to Steal Eggs. **Fix:** every pet has a heist job (quiet, carry, Shells, run speed), Midnight
variants do it 50% better, and duplicates will level the job. Pets still only come from play.

**Second challenge: the fixed 5-minute round.**
- The cost: 30 seconds of prep plus 30 seconds of results is 20% downtime, and it blocks drop-in
  play on phones.
- The fix: keep the climax and drop the dead time. Play is continuous, with a server-wide 60-second
  Midnight surge every 4 minutes and the results as a toast.

**Kept from ChatGPT:**
- the name and the guardian concept;
- bigger eggs being louder;
- losing only the carried egg;
- co-op first, cosmetics-only monetization;
- the safe intro route (practice eggs on the trail);
- the first-build scope;
- the acceptance tests.

**Added by Claude:**
- pet jobs;
- the Giant-egg helper system, with a shared hatch for each helper;
- finders keepers on dropped eggs;
- the Midnight surge in place of rounds;
- the 2026 policy constraints;
- a roadmap toward Mimic eggs.

---

## Round 1: Claude (first playable build)

**Review of the prototype** (it was copied unchanged in Round 0):
- `EggSystem.server.lua` paid out on every prompt trigger. Nothing consumed the egg, there was no
  cooldown and no server-side distance or state check, so two players or one fast clicker got every
  reward. Its RemoteEvent and Part also had to be made by hand. **Replaced** by `EggLedger` plus
  `EggService`.
- `Currency.server.lua`: a Money IntValue with no saving. **Replaced** by `PlayerDataService`
  (Shells, pets, stats; DataStore in Round 2).
- `MapGenerator.server.lua` and `PlotManager.server.lua` built 8 plots around a hub. That fit the old
  plot design, not one forest with a shared Hatchery. PlotManager also re-spawned every character
  after appearance load and set the HRP CFrame before the character settled. **Replaced** by
  `MapService`.
- `MainUI.client.lua` had fixed pixel panels (500x400 does not fit a 667x375 phone) and placeholder
  Shop and Battle Pass tabs. **Replaced** by a scaled HUD with one contextual action button.
- `RarityTable.lua` had 9 tiers down to 0.01% and used global `math.random`. **Rewritten:** 5 tiers
  plus a Midnight variant, rolls with a server `Random`, and per-egg odds.

**What the build does:** see `docs/DESIGN.md` (hook, loop, tuning) and the README test steps.

**How it was checked** (no Studio on the build machine):
- StyLua parse and format check, and a selene lint: no warnings.
- `tests/run.luau`: 26 unit tests. They cover odds (200,000 rolls per egg), pet keys and perks, a
  noise-meter simulation, and the egg ledger: contention, a single reward, locks, helpers, and a
  20,000-step random stress test of its invariants. Mutating the ledger on purpose makes them fail.
- `tests/smoke.luau`: 66 integration checks. It runs the real `Main.server.lua`, `MainUI` and
  `WorldFX` in a simulated DataModel where Lune checks every property against Roblox's API database.
  It walks scripted players through these scenarios:
  - tap GRAB, then carry and bank;
  - repeated input;
  - simultaneous claims;
  - a teleport exploit;
  - Giant-egg helpers;
  - the drop lock;
  - leaving and dying mid-carry;
  - Mama Moss waking, chasing and catching a carrier;
  - Midnight;
  - malformed requests and the rate limit;
  - the pets panel.

  It passed 3 runs in a row.
- **Bugs these checks caught in Claude's own code, all fixed before hand-off:**
  - the guardian could stay one tick short of waking forever (she drained the meter before checking it);
  - a lone Giant carrier could leave earshot without waking her;
  - a cheater's dropped egg could be re-grabbed and banked from inside the Hatchery;
  - a newly hatched Shells pet boosted the very hatch that produced it.

**Not verified:** real Roblox physics and rendering, touch feel, frame rate on a real phone, network
latency. Those need Hayk in Studio.

**Scores** (first playable): see the Round 1 reply.
