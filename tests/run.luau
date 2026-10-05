--!nocheck
-- Unit tests for the pure game modules. Not part of the Roblox place.
-- Run from the repository root:  lune run tests/run.luau
-- Covers: config sanity, RarityTable odds, PetCatalog keys/perks, and EggLedger (one claim per egg,
-- one reward per egg, pickup locks, helpers, and a randomized stress test of the invariants).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

---------------------------------------------------------------------------------------------------
-- A tiny loader that runs Roblox ModuleScripts with the few Roblox globals they use.
---------------------------------------------------------------------------------------------------

local function makeRandom(seed)
	local state = math.max(1, math.floor(seed or 1) % 4294967296)
	local rng = {}
	function rng:NextNumber(min, max)
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		local unit = state / 4294967296
		if min ~= nil and max ~= nil then
			return min + (max - min) * unit
		end
		return unit
	end
	function rng:NextInteger(min, max)
		return min + math.floor(self:NextNumber() * (max - min + 1))
	end
	return rng
end

local RandomStub = {
	new = function(seed)
		return makeRandom(seed)
	end,
}

local cache = {}
local function loadModule(node)
	if cache[node.Path] then
		return cache[node.Path]
	end
	local environment = setmetatable({
		Vector3 = roblox.Vector3,
		Color3 = roblox.Color3,
		Random = RandomStub,
		script = { Name = node.Name, Parent = node.Siblings },
		require = function(target)
			assert(type(target) == "table" and target.Path, "unexpected require target")
			return loadModule(target)
		end,
	}, { __index = getfenv(0) })
	local chunk = luau.load(fs.readFile(node.Path), { debugName = node.Path, environment = environment })
	local result = chunk()
	cache[node.Path] = result
	return result
end

local function folder(directory, names)
	local siblings = {}
	for _, name in names do
		siblings[name] = { Name = name, Path = directory .. name .. ".lua", Siblings = siblings }
	end
	return siblings
end

local Modules = folder("src/ReplicatedStorage/Modules/", { "GameConfig", "PetCatalog", "RarityTable" })
local Services = folder("src/ServerScriptService/Services/", { "EggLedger" })

local GameConfig = loadModule(Modules.GameConfig)
local PetCatalog = loadModule(Modules.PetCatalog)
local RarityTable = loadModule(Modules.RarityTable)
local EggLedger = loadModule(Services.EggLedger)

