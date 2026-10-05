# Midnight Hatch — Round 0 project package

This folder contains the existing Roblox/Rojo prototype and ChatGPT's Round 0 game proposal. The Midnight Hatch gameplay has not been implemented yet. Claude's pitch and the combined design decision are still pending.

## Open the project

The Rojo configuration is `default.project.json`. Keep the `src` subfolders intact because Rojo maps them to Roblox services.

To serve this copy with your installed Rojo:

```sh
cd /Users/goat/claude/MidnightHatch
rojo serve default.project.json
```

Connect Roblox Studio's Rojo plugin to the server shown in the terminal. Serve either this copy or the original project; pick the intended server when connecting Studio.

The existing Lua scripts are exact copies of the original prototype. They have not been changed or playtested during packaging. The original project remains at `/Users/goat/RobloxGame`.

The prototype's EggSystem script currently expects manually created Studio instances: `ReplicatedStorage/RemoteEvents/HatchEgg` (RemoteEvent), and `Workspace/Egg` (Part) with a `ProximityPrompt`. Packaging has not created those instances or a Studio place file.

## Proposed game

**Working name:** Midnight Hatch

**Hook:** Grab an egg from a sleeping monster, escape with friends, and hatch a strange pet for your permanent collection. Bigger eggs promise more unusual pets but make more noise and attract the guardian.

**Core loop:** Find a nest, choose a safe or risky egg, carry it through the forest, dodge the guardian or help a friend, reach the hatchery, then hatch and collect.

**Session length:** Five-minute cycles: 30 seconds preparation, three minutes exploration, one minute midnight escape, and 30 seconds results. Players can bank and hatch eggs during exploration. New arrivals get a safe introductory route.

**Failure:** Lose only the egg currently being carried. Previously collected pets and earned progression stay safe. Return to play quickly.

**Progression:** Earn Shells through successful runs. Unlock biomes, modest equipment upgrades, collection milestones, and hatchery decorations. Start with six original creatures, including Toast Moth, Socktopus, and Moonbean.

**Social play:** Friends distract the guardian and recover dropped eggs. Solo play remains viable. The proposed initial mode uses monster nests and cooperative play; an optional later competitive mode could put only unbanked eggs at risk.

**Monetization:** Direct purchases of lantern skins, pet outfits, hatch animations, emotes, and decorations. Purchases are cosmetic. Speed, survival tools, and pet availability come through play.

**Creator appeal:** Giant-egg challenges, last-second group escapes, discoveries, and funny guardian chases produce clear video premises through actual gameplay.

## Research checked October 5, 2026

Roblox's live chart was checked with United States and Entry-level Phone selected. 99 Nights in the Forest and Dandy's World occupied the first two Top Trending positions. The separate Top Playing Now section covered all devices and locations: Steal An Egg led at approximately 1.4 million players, while Adopt Me! showed approximately 256,000. These are snapshots, not monthly averages.

- Live phone charts: https://www.roblox.com/charts?device=low_end_phone&country=us
- Trending methodology: https://www.roblox.com/charts/top-trending

Roblox describes Trending as increased time spent over the preceding two weeks.

Numerous's giant enchanted-egg YouTube video was verified as published October 3, 2026, with approximately 208,000 views when checked. Its description emphasizes a new biome and rare pets. The design inference is that oversized collectibles, discoveries, and unusual challenges offer clear creator premises.

- Creator video: https://www.youtube.com/watch?v=T7d3h8gYaJ8

TikTok blocked direct browsing. This research does not verify October TikTok rankings or trending hashtags.

## Higgsfield concept art direction

Higgsfield was requested for art production. The image generation attempt returned “Requires basic plan or higher.” No image job was created and this package contains no generated image.

Prepared prompt:

> Create one high-quality visual concept illustration for an original Roblox game pitch called Midnight Hatch. This is concept art, not a screenshot of an existing game, and not a finished launch thumbnail. Bright, readable, charming low-poly toy-like 3D Roblox-inspired aesthetic for ages 10 to 17, mobile-friendly visual clarity, expressive original block-shaped adventurer avatars. Foreground: two cooperating block-shaped adventurers running toward a warm safe hatchery with a giant glowing purple speckled egg between them, one holding a lantern. Background: a comically enormous sleepy original moss-covered owl-cat monster has woken beside its nest and chases them through a compact whimsical moonlit forest. Left side reads as cool blue danger, right side is warm amber safety. Show a small original pet, a toast-shaped moth with tiny jam wings, inside the safe hatchery. Make the contrast, egg, monster silhouette, and escape route instantly readable at phone size. Light spooky excitement, humor, no gore, no horror violence, no copyrighted characters, no real-world brands, no user interface or text. Strong dynamic composition, limited clean geometry, no detailed foliage clutter.

## First playable build

Keep the initial scope to one compact forest, one guardian, six players, three egg types, one hatchery, and one large contextual mobile action button.

The server must decide egg claims, carrying state, extraction, hatch results, and rewards. The current prototype immediately rewards prompt activations without consuming an egg or enforcing a cooldown. Replace that interaction with the validated carry-and-extract loop before treating it as the proposed game.

Studio acceptance test for the implementation round:

1. Start a server with two clients.
2. Both players attempt to claim the same egg; exactly one receives it.
3. The guardian responds to the carrying player.
4. Extraction grants a reward exactly once.
5. Dropping, dying, repeated input, and simultaneous claims do not duplicate eggs or rewards.
6. Check touch layout with Studio's device emulator, then measure performance on a real low-end phone.

These are future acceptance tests, not tests completed during Round 0. Game scores begin with the first playable build.

## Message for Claude

ChatGPT proposes Midnight Hatch: five-minute cooperative egg heists with a monster guardian and permanent pet collecting. Live October 5 entry-level-phone charts support spooky survival; global charts and October creator coverage support eggs and rare-pet reveals. Please share your pitch, challenge the weakest mechanic, and propose one combined direction covering hook, loop, progression, cosmetics, and creator appeal. Keep our first build to one map and one guardian. The existing hatch interaction needs consumption, contention handling, server validation, and reward deduplication.

## Shared file list

See `FILE_LIST.md` for every file in this package and its recorded editor.
