-- EggService
-- Server-authoritative eggs. Replaces the prototype's EggSystem, which paid out on every prompt trigger
-- without using up the egg: no cooldown, no distance check, and two players (or one fast clicker)
-- could collect the same reward.
--
-- Now the client only asks: Action("Grab", eggId) or Action("Drop"). The server checks each request
-- (alive, not stunned, close enough, egg available; Main rate-limits), claims the egg in EggLedger,
-- welds it above the carrier's head and slows them down. Banking has no request at all: the server
-- sees the carrier walk into the Hatchery. EggLedger:TryConsume succeeds once per egg, so every egg
-- hatches once, and what hatches was rolled on the server when the egg spawned.
-- Dropping, dying, resetting, leaving, getting caught or moving impossibly fast drops the egg where
-- you stand; anyone can pick it up after a short lock. Giant eggs can be carried with helpers, and
-- each helper who stays close gets their own hatch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local PetCatalog = require(Modules.PetCatalog)
local RarityTable = require(Modules.RarityTable)
local PetModels = require(Modules.PetModels)
local Net = require(Modules.Net)
local EggLedger = require(script.Parent.EggLedger)

local PLAYER = GameConfig.Player
local NEST = GameConfig.Nest
local GIANT = GameConfig.GiantCarry
local SECURITY = GameConfig.Security
local VARIANTS = GameConfig.Variants
local GROUPS = GameConfig.CollisionGroups

local CARRY_HEIGHT = 2.7 -- from the root part's centre to just above the head

local EggService = {}

local ledger = EggLedger.new()
local rng = Random.new()
local deps -- { Map, Guardian, Data, Pets, Cycle }
local notifyRemote, hatchedRemote, caughtRemote

local slots = {} -- { Index, Kind, Position, Stray, EggId, RespawnAt }
local models = {} -- [eggId] = Model in Workspace.MidnightMap.Eggs
local welds = {} -- [eggId] = WeldConstraint to the carrier
local trackers = {} -- [Player] = movement checks while carrying
local stunnedUntil = {} -- [Player] = os.clock()
local helperAwaySince = {} -- [userId] = os.clock()
local midnightBanked = 0

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function newTracker(position, walkSpeed, now)
	return {
		LastPos = position,
		LastTime = now,
		WindowPos = position,
		WindowStart = now,
		WindowSpeed = walkSpeed,
		Strikes = 0,
		FirstStrikeAt = 0,
	}
end

local function notify(player, text, style)
	notifyRemote:FireClient(player, text, style or "info")
end

local function notifyAll(text, style)
	notifyRemote:FireAllClients(text, style or "info")
end

-- Mirrors an egg's public state to its model's attributes (the client UI reads them).
local function syncModel(egg)
	local model = models[egg.Id]
	if not model then
		return
	end
	local helperIds = {}
	for helperId in egg.Helpers do
		table.insert(helperIds, tostring(helperId))
	end
	model:SetAttribute("State", egg.State)
	model:SetAttribute("CarrierId", egg.CarrierId or 0)
	model:SetAttribute("HelperCount", egg.HelperCount)
	model:SetAttribute("Helpers", table.concat(helperIds, ","))
	model:SetAttribute("Midnight", egg.Midnight == true)
	model:SetAttribute("LockedUntil", egg.LockedUntilServer or 0)
end

local function syncPlayer(player)
	local carried = ledger:CarriedBy(player.UserId)
	local helping = ledger:HelpingWith(player.UserId)
	player:SetAttribute("MH_Carrying", if carried then carried.Id else 0)
	player:SetAttribute("MH_CarryKind", if carried then carried.Kind else "")
	player:SetAttribute("MH_Helping", if helping then helping.Id else 0)
end

-- Walk speed comes only from the server: stun, egg weight, helpers and pet perks.
function EggService.RefreshSpeed(player)
	local _, humanoid = getCharacterParts(player)
	if not humanoid or not deps then
		return
	end
	local speed = PLAYER.BaseWalkSpeed
	local stunned = stunnedUntil[player]
	if stunned and os.clock() < stunned then
		speed = PLAYER.StunWalkSpeed
	else
		local egg = ledger:CarriedBy(player.UserId)
		if egg then
			local factor = GameConfig.Eggs[egg.Kind].CarrySpeed
			if egg.Kind == "Giant" then
				factor += GIANT.PerHelper * egg.HelperCount
			end
			speed *= math.min(factor, 1) * (1 + deps.Pets.GetPerk(player, "Carry"))
		else
			speed *= 1 + deps.Pets.GetPerk(player, "Swift")
		end
	end
	humanoid.WalkSpeed = speed
