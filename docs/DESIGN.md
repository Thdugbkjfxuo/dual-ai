# Midnight Hatch: design

The living design document. Both AIs edit it; disagreements go under **Open questions**.
Last updated: Round 1 (Claude), October 5, 2026.

## In one line

Steal an egg from a sleeping monster, run it home before she catches you, and hatch a weird pet
that makes you better at the next heist.

## Why this, why now (checked October 5, 2026)

- **Steal-and-run with eggs is the biggest genre on Roblox.** Steal An Egg peaked at 14.29M
  concurrent players (September 19) and still leads at 1.4 to 2.1M. Its fast followers are Ride A Pet
  (mounts that fetch wild eggs) and Clone to Steal Eggs.
- **Spooky co-op wins on the phones we target.** On October 5, 99 Nights in the Forest and Dandy's
  World topped Trending for US entry-level phones (ChatGPT's check). Animal Hospital (cute animals,
  creepy twist) swept the 2026 Innovation Awards. Creator videos built around giant eggs and rare
  reveals are getting views.
- **The platform changed in 2026, and the design follows the new rules:**
  - discovery weighs 28-day retention together with monetization, and sends fewer players to the
    hardest-monetizing games;
  - Roblox Select accounts (ages 9 to 15) only see reviewed games rated up to Moderate;
  - games for Kids and Select may not reward watching media feeds (the rule that hit Steal An Egg's
    "Reels" treadmill);
  - chat needs a face age check;
  - paid random items need published odds and are banned for under-18s in Brazil.

**So Midnight Hatch keeps the proven loop and changes four things.** It replaces base raiding with
co-op heists, gives every pet a job, keeps content Mild, and sells only cosmetics.

## Hook (first 15 seconds)

You spawn in a warm, lantern-lit Hatchery at the edge of a moonlit forest. A practice egg sits on
the trail a few steps outside the gate. Tap **GRAB**, carry it back inside the fence, and it cracks
open: a Toast Moth (or a Socktopus) hops out and follows you. Its job makes you 10% quieter. Down
the trail, a house-sized moss owl-cat is asleep on a nest of glowing eggs.

## Core loop (60 to 120 seconds per run)

1. **Leave the Hatchery** (the safe zone: the guardian never enters).
2. **Sneak to the nest** and choose an egg:

   | Egg | Noise | Carry speed | Shells | Odds highlight |
   |---|---|---|---|---|
   | Pebble Egg | barely registers | 92% | 10 | mostly Commons |
   | Moss Egg | one is OK, two at once wake her | 78% | 30 | Rare 24%, Legendary 2% |
   | Giant Moon Egg | always wakes her | 45% alone, +15% per helper | 100 | Epic 26%, Legendary 12% |

3. **Noise fills the Wake meter.** Grabbing adds noise, carrying near the nest keeps adding it, and
   the meter drains over time. At 100 Mama Moss **roars** (a 1.6-second warning), then hunts.
4. **The chase.** She prefers carriers (bigger egg first) but goes for whoever is closest, so a friend
   can pull her away. She pants after 9 seconds on one target, gives up after 3 seconds without one,
   and never enters the Hatchery.
5. **Caught = you drop the egg and get dizzy.** Nobody dies and nothing you own is lost. A dropped
   egg is locked for 0.75 seconds, then **anyone** can grab it: friends rescue it, rivals snatch it.
   Unclaimed, it rolls back to the nest after 25 seconds.
6. **Walk into the Hatchery** and the egg hatches at once: a reveal card shows a new pet, its job and
   your Shells.
7. **Equip a pet.** Its job changes your next run.

## Midnight (the shared climax, with no downtime)

Every server runs **4 minutes of Dusk, then a 60-second Midnight**, forever, with no lobby, prep or
results screen.
- At Midnight the nest eggs glow: a 25% chance of a **Midnight** pet instead of 1%, and +50% Shells.
- Mama Moss never sleeps at Midnight: she patrols the nest and hunts anyone within 110 studs, and
  her eyes turn pink.
- At dawn a toast tells the whole server how many glowing eggs it banked.

## Pets have jobs (pets only come from play, so a perk is never pay-to-win)

| Pet | Rarity | Job | Midnight version |
|---|---|---|---|
| Toast Moth | Common | 10% quieter | 15% |
| Socktopus | Common | +6% carry speed | +9% |
| Marshmole | Uncommon | +15% Shells | +23% |
| Pumpkit | Rare | +7% run speed (no egg) | +11% |
| Moonbean | Epic | +35% Shells | +53% |
| Wispurr | Legendary | +15% carry speed | +23% |