---------------------------------------------------------------------------------------------------
-- Test runner
---------------------------------------------------------------------------------------------------

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local function eq(actual, expected, message)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(message or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function near(actual, expected, tolerance, message)
	if math.abs(actual - expected) > tolerance then
		error(("%s: expected %.3f +/- %.3f, got %.3f"):format(message or "value", expected, tolerance, actual), 2)
	end
end

---------------------------------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------------------------------

test("every egg's odds name real pets and add up to 100", function()
	for _, kind in GameConfig.EggOrder do
		local total = 0
		for _, entry in GameConfig.Eggs[kind].Odds do
			assert(PetCatalog.Pets[entry.Id], kind .. " lists unknown pet " .. tostring(entry.Id))
			assert(entry.Weight > 0, kind .. " has a non-positive weight")
			total += entry.Weight
		end
		near(total, 100, 1e-9, kind .. " odds total")
	end
end)

test("every pet can hatch from some egg and has a known rarity and perk", function()
	for _, petId in PetCatalog.Order do
		local pet = PetCatalog.Pets[petId]
		assert(pet, "missing pet " .. petId)
		assert(RarityTable.Tiers[pet.Rarity], petId .. " rarity")
		assert(PetCatalog.PerkText[pet.Perk], petId .. " perk")
		assert(#PetCatalog.FoundIn(petId) > 0, petId .. " cannot hatch from any egg")
	end
end)

test("nest slots use real egg kinds; bigger eggs are louder, slower and pay more", function()
	for _, slot in GameConfig.Nest.Slots do
		assert(GameConfig.Eggs[slot.Kind], "unknown slot kind " .. tostring(slot.Kind))
	end
	local pebble, moss, giant = GameConfig.Eggs.Pebble, GameConfig.Eggs.Moss, GameConfig.Eggs.Giant
	assert(pebble.GrabNoise < moss.GrabNoise and moss.GrabNoise < giant.GrabNoise, "noise order")
	assert(pebble.CarrySpeed > moss.CarrySpeed and moss.CarrySpeed > giant.CarrySpeed, "speed order")
	assert(pebble.Shells < moss.Shells and moss.Shells < giant.Shells, "reward order")
end)

test("a Giant egg with every helper is still slower than walking, and helpers are worth it", function()
	local full = GameConfig.Eggs.Giant.CarrySpeed + GameConfig.GiantCarry.PerHelper * GameConfig.GiantCarry.MaxHelpers
	assert(full <= 1, "full helper speed should not exceed walking")
	assert(full > GameConfig.Eggs.Moss.CarrySpeed, "a full team should beat a solo Moss carrier")
end)

test("the fastest honest carrier stays under the bank pace limit", function()
	local best = 0
	for _, kind in GameConfig.EggOrder do
		local factor = GameConfig.Eggs[kind].CarrySpeed
		if kind == "Giant" then
			factor += GameConfig.GiantCarry.PerHelper * GameConfig.GiantCarry.MaxHelpers
		end
		best = math.max(best, math.min(factor, 1))
	end
	local bestCarryPerk = 0
	for _, petId in PetCatalog.Order do
		local kind, amount = PetCatalog.GetPerk(petId, "Midnight")
		if kind == "Carry" then
			bestCarryPerk = math.max(bestCarryPerk, amount)
		end
	end
	local fastest = GameConfig.Player.BaseWalkSpeed * best * (1 + bestCarryPerk)
	assert(fastest < GameConfig.Security.MaxBankPace, ("fastest carrier %.1f studs/s"):format(fastest))
end)

-- Mirrors the server, tick by tick (0.1 s): a grab adds GrabNoise (AddNoise caps it at the
-- threshold); each tick EggService adds carry noise while inside NoiseRadius, then GuardianService
-- wakes her if the meter is full, otherwise drains it. Eggs sit about 10 studs from the nest centre.
-- Returns the highest the meter got (the threshold means she woke up).
local function peakNoise(kinds, speedFactor)
	local guardian = GameConfig.Guardian
	local wake = guardian.WakeThreshold
	local noise, distance = 0, 10
	for _, kind in kinds do
		noise = math.min(wake, noise + GameConfig.Eggs[kind].GrabNoise)
	end
	local peak = noise
	local speed = GameConfig.Player.BaseWalkSpeed * speedFactor
	while distance <= guardian.NoiseRadius do
		for _, kind in kinds do
			noise = math.min(wake, noise + GameConfig.Eggs[kind].CarryNoisePerSecond * 0.1)
		end
		peak = math.max(peak, noise)
		if noise >= wake then
			return wake -- GuardianService wakes her before draining
		end
		noise = math.max(0, noise - guardian.NoiseDecayPerSecond * 0.1)
		distance += speed * 0.1
	end
	return peak
end

test("noise: one Pebble or Moss never wakes her, two Moss eggs do, a Giant always does", function()
	local wake = GameConfig.Guardian.WakeThreshold
	assert(peakNoise({ "Pebble" }, GameConfig.Eggs.Pebble.CarrySpeed) < 0.4 * wake, "a Pebble should barely register")
	assert(peakNoise({ "Moss" }, GameConfig.Eggs.Moss.CarrySpeed) < 0.6 * wake, "one Moss egg should not wake her")
	eq(peakNoise({ "Moss", "Moss" }, GameConfig.Eggs.Moss.CarrySpeed), wake, "two Moss eggs at once")
	eq(peakNoise({ "Giant" }, GameConfig.Eggs.Giant.CarrySpeed), wake, "a lone Giant carrier")
	local team = GameConfig.Eggs.Giant.CarrySpeed + GameConfig.GiantCarry.PerHelper * GameConfig.GiantCarry.MaxHelpers
	eq(peakNoise({ "Giant" }, team), wake, "a full Giant team")
end)

test("stray practice eggs are out of the guardian's hearing", function()
	for _, position in GameConfig.Nest.StraySlots do
		local dx, dz = position.X - GameConfig.Map.NestCenter.X, position.Z - GameConfig.Map.NestCenter.Z
		assert(math.sqrt(dx * dx + dz * dz) > GameConfig.Guardian.NoiseRadius, "stray egg inside noise radius")
	end
end)

test("the guardian is faster than a lone Giant carrier but escapable at a Pebble's pace", function()
	local walk = GameConfig.Player.BaseWalkSpeed
	assert(GameConfig.Guardian.ChaseSpeed > walk * GameConfig.Eggs.Giant.CarrySpeed, "solo giant should be catchable")
	assert(
		GameConfig.Guardian.ChaseSpeed - walk * GameConfig.Eggs.Pebble.CarrySpeed < 4,
		"pebble chases should be close"
	)
end)

---------------------------------------------------------------------------------------------------
-- RarityTable
---------------------------------------------------------------------------------------------------

test("Roll matches the configured odds (200,000 rolls per egg)", function()
	for _, kind in GameConfig.EggOrder do
		local odds = GameConfig.Eggs[kind].Odds
		local rng = makeRandom(1234 + #kind)
		local counts = {}
		local rolls = 200000
		for _ = 1, rolls do
			local id = RarityTable.Roll(odds, rng)
			counts[id] = (counts[id] or 0) + 1
		end
		for _, entry in odds do
			near((counts[entry.Id] or 0) / rolls * 100, entry.Weight, 0.6, kind .. " " .. entry.Id .. " %")
		end
	end
end)

test("Roll never returns a zero-weight entry and handles empty odds", function()
	local rng = makeRandom(7)
	local odds = { { Id = "A", Weight = 0 }, { Id = "B", Weight = 5 }, { Id = "C", Weight = 0 } }
	for _ = 1, 1000 do
		eq(RarityTable.Roll(odds, rng), "B", "only B can roll")
	end
	eq(RarityTable.Roll({}, rng), nil, "empty odds")
	eq(RarityTable.Roll({ { Id = "A", Weight = 0 } }, rng), nil, "all-zero odds")
end)

test("Roll returns the last entry when the random number is at the very top", function()
	local top = {
		NextNumber = function()
			return 0.9999999999
		end,
	}
	eq(RarityTable.Roll({ { Id = "A", Weight = 50 }, { Id = "B", Weight = 50 } }, top), "B", "top roll")
end)

test("Percent reports chances", function()
	local odds = GameConfig.Eggs.Moss.Odds
	near(RarityTable.Percent(odds, "Wispurr"), 2, 1e-9, "Wispurr in Moss")
	eq(RarityTable.Percent(odds, "Nobody"), 0, "unknown id")
end)

---------------------------------------------------------------------------------------------------
-- PetCatalog
---------------------------------------------------------------------------------------------------

test("ParseKey accepts real keys and rejects everything else", function()
	local petId, variant = PetCatalog.ParseKey("ToastMoth:Normal")
	eq(petId, "ToastMoth", "pet")
	eq(variant, "Normal", "variant")
	eq(select(2, PetCatalog.ParseKey("Wispurr:Midnight")), "Midnight", "midnight variant")
	for _, bad in { "ToastMoth:Gold", "Bogus:Normal", "ToastMoth", "ToastMoth:Normal:x", "", 42, nil, {} } do
		eq(PetCatalog.ParseKey(bad), nil, "bad key " .. tostring(bad))
	end
	eq(PetCatalog.ParseKey(string.rep("A", 60) .. ":Normal"), nil, "over-long key")
end)

test("Midnight pets do their job 50% better", function()
	local _, normal = PetCatalog.GetPerk("ToastMoth", "Normal")
	local _, midnight = PetCatalog.GetPerk("ToastMoth", "Midnight")
	near(midnight, normal * 1.5, 1e-9, "midnight perk")
	eq(PetCatalog.DescribePerk("ToastMoth", "Normal"), "10% quieter", "normal text")
	eq(PetCatalog.DescribePerk("ToastMoth", "Midnight"), "15% quieter", "midnight text")
	eq(PetCatalog.DescribePerk("Moonbean", "Normal"), "+35% Shells", "shells text")
end)

test("FoundIn lists the eggs a pet hatches from", function()
	local names = table.concat(PetCatalog.FoundIn("Wispurr"), ", ")
	eq(names, "Moss Egg, Giant Moon Egg", "Wispurr eggs")
end)

---------------------------------------------------------------------------------------------------
-- EggLedger
---------------------------------------------------------------------------------------------------

local A, B, C, D, E = 101, 102, 103, 104, 105

test("two players grabbing the same egg: exactly one wins", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Moss")
	local okA = ledger:TryClaim(egg.Id, A, 0)
	local okB, reason = ledger:TryClaim(egg.Id, B, 0)
	eq(okA, true, "first claim")
	eq(okB, false, "second claim")
	eq(reason, "taken", "reason")
	eq(egg.CarrierId, A, "carrier")
	eq(ledger:CarriedBy(B), nil, "B carries nothing")
end)

test("a carrier cannot hold two eggs; repeated grabs on your own egg do nothing", function()
	local ledger = EggLedger.new()
	local first, second = ledger:Create("Pebble"), ledger:Create("Pebble")
	assert(ledger:TryClaim(first.Id, A, 0))
	local ok, reason = ledger:TryClaim(second.Id, A, 0)
	eq(ok, false, "second egg")
	eq(reason, "busy", "reason")
	for _ = 1, 10 do
		eq(ledger:TryClaim(first.Id, A, 0), false, "re-grab own egg")
	end
	eq(ledger:CarriedBy(A), first, "still carrying the first egg")
end)

test("an egg is consumed once: one reward, then it is gone", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Giant")
	assert(ledger:TryClaim(egg.Id, A, 0))
	local rewards = 0
	for _ = 1, 5 do
		if ledger:TryConsume(egg.Id, A) then
			rewards += 1
		end
	end
	eq(rewards, 1, "rewards")
	eq(ledger:Get(egg.Id), nil, "egg removed")
	eq(ledger:CarriedBy(A), nil, "carrier freed")
	local ok, reason = ledger:TryClaim(egg.Id, B, 1)
	eq(ok, false, "claim after consume")
	eq(reason, "gone", "reason")
	eq(ledger:TryDrop(egg.Id, 1, 0.75), false, "drop after consume")
end)

test("only the carrier can consume", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Moss")
	eq(ledger:TryConsume(egg.Id, A), false, "consume an egg still in the nest")
	assert(ledger:TryClaim(egg.Id, A, 0))
	eq(ledger:TryConsume(egg.Id, B), false, "consume by someone else")
	eq(ledger:TryConsume(egg.Id, A), true, "consume by carrier")
end)

test("a dropped egg is locked briefly, then anyone can grab it", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Moss")
	assert(ledger:TryClaim(egg.Id, A, 0))
	local ok, released, carrier = ledger:TryDrop(egg.Id, 10, 0.75)
	eq(ok, true, "drop")
	eq(#released, 0, "no helpers released")
	eq(carrier, A, "previous carrier")
	eq(ledger:CarriedBy(A), nil, "carrier freed")
	local early, reason = ledger:TryClaim(egg.Id, B, 10.5)
	eq(early, false, "claim during lock")
	eq(reason, "locked", "reason")
	eq(ledger:TryClaim(egg.Id, B, 10.8), true, "claim after lock")
	eq(egg.State, "Carried", "state")
end)

test("unclaimed dropped eggs return to the nest; nest and carried eggs do not", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Pebble")
	eq(ledger:TryReturnToNest(egg.Id), false, "already in the nest")
	assert(ledger:TryClaim(egg.Id, A, 0))
	eq(ledger:TryReturnToNest(egg.Id), false, "carried")
	assert(ledger:TryDrop(egg.Id, 1, 0.75))
	eq(ledger:TryReturnToNest(egg.Id), true, "dropped")
	eq(egg.State, "Nest", "state")
	eq(ledger:TryClaim(egg.Id, B, 1.1), true, "claimable at once (lock cleared)")
end)

test("helpers: join, limits, release on drop, snapshot on consume", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Giant")
	eq(ledger:TryAddHelper(egg.Id, B, 0, 3), false, "cannot help an egg in the nest")
	assert(ledger:TryClaim(egg.Id, A, 0))
	local own, ownReason = ledger:TryAddHelper(egg.Id, A, 0, 3)
	eq(own, false, "carrier helping own egg")
	eq(ownReason, "own_egg", "reason")
	eq(ledger:TryAddHelper(egg.Id, B, 1, 3), true, "B helps")
	eq(ledger:TryAddHelper(egg.Id, B, 1, 3), false, "B helps twice")
	eq(egg.HelperCount, 1, "count after duplicate")
	eq(ledger:TryAddHelper(egg.Id, C, 2, 3), true, "C helps")
	eq(ledger:TryAddHelper(egg.Id, D, 3, 3), true, "D helps")
	local full, fullReason = ledger:TryAddHelper(egg.Id, E, 4, 3)
	eq(full, false, "fourth helper")
	eq(fullReason, "full", "reason")

	local other = ledger:Create("Pebble")
	local busy, busyReason = ledger:TryClaim(other.Id, B, 5)
	eq(busy, false, "a helper cannot grab another egg")
	eq(busyReason, "busy", "reason")

	eq(ledger:RemoveHelper(D), egg, "D lets go")
	eq(egg.HelperCount, 2, "count after leave")
	eq(ledger:RemoveHelper(D), nil, "D lets go twice")

	local ok, helpers = ledger:TryConsume(egg.Id, A)
	eq(ok, true, "consume")
	eq(helpers[B], 1, "B in snapshot with join time")
	eq(helpers[C], 2, "C in snapshot")
	eq(helpers[D], nil, "D left before the bank")
	eq(ledger:HelpingWith(B), nil, "B released")
	eq(ledger:TryClaim(other.Id, B, 6), true, "B is free to grab again")
end)

test("dropping a Giant egg releases every helper", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Giant")
	assert(ledger:TryClaim(egg.Id, A, 0))
	assert(ledger:TryAddHelper(egg.Id, B, 0, 3))
	assert(ledger:TryAddHelper(egg.Id, C, 0, 3))
	local ok, released = ledger:TryDrop(egg.Id, 1, 0.75)
	eq(ok, true, "drop")
	table.sort(released)
	eq(table.concat(released, ","), B .. "," .. C, "released helpers")
	eq(egg.HelperCount, 0, "count")
	eq(ledger:HelpingWith(B), nil, "B free")
	eq(ledger:HelpingWith(C), nil, "C free")
end)

test("Remove refuses a carried egg and Create cannot override core fields", function()
	local ledger = EggLedger.new()
	local egg = ledger:Create("Moss", { State = "Carried", CarrierId = A, PetId = "Pumpkit" })
	eq(egg.State, "Nest", "core field kept")
	eq(egg.CarrierId, nil, "core field kept")
	eq(egg.PetId, "Pumpkit", "extra field stored")
	assert(ledger:TryClaim(egg.Id, A, 0))
	eq(ledger:Remove(egg.Id), false, "remove while carried")
	assert(ledger:TryDrop(egg.Id, 1, 0))
	eq(ledger:Remove(egg.Id), true, "remove when dropped")
	eq(ledger:Count(), 0, "empty")
end)

test("unknown and malformed ids are rejected", function()
	local ledger = EggLedger.new()
	for _, id in { 999, -1, 0, "1", nil, 1 / 0 } do
		eq(ledger:TryClaim(id, A, 0), false, "claim " .. tostring(id))
		eq(ledger:TryConsume(id, A), false, "consume " .. tostring(id))
	end
end)

test("stress: random grabs, helps, drops and banks never break the invariants", function()
	local rng = makeRandom(20261005)
	local ledger = EggLedger.new()
	local users = { A, B, C, D, E }
	local eggs = {}
	for i = 1, 4 do
		eggs[i] = ledger:Create(if i == 1 then "Giant" else "Moss")
	end
	local consumedIds, rewards = {}, 0
	local now = 0
	for step = 1, 20000 do
		now += 0.05
		local user = users[rng:NextInteger(1, #users)]
		local egg = eggs[rng:NextInteger(1, #eggs)]
		local action = rng:NextInteger(1, 6)
		if action <= 2 then
			ledger:TryClaim(egg.Id, user, now)
		elseif action == 3 then
			ledger:TryAddHelper(egg.Id, user, now, 3)
		elseif action == 4 then
			local carried = ledger:CarriedBy(user)
			if carried then
				ledger:TryDrop(carried.Id, now, 0.75)
			else
				ledger:RemoveHelper(user)
			end
		elseif action == 5 then
			if ledger:TryConsume(egg.Id, user) then
				assert(not consumedIds[egg.Id], "egg consumed twice")
				consumedIds[egg.Id] = true
				rewards += 1
				eggs[table.find(eggs, egg)] = ledger:Create("Moss") -- the slot respawns
			end
		else
			ledger:TryReturnToNest(egg.Id)
		end

		-- invariants
		local carriers, helping = {}, {}
		for _, live in ledger:All() do
			assert(not live.Consumed, "a consumed egg is still live")
			if live.State == "Carried" then
				assert(live.CarrierId, "carried without a carrier")
				assert(not carriers[live.CarrierId], "someone carries two eggs")
				carriers[live.CarrierId] = true
				eq(ledger:CarriedBy(live.CarrierId), live, "carrier index")
			else
				eq(live.CarrierId, nil, "carrier on a free egg (step " .. step .. ")")
				eq(live.HelperCount, 0, "helpers on a free egg")
			end
			local count = 0
			for helperId in live.Helpers do
				count += 1
				assert(helperId ~= live.CarrierId, "carrier helping own egg")
				assert(not helping[helperId], "someone helps two eggs")
				helping[helperId] = true
				eq(ledger:HelpingWith(helperId), live, "helper index")
			end
			eq(count, live.HelperCount, "helper count")
			assert(count <= 3, "too many helpers")
		end
		for helperId in helping do
			assert(not carriers[helperId], "someone carries and helps at once")
		end
		-- and the reverse: every index entry points at an egg that agrees
		for _, someone in users do
			local carried = ledger:CarriedBy(someone)
			if carried then
				eq(carried.State, "Carried", "carry index points at a free egg")
				eq(carried.CarrierId, someone, "carry index points at someone else's egg")
			end
			local helped = ledger:HelpingWith(someone)
			if helped then
				assert(helped.Helpers[someone] ~= nil, "help index points at an egg without that helper")
			end
		end
	end
	assert(rewards > 0, "the stress test should bank some eggs")
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