end

---------------------------------------------------------------------------------------------------
-- World models
---------------------------------------------------------------------------------------------------

local function restCFrame(kind, groundPoint)
	local height = GameConfig.Eggs[kind].Height
	return CFrame.new(groundPoint + Vector3.new(0, height / 2 - 0.1, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

local function setCarried(model, carried)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = not carried
			part.Massless = carried
		end
	end
end

local function groundBelow(position)
	local ignore = { deps.Map.EggFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), groundParams)
	if result then
		return result.Position
	end
	return Vector3.new(position.X, deps.Map.GroundY, position.Z)
end

local function attachToCharacter(egg, root)
	local model = models[egg.Id]
	if not model or not model.PrimaryPart then
		return false
	end
	if welds[egg.Id] then
		welds[egg.Id]:Destroy()
		welds[egg.Id] = nil
	end
	setCarried(model, true)
	local height = GameConfig.Eggs[egg.Kind].Height
	model:PivotTo(root.CFrame * CFrame.new(0, CARRY_HEIGHT + height / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	welds[egg.Id] = weld
	return true
end

local function detachToGround(egg, position)
	local model = models[egg.Id]
	if not model then
		return
	end
	if welds[egg.Id] then
		welds[egg.Id]:Destroy()
		welds[egg.Id] = nil
	end
	setCarried(model, false)
	model:PivotTo(restCFrame(egg.Kind, groundBelow(position)))
end

-- Puts a dropped egg back on its nest (or trail) slot, free to grab at once.
local function returnToSlot(egg)
	if not ledger:TryReturnToNest(egg.Id) then
		return false
	end
	egg.LockedUntilServer = 0
	local slot = slots[egg.SlotIndex]
	local model = models[egg.Id]
	if slot and model then
		model:PivotTo(restCFrame(egg.Kind, slot.Position))
	end
	syncModel(egg)
	return true
end

-- What hatches is decided here, on the server, and never sent to clients before the hatch.
local function rollContents(kind, isMidnight)
	local petId = RarityTable.Roll(GameConfig.Eggs[kind].Odds, rng)
	local chance = if isMidnight then VARIANTS.MidnightChanceMidnightEgg else VARIANTS.MidnightChanceDusk
	local variant = if rng:NextNumber() < chance then "Midnight" else "Normal"
	return petId, variant
end

local function spawnInSlot(slot)
	local isMidnight = not slot.Stray and deps.Cycle.GetPhase() == "Midnight"
	local petId, variant = rollContents(slot.Kind, isMidnight)
	local egg = ledger:Create(slot.Kind, {
		SlotIndex = slot.Index,
		Stray = slot.Stray,
		Midnight = isMidnight,
		PetId = petId,
		Variant = variant,
	})

	local model = PetModels.BuildEgg(slot.Kind, isMidnight, egg.Id, true)
	model.Name = slot.Kind .. "Egg_" .. egg.Id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("EggId", egg.Id)
	model:SetAttribute("Kind", slot.Kind)
	model:SetAttribute("Stray", slot.Stray)
	model:PivotTo(restCFrame(slot.Kind, slot.Position))
	model.Parent = deps.Map.EggFolder
	models[egg.Id] = model

	slot.EggId = egg.Id
	slot.RespawnAt = nil
	syncModel(egg)
end

---------------------------------------------------------------------------------------------------
-- Helpers (Giant eggs)
---------------------------------------------------------------------------------------------------

local function stopHelping(player, message)
	local egg = ledger:RemoveHelper(player.UserId)
	helperAwaySince[player.UserId] = nil
	syncPlayer(player)
	if not egg then
		return
	end
	syncModel(egg)
	local carrier = if egg.CarrierId then Players:GetPlayerByUserId(egg.CarrierId) else nil
	if carrier then
		EggService.RefreshSpeed(carrier)
	end
	if message then
		notify(player, message, "info")
	end
end

local function tryJoinHelper(player, egg, root, now)
	if egg.CarrierId == player.UserId then
		return
	end
	local carrier = Players:GetPlayerByUserId(egg.CarrierId)
	local carrierRoot = if carrier then getCharacterParts(carrier) else nil
	if not carrier or not carrierRoot then
		return
	end
	if flatDistance(carrierRoot.Position, root.Position) > PLAYER.HelpRange + PLAYER.GrabRangeSlack then
		return
	end
	local ok, reason = ledger:TryAddHelper(egg.Id, player.UserId, now, GIANT.MaxHelpers)
	if not ok then
		if reason == "full" then
			notify(player, "This egg already has enough helpers!", "warn")
		end
		return
	end
	helperAwaySince[player.UserId] = nil
	syncModel(egg)
	syncPlayer(player)
	EggService.RefreshSpeed(carrier)
	notify(carrier, ("👥 %s is helping you carry!"):format(player.DisplayName), "good")
	notify(player, ("👥 You're helping %s! Stay close to share the hatch."):format(carrier.DisplayName), "good")
end

local function updateHelpers(carrier, egg, carrierRoot, now)
	local leaving = {}
	for helperId in egg.Helpers do
		local helper = Players:GetPlayerByUserId(helperId)
		local helperRoot = if helper then getCharacterParts(helper) else nil
		if helperRoot and flatDistance(helperRoot.Position, carrierRoot.Position) <= PLAYER.HelpRange * 1.4 then
			helperAwaySince[helperId] = nil
		else
			local since = helperAwaySince[helperId]
			if not since then
				helperAwaySince[helperId] = now
			elseif now - since >= GIANT.LeaveAfterSeconds then
				table.insert(leaving, helperId)
			end
		end
	end
	if #leaving == 0 then
		return
	end
	for _, helperId in leaving do
		local helper = Players:GetPlayerByUserId(helperId)
		if helper then
			stopHelping(helper, "You stopped helping (too far away).")
		else
			ledger:RemoveHelper(helperId)
			helperAwaySince[helperId] = nil
		end
	end
	syncModel(egg)
	EggService.RefreshSpeed(carrier)
end

---------------------------------------------------------------------------------------------------
-- Dropping, banking, hatching
---------------------------------------------------------------------------------------------------

-- Drops whatever the player carries (and stops them helping). Returns true if an egg was dropped.
function EggService.ForceDrop(player, reason)
	if ledger:HelpingWith(player.UserId) then
		stopHelping(player, nil)
	end
	local egg = ledger:CarriedBy(player.UserId)
	if not egg then
		return false
	end

	local model = models[egg.Id]
	local root = getCharacterParts(player)
	local position = if root
		then root.Position
		elseif model and model.PrimaryPart then model.PrimaryPart.Position
		else deps.Map.NestCenter

	local ok, released = ledger:TryDrop(egg.Id, os.clock(), NEST.PickupLockSeconds)
	if not ok then
		return false
	end
	egg.LockedUntilServer = workspace:GetServerTimeNow() + NEST.PickupLockSeconds
	trackers[player] = nil
	detachToGround(egg, position)
	syncModel(egg)
	-- An egg never rests inside the Hatchery (it could be re-grabbed and banked from there), and an
	-- egg taken from a cheater goes home instead of staying where they put it.
	if reason == "TooFast" or deps.Map.IsInSafeZone(position, 6) then
		returnToSlot(egg)
	end
	syncPlayer(player)
	for _, helperId in released do
		helperAwaySince[helperId] = nil
		local helper = Players:GetPlayerByUserId(helperId)
		if helper then
			syncPlayer(helper)
			notify(helper, "The egg was dropped! Grab it!", "warn")
		end
	end
	EggService.RefreshSpeed(player)

	if reason == "Caught" then
		notify(player, "💫 Mama Moss got you! You dropped the egg.", "danger")
	elseif reason == "TooFast" then
		notify(player, "Your egg slipped! (you moved too fast)", "warn")
	end
	if egg.Kind == "Giant" and reason ~= "Dropped" then
		notifyAll("🥚 The GIANT egg is on the ground. Grab it!", "giant")
	end
	return true
end

local function computeShells(player, egg)
	local amount = GameConfig.Eggs[egg.Kind].Shells
	if egg.Midnight then
		amount *= VARIANTS.MidnightShellsMultiplier
	end
	if egg.Stray then
		amount *= NEST.StrayShellsMultiplier
	end
	amount *= 1 + deps.Pets.GetPerk(player, "Shells")
	return math.max(1, math.floor(amount + 0.5))
end

local function grantHatch(player, egg, petId, variant, helped)
	local pet = PetCatalog.Pets[petId]
	if not pet then
		warn("[EggService] unknown pet " .. tostring(petId))
		return
	end
	local shells = computeShells(player, egg) -- before AddPet: a freshly hatched pet can't boost its own hatch
	local isNew, autoEquipped = deps.Data.AddPet(player, petId, variant)
	deps.Data.AddShells(player, shells)
	deps.Data.AddStat(player, "Banked", 1)
	deps.Data.AddStat(player, "Hatched", 1)
	if autoEquipped then
		deps.Pets.Apply(player)
	end
	deps.Data.Sync(player)

	hatchedRemote:FireClient(player, {
		PetId = petId,
		Variant = variant,
		Shells = shells,
		IsNew = isNew,
		EggKind = egg.Kind,
		Helped = helped,
		AutoEquipped = autoEquipped,
	})
	if RarityTable.Get(pet.Rarity).Rank >= 4 or variant == "Midnight" then
		local label = if variant == "Midnight" then "Midnight " .. pet.Name else pet.Name
		notifyAll(("✨ %s hatched a %s %s!"):format(player.DisplayName, pet.Rarity, label), "rare")
	end
end

local function bank(player, egg, root, now)
	-- The straight-line pace from the (server-observed) pickup point to here must be humanly possible.
	local elapsed = math.max(now - egg.ClaimedAt, 0.05)
	if egg.PickupPos then
		local pace = flatDistance(egg.PickupPos, root.Position) / elapsed
		if pace > SECURITY.MaxBankPace then
			warn(
				("[EggService] %s reached the hatchery too fast (%.0f studs/s); egg dropped"):format(player.Name, pace)
			)
			EggService.ForceDrop(player, "TooFast")
			return
		end
	end

	local ok, helpers = ledger:TryConsume(egg.Id, player.UserId)
	if not ok then
		return
	end

	-- Consumed: remove the model and free the slot for a new egg.
	local model = models[egg.Id]
	models[egg.Id] = nil
	if welds[egg.Id] then
		welds[egg.Id]:Destroy()
		welds[egg.Id] = nil
	end
	if model then
		model:Destroy()
	end
	trackers[player] = nil
	local slot = slots[egg.SlotIndex]
	if slot and slot.EggId == egg.Id then
		slot.EggId = nil
		slot.RespawnAt = now
			+ (if slot.Stray then NEST.StrayRespawnSeconds else GameConfig.Eggs[slot.Kind].RespawnSeconds)
	end
	syncPlayer(player)
	EggService.RefreshSpeed(player)
	if egg.Midnight then
		midnightBanked += 1
	end

	grantHatch(player, egg, egg.PetId, egg.Variant, false)

	-- Giant-egg helpers who stayed close get their own hatch from the same egg.
	for helperId, joinedAt in helpers do
		helperAwaySince[helperId] = nil
		local helper = Players:GetPlayerByUserId(helperId)
		if helper then
			syncPlayer(helper)
			local helperRoot = getCharacterParts(helper)
			local closeEnough = helperRoot ~= nil
				and (
					deps.Map.IsInSafeZone(helperRoot.Position)
					or flatDistance(helperRoot.Position, root.Position) <= PLAYER.HelpRange * 1.6
				)
			if closeEnough and now - joinedAt >= GIANT.HelperMinSeconds then
				local petId, variant = rollContents(egg.Kind, egg.Midnight)
				grantHatch(helper, egg, petId, variant, true)
			else
				notify(helper, "You joined too late to share this hatch.", "warn")
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------------------------------------

-- 10 times a second: movement checks, carry noise, helpers, and banking.
local function carrierTick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local egg = ledger:CarriedBy(player.UserId)
		if not egg then
			continue
		end
		local root, humanoid = getCharacterParts(player)
		if not root then
			EggService.ForceDrop(player, "Lost")
			continue
		end

		local tracker = trackers[player]
		if not tracker then
			tracker = newTracker(root.Position, humanoid.WalkSpeed, now)
			trackers[player] = tracker
		end

		-- A single huge jump (teleport) drops the egg at once.
		local elapsed = now - tracker.LastTime
		local allowedStep = humanoid.WalkSpeed * elapsed * SECURITY.SpeedTolerance + SECURITY.SpeedSlackStuds
		local stepped = flatDistance(root.Position, tracker.LastPos)
		tracker.LastPos = root.Position
		tracker.LastTime = now
		if stepped > allowedStep * SECURITY.TeleportFactor then
			EggService.ForceDrop(player, "TooFast")
			continue
		end
		-- Over each ~1 s window the carrier must stay under 1.5x their speed (plus slack).
		tracker.WindowSpeed = math.max(tracker.WindowSpeed, humanoid.WalkSpeed)
		local windowTime = now - tracker.WindowStart
		if windowTime >= 1 then
			local allowed = tracker.WindowSpeed * windowTime * SECURITY.SpeedTolerance + SECURITY.SpeedSlackStuds
			if flatDistance(root.Position, tracker.WindowPos) > allowed then
				if now - tracker.FirstStrikeAt > SECURITY.StrikeWindowSeconds then
					tracker.Strikes = 0
					tracker.FirstStrikeAt = now
				end
				tracker.Strikes += 1
			end
			tracker.WindowPos = root.Position
			tracker.WindowStart = now
			tracker.WindowSpeed = humanoid.WalkSpeed
			if tracker.Strikes >= SECURITY.MaxStrikes then
				EggService.ForceDrop(player, "TooFast")
				continue
			end
		end

		local cfg = GameConfig.Eggs[egg.Kind]
		if flatDistance(root.Position, deps.Map.NestCenter) <= GameConfig.Guardian.NoiseRadius then
			deps.Guardian.AddNoise(cfg.CarryNoisePerSecond * elapsed * (1 - deps.Pets.GetPerk(player, "Quiet")))
		end
		if egg.HelperCount > 0 then
			updateHelpers(player, egg, root, now)
		end
		if deps.Map.IsInSafeZone(root.Position) then
			bank(player, egg, root, now)
		end
	end
end

-- Once a second: respawn empty slots and roll unclaimed dropped eggs back home.
local function slotTick()
	local now = os.clock()
	for _, slot in slots do
		if slot.EggId == nil and slot.RespawnAt and now >= slot.RespawnAt then
			spawnInSlot(slot)
		end
	end
	for _, egg in ledger:All() do
		if egg.State == "Dropped" and now - egg.DroppedAt >= NEST.DroppedEggSeconds then
			returnToSlot(egg)
		end
	end
end

local function onPhaseChanged(phase)
	local isMidnight = phase == "Midnight"
	if isMidnight then
		midnightBanked = 0
	elseif midnightBanked > 0 then
		notifyAll(("🌅 Midnight is over! This server banked %d glowing eggs."):format(midnightBanked), "midnight")
	end
	-- Eggs waiting in the nest glow at Midnight (better odds of a Midnight pet) and fade at dawn.
	for _, egg in ledger:All() do
		if egg.State == "Nest" and not egg.Stray and egg.Midnight ~= isMidnight then
			egg.Midnight = isMidnight
			local chance = if isMidnight then VARIANTS.MidnightChanceMidnightEgg else VARIANTS.MidnightChanceDusk
			egg.Variant = if rng:NextNumber() < chance then "Midnight" else "Normal"
			local model = models[egg.Id]
			if model then
				PetModels.SetEggMidnight(model, egg.Kind, isMidnight, true)
			end
			syncModel(egg)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Requests and queries
---------------------------------------------------------------------------------------------------

-- Action "Grab": claim a free egg, or join a Giant egg someone else is carrying.
function EggService.HandleGrab(player, eggId)
	if typeof(eggId) ~= "number" or eggId ~= eggId then
		return
	end
	local root, humanoid = getCharacterParts(player)
	if not root then
		return
	end
	local now = os.clock()
	if stunnedUntil[player] and now < stunnedUntil[player] then
		return
	end
	local egg = ledger:Get(eggId)
	if not egg then
		notify(player, "That egg is gone.", "warn")
		return
	end
	local model = models[egg.Id]
	if not model or not model.PrimaryPart then
		return
	end

	if egg.State == "Carried" then
		if egg.Kind == "Giant" then
			tryJoinHelper(player, egg, root, now)
		elseif egg.CarrierId ~= player.UserId then
			notify(player, "Too slow! Someone grabbed it first.", "warn")
		end
		return
	end

	local cfg = GameConfig.Eggs[egg.Kind]
	local reach = PLAYER.GrabRange + PLAYER.GrabRangeSlack + cfg.Height / 2
	if (model.PrimaryPart.Position - root.Position).Magnitude > reach then
		return
	end

	local ok, reason = ledger:TryClaim(egg.Id, player.UserId, now)
	if not ok then
		if reason == "locked" then
			notify(player, "Hold on, it's still rolling!", "info")
		end
		return
	end
	if not attachToCharacter(egg, root) then
		ledger:TryDrop(egg.Id, now, 0)
		return
	end
	-- Movement checks start from where the server saw the pickup, so a teleport after grabbing is caught.
	egg.PickupPos = root.Position
	EggService.RefreshSpeed(player)
	trackers[player] = newTracker(root.Position, humanoid.WalkSpeed, now)

	if flatDistance(root.Position, deps.Map.NestCenter) <= GameConfig.Guardian.NoiseRadius then
		deps.Guardian.AddNoise(cfg.GrabNoise * (1 - deps.Pets.GetPerk(player, "Quiet")))
	end
	syncModel(egg)
	syncPlayer(player)
	if egg.Kind == "Giant" then
		notifyAll(("🥚 %s grabbed the GIANT egg! Help carry it!"):format(player.DisplayName), "giant")
	end
end

-- Action "Drop": put your egg down, or stop helping.
function EggService.HandleDrop(player)
	if ledger:HelpingWith(player.UserId) then
		stopHelping(player, "You stopped helping.")
		return
	end
	EggService.ForceDrop(player, "Dropped")
end

-- How much the guardian wants to chase this player.
function EggService.GetThreatWeight(player)
	local egg = ledger:CarriedBy(player.UserId)
	if egg then
		return GameConfig.Eggs[egg.Kind].ThreatWeight
	end
	if ledger:HelpingWith(player.UserId) then
		return 1.6
	end
	return 1
end

function EggService.IsCarrying(player)
	return ledger:CarriedBy(player.UserId) ~= nil
end

-- Called by GuardianService when she reaches a player.
function EggService.OnPlayerCaught(player, fromPosition)
	local wasCarrying = ledger:CarriedBy(player.UserId) ~= nil
	EggService.ForceDrop(player, "Caught")
	if not wasCarrying then
		notify(player, "💫 Mama Moss bonked you!", "danger")
	end
	stunnedUntil[player] = os.clock() + PLAYER.StunSeconds
	player:SetAttribute("MH_Stunned", true)
	EggService.RefreshSpeed(player)
	caughtRemote:FireClient(player, fromPosition)
	task.delay(PLAYER.StunSeconds, function()
		local untilTime = stunnedUntil[player]
		if player.Parent and untilTime and os.clock() >= untilTime - 0.05 then
			stunnedUntil[player] = nil
			player:SetAttribute("MH_Stunned", false)
			EggService.RefreshSpeed(player)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------------------------------

local function onCharacterAdded(player, character)
	stunnedUntil[player] = nil
	player:SetAttribute("MH_Stunned", false)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GROUPS.Players
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GROUPS.Players
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if humanoid and root then
		humanoid.Died:Connect(function()
			EggService.ForceDrop(player, "Died")
		end)
		EggService.RefreshSpeed(player)
	end
end

local function onPlayerAdded(player)
	player:SetAttribute("MH_Stunned", false)
	syncPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		EggService.ForceDrop(player, "Lost")
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	EggService.ForceDrop(player, "Left")
	trackers[player] = nil
	stunnedUntil[player] = nil
	helperAwaySince[player.UserId] = nil
end

function EggService.Init(dependencies)
	deps = dependencies
	notifyRemote = Net.Get("Notify")
	hatchedRemote = Net.Get("Hatched")
	caughtRemote = Net.Get("Caught")

	for _, definition in NEST.Slots do
		table.insert(slots, {
			Index = #slots + 1,
			Kind = definition.Kind,
			Position = deps.Map.NestSurface(definition.Offset),
			Stray = false,
		})
	end
	for _, position in NEST.StraySlots do
		table.insert(slots, {
			Index = #slots + 1,
			Kind = "Pebble",
			Position = deps.Map.TrailPoint(position),
			Stray = true,
		})
	end
	for _, slot in slots do
		spawnInSlot(slot)
	end

	deps.Cycle.OnPhaseChanged(onPhaseChanged)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(carrierTick)
			if not ok then
				warn("[EggService] " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(slotTick)
			if not ok then
				warn("[EggService] " .. tostring(err))
			end
		end
	end)
end

return EggService