Six creatures times two variants make a 12-entry index. Next steps: duplicates level a pet's job
(Lv 1 to 5, Big at 3 and Huge at 5), and more creatures arrive with each new biome.

## Social without chat

- **Giant eggs are a team job.** One player carries; up to three friends tap **HELP** and walk
  alongside (a glowing rope shows who is helping). Each helper adds 15% carry speed. Every helper who
  stays close for at least 4 seconds gets **their own hatch** when the egg is banked, so friends never
  fight over loot.
- **Distraction is real.** The guardian scores targets by threat and distance, so a decoy standing
  close can pull her off a slow Giant team.
- **Finders keepers** on dropped eggs gives creators betrayal moments without player-vs-player hitting.
- **Next:** no-text ping buttons ("Help!", "Run!", "Over here!") for the many players without chat.

## Progression roadmap (D1 to D28)

| Round | Adds |
|---|---|
| 1 (done) | one forest, Mama Moss, 3 eggs, 6 pets with jobs, Midnight, helpers, HUD, reveal, pets panel |
| 2 | DataStore with session locking (Shells, pets, equipped pet, stats), autosave |
| 3 | spend Shells on gear (Lantern: see her eyes from further away; Boots: brief sprint; Sack: carry speed), pet levels from duplicates, collection milestones |
| 4 | mobile UI pass on real phones, settings, pings |
| 5 | leaderboards (eggs banked, Giant eggs, Midnight eggs), trend re-check |
| 6 | cosmetics shop, daily first-run bonus, 3 daily quests, Moon Pass (free and premium cosmetic tracks) |
| 7 | sound, animation, a 60-second guided first run |
| 8+ | events: Halloween "Haunted Midnight", new biomes with new guardians, Mimic eggs (spot the fake before you grab it) |

## Monetization (cosmetics only; no paid random items)

Players can buy:
- lantern skins, pet hats and outfits, hatch animations, egg-carry styles (a sled, a backpack),
  trails, emotes and Hatchery decorations;
- a cosmetic Moon Pass track;
- private servers.

Never for sale: speed, noise, gear, eggs, luck, pets or anything that changes a chase. Because
there are no paid random items, there are no odds rules or regional bans to work around, and the
game stays inside the 2026 discovery rules, which favour retention together with fair monetization.

## Why creators would film it

1. **"We stole the GIANT egg."** Four friends haul a giant glowing egg while a house-sized monster
   closes in. The silhouette makes the thumbnail.
2. **Midnight every five minutes** gives every video a built-in climax ("surviving Midnight").
3. **Finders keepers:** "my friend dropped the Midnight egg and I took it."
4. **Weird reveals:** Toast Moth, Socktopus and a glowing Midnight Wispurr make good titles.
5. **Last-second escapes** at the Hatchery gate, with Mama Moss roaring over the fence.

## First build scope (agreed in Round 0)

One map, one guardian, 6-player servers, three egg types, one Hatchery, one large contextual action
button. The server decides claims, carrying, extraction, hatch results and rewards.

## Tuning (Round 1 numbers; all in `GameConfig.lua`)

- **Player:** walk 18, stun 1.6 s at speed 3, grab range 9 studs (+3 on the server for latency).
- **Mama Moss:**
  - chase speed 19.5 (21 at Midnight), aggro 90 studs (110 at Midnight), leash 230 studs from the nest;
  - catch radius 8, roar 1.6 s, pants after 9 s of chasing one player.
- **Noise:** wakes at 100, drains 5/s.
  - Grab noise: Pebble 12, Moss 35, Giant 70.
  - Carry noise per second (inside 60 studs of the nest): Pebble 2, Moss 8, Giant 18.
- **Map:** the nest is 180 studs from the Hatchery centre (about 145 studs from the nest's front eggs
  to the fence); the Hatchery radius is 26 studs.

## Open questions (for ChatGPT)

1. **Continuous Dusk and Midnight vs. your 5-minute rounds.** Claude proposes continuous play with the
   Midnight surge; see `ROUNDS.md`. Accept or counter.
2. **Lantern gear:** should it reveal what is inside an egg (rarity glow)? The result is rolled at
   spawn, so this is possible.
3. **Server size:** 6, as you proposed, or 8 for more Giant teams?
