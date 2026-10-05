-- GuardianService
-- Mama Moss, the one Round 1 guardian: a giant moss owl-cat asleep behind her eggs.
-- Grabbing and carrying eggs near the nest fills her Wake meter. At 100 she roars (1.6 s warning),
-- then hunts: she prefers carriers (bigger eggs first) but chases whoever is closest, so a friend
-- can pull her away. A catch makes you drop your egg and stuns you; nobody dies.
-- She never enters the Hatchery, gives up after a few seconds without a target, pants after a long
-- chase, and goes home to sleep. At Midnight she is always awake and patrols the nest.
--
-- Server-owned Humanoid; it walks through trees and players (collision groups), so it needs no
-- pathfinding. Public state for the HUD goes to ReplicatedStorage attributes (always replicated,
-- even with streaming): MH_GuardianState, MH_GuardianNoise (0-100), MH_GuardianTarget (UserId or 0).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local Net = require(Modules.Net)

local CFG = GameConfig.Guardian
local GROUPS = GameConfig.CollisionGroups

local ROOT_HEIGHT = 8 -- root centre above the ground: matches HipHeight + half the root size
local HIP_HEIGHT = 5
local ROOT_SIZE = 6

local GuardianService = {}

local deps -- { Map, Cycle, Eggs }
local model, root, humanoid
local lids = {}
local eyes = {}
local pupils = {}

local state = "Sleeping" -- Sleeping | Waking | Hunting | Gloating | Panting | Returning | Patrolling
local stateUntil = 0
local noise = 0
local target = nil
local targetSince = 0
local lastHadTarget = 0
local immunity = {} -- [Player] = os.clock() until which she ignores them
local patrolGoal = nil
local stuckCheckAt = 0
local stuckFrom = Vector3.zero
local published = { State = "", Noise = -1, Target = -1 }

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function getRoot(player)
	local character = player.Character
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
	local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoidRoot or not playerHumanoid or playerHumanoid.Health <= 0 then
		return nil
	end
	return humanoidRoot
end

local function notifyAll(text, style)
	Net.Get("Notify"):FireAllClients(text, style)
end

local function publish()
	if published.State ~= state then
		published.State = state
		ReplicatedStorage:SetAttribute("MH_GuardianState", state)
	end
	local roundedNoise = math.floor(noise + 0.5)
	if published.Noise ~= roundedNoise then
		published.Noise = roundedNoise
		ReplicatedStorage:SetAttribute("MH_GuardianNoise", roundedNoise)
	end
	local targetId = if target then target.UserId else 0
	if published.Target ~= targetId then
		published.Target = targetId
		ReplicatedStorage:SetAttribute("MH_GuardianTarget", targetId)
	end
end

local function setEyes(open)
	for _, lid in lids do
		lid.Transparency = if open then 1 else 0
	end
	for _, pupil in pupils do
		pupil.Transparency = if open then 0 else 1 -- would poke through a closed lid
	end
	local midnight = deps.Cycle.GetPhase() == "Midnight"
	for _, eye in eyes do
		eye.Color = if midnight then Color3.fromRGB(255, 96, 140) else Color3.fromRGB(255, 220, 80)
	end
end

local function setState(newState, duration)
	state = newState
	stateUntil = os.clock() + (duration or 0)
	setEyes(newState ~= "Sleeping")
	if newState ~= "Hunting" then
		target = nil
	end
	publish()
end

local function stop()
	humanoid:MoveTo(root.Position)
end

local function homePosition()
	return deps.Map.GuardianHome.Position
end

---------------------------------------------------------------------------------------------------
-- Model
---------------------------------------------------------------------------------------------------

local function buildModel()
	local home = deps.Map.GuardianHome
	local rootCFrame = home + Vector3.new(0, ROOT_HEIGHT, 0)

	model = Instance.new("Model")
	model.Name = "MamaMoss"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(ROOT_SIZE, ROOT_SIZE, ROOT_SIZE)
	root.CFrame = rootCFrame
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	root.CanTouch = false
	root.CollisionGroup = GROUPS.Guardian
	root.Parent = model

	local MOSS = Color3.fromRGB(78, 116, 64)
	local MOSS_DARK = Color3.fromRGB(56, 88, 50)
	local BELLY = Color3.fromRGB(226, 214, 172)
	local ORANGE = Color3.fromRGB(232, 160, 70)

	local function piece(name, size, offset, color, options)
		options = options or {}
		local part
		if options.Wedge then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			-- the shape goes first: a Ball would force a non-uniform size to be uniform
			part.Shape = if options.Ellipsoid then Enum.PartType.Block else (options.Shape or Enum.PartType.Ball)
		end
		part.Name = name
		part.Size = size
		part.CFrame = rootCFrame * offset
		part.Color = color
		part.Material = options.Material or Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = options.Shadow == true
		part.CollisionGroup = GROUPS.Guardian
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if options.Ellipsoid then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	-- Forward is -Z. Offsets are from the root centre (8 studs above her feet).
	piece("Body", Vector3.new(14, 14, 14), CFrame.new(0, 1, 0), MOSS, { Material = Enum.Material.Grass, Shadow = true })
	piece("Belly", Vector3.new(9.5, 9.5, 9.5), CFrame.new(0, 0, -3.2), BELLY, { Material = Enum.Material.Fabric })
	piece(
		"Head",
		Vector3.new(10, 10, 10),
		CFrame.new(0, 8.5, -1),
		MOSS,
		{ Material = Enum.Material.Grass, Shadow = true }
	)
	for _, side in { -1, 1 } do
		piece(
			"Ear",
			Vector3.new(1.6, 3.6, 2.6),
			CFrame.new(side * 3.2, 13.4, -1) * CFrame.Angles(0, 0, math.rad(side * -12)),
			MOSS_DARK,
			{
				Wedge = true,
			}
		)
		local eye =
			piece("Eye", Vector3.new(3, 3, 3), CFrame.new(side * 2.2, 9.2, -5.4), Color3.fromRGB(255, 220, 80), {
				Material = Enum.Material.Neon,
			})
		table.insert(eyes, eye)
		local pupil =
			piece("Pupil", Vector3.new(1.4, 1.4, 1.4), CFrame.new(side * 2.2, 9.2, -6.6), Color3.fromRGB(25, 20, 30))
		table.insert(pupils, pupil)
		local lid = piece("Lid", Vector3.new(3.3, 3.3, 3.3), CFrame.new(side * 2.2, 9.2, -5.4), MOSS, {
			Material = Enum.Material.Grass,
		})
		table.insert(lids, lid)
		piece(
			"Wing",
			Vector3.new(2.6, 8, 6.4),
			CFrame.new(side * 7, 1.5, 0.6) * CFrame.Angles(0, 0, math.rad(side * 8)),
			MOSS_DARK,
			{
				Ellipsoid = true,
				Material = Enum.Material.Grass,
			}
		)
		piece("Foot", Vector3.new(3.2, 3.2, 3.2), CFrame.new(side * 3.5, -6.6, -2), ORANGE)
	end
	piece("Beak", Vector3.new(1.4, 1.4, 1.8), CFrame.new(0, 7.6, -6.2) * CFrame.Angles(math.rad(180), 0, 0), ORANGE, {
		Wedge = true,
	})
	piece("Tuft", Vector3.new(3, 3, 3), CFrame.new(-2.5, 13.2, 0.5), MOSS_DARK, { Material = Enum.Material.Grass })
	piece("Tuft", Vector3.new(2.4, 2.4, 2.4), CFrame.new(3.6, 6.5, 3.5), MOSS_DARK, { Material = Enum.Material.Grass })

	humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.WalkSpeed = CFG.ChaseSpeed
	humanoid.AutoRotate = true
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	for _, stateType in
		{
			Enum.HumanoidStateType.Dead,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Seated,
		}
	do
		humanoid:SetStateEnabled(stateType, false)
	end

	model.PrimaryPart = root
	model.Parent = deps.Map.Root
	root:SetNetworkOwner(nil) -- the server moves her; clients cannot push or fling her
end

---------------------------------------------------------------------------------------------------
-- Behaviour
---------------------------------------------------------------------------------------------------

-- Keeps a goal outside the hatchery fence.
local function clampOutsideSafeZone(goal)
	local center = deps.Map.HatcheryCenter
	local limit = deps.Map.HatcheryRadius + CFG.SafeZoneMargin
	local offset = Vector3.new(goal.X - center.X, 0, goal.Z - center.Z)
	if offset.Magnitude >= limit then
		return goal
	end
	local direction = if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(0, 0, -1)
	return Vector3.new(center.X, goal.Y, center.Z) + direction * limit
end

local function pickTarget(now, aggroRadius)
	local best, bestScore = nil, 0
	for _, player in Players:GetPlayers() do
		local until_ = immunity[player]
		if until_ and until_ > now then
			continue
		end
		local playerRoot = getRoot(player)
		if not playerRoot then
			continue
		end
		local position = playerRoot.Position
		if deps.Map.IsInSafeZone(position) or flatDistance(position, homePosition()) > CFG.LeashRadius then
			continue
		end
		local distance = flatDistance(position, root.Position)
		if distance > aggroRadius then
			continue
		end
		local score = deps.Eggs.GetThreatWeight(player) / math.max(distance, 6)
		if player == target then
			score *= 1.35 -- stick with the current target unless someone is clearly better
		end
		if score > bestScore then
			best, bestScore = player, score
		end
	end
	return best
end

local function nearbyCarrier(radius)
	for _, player in Players:GetPlayers() do
		local playerRoot = getRoot(player)
		if
			playerRoot
			and deps.Eggs.IsCarrying(player)
			and not deps.Map.IsInSafeZone(playerRoot.Position)
			and flatDistance(playerRoot.Position, root.Position) <= radius
		then
			return player
		end
	end
	return nil
end

local function wake(reason)
	setState("Waking", CFG.WakeRoarSeconds)
	stop()
	if reason == "noise" then
		notifyAll("😾 Mama Moss WOKE UP! Run for the Hatchery!", "danger")
	end
end

local function catch(player, now)
	immunity[player] = now + GameConfig.Player.CatchImmunitySeconds
	setState("Gloating", CFG.GloatSeconds)
	stop()
	deps.Eggs.OnPlayerCaught(player, root.Position)
end

local function goHomeAndSleep()
	noise = CFG.RestNoise
	model:PivotTo(deps.Map.GuardianHome + Vector3.new(0, ROOT_HEIGHT, 0)) -- face the hatchery again
	setState("Sleeping")
end

local function step(dt)
	local now = os.clock()
	local midnight = deps.Cycle.GetPhase() == "Midnight"
	local aggroRadius = if midnight then CFG.MidnightAggroRadius else CFG.AggroRadius

	if state == "Sleeping" then
		-- Check before draining: noise is capped at the threshold, so draining first could hold it
		-- just under 100 forever while a carrier keeps topping it up.
		if midnight then
			wake("midnight")
		elseif noise >= CFG.WakeThreshold then
			wake("noise")
		else
			noise = math.max(0, noise - CFG.NoiseDecayPerSecond * dt)
		end
	elseif state == "Waking" or state == "Gloating" or state == "Panting" then
		stop()
		if now >= stateUntil then
			setState("Hunting")
			lastHadTarget = now
			targetSince = now
		end
	elseif state == "Hunting" then
		local newTarget = pickTarget(now, aggroRadius)
		if newTarget ~= target then
			target = newTarget
			targetSince = now
		end
		local targetRoot = target and getRoot(target)
		if target and targetRoot then
			lastHadTarget = now
			humanoid.WalkSpeed = if midnight then CFG.MidnightChaseSpeed else CFG.ChaseSpeed
			humanoid:MoveTo(clampOutsideSafeZone(targetRoot.Position))
			local closeEnough = flatDistance(targetRoot.Position, root.Position) <= CFG.CatchRadius
				and math.abs(targetRoot.Position.Y - root.Position.Y) < 14
			if closeEnough then
				catch(target, now)
			elseif now - targetSince >= CFG.ChaseBurstSeconds then
				setState("Panting", CFG.PantSeconds) -- an escape window after a long chase
				stop()
			end
		else
			target = nil
			stop()
			if now - lastHadTarget >= CFG.LoseInterestSeconds then
				setState(if midnight then "Patrolling" else "Returning")
			end
		end
	elseif state == "Returning" then
		if midnight then
			setState("Patrolling")
		elseif nearbyCarrier(CFG.NoticeRadius) then
			setState("Hunting")
			lastHadTarget = now
			targetSince = now
		else
			humanoid.WalkSpeed = CFG.ReturnSpeed
			humanoid:MoveTo(homePosition())
			if flatDistance(root.Position, homePosition()) < 4 then
				goHomeAndSleep()
			end
		end
	elseif state == "Patrolling" then
		if not midnight then
			setState("Returning")
		elseif pickTarget(now, aggroRadius) then
			setState("Hunting")
			lastHadTarget = now
			targetSince = now
		else
			if not patrolGoal or flatDistance(root.Position, patrolGoal) < 5 then
				local angle = math.random() * math.pi * 2
				local distance = CFG.PatrolRadius * math.sqrt(math.random())
				patrolGoal = homePosition() + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			end
			humanoid.WalkSpeed = CFG.PatrolSpeed
			humanoid:MoveTo(clampOutsideSafeZone(patrolGoal))
		end
	end

	-- Never stray past the leash; never stand inside the hatchery.
	if flatDistance(root.Position, homePosition()) > CFG.LeashRadius and state == "Hunting" then
		setState("Returning")
	end
	if deps.Map.IsInSafeZone(root.Position, CFG.SafeZoneMargin) then
		local center = deps.Map.HatcheryCenter
		local away = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, -1)
		humanoid:MoveTo(center + direction * (deps.Map.HatcheryRadius + CFG.SafeZoneMargin + 4))
	end

	-- If she is supposed to move but has not, hop (rare: trees and rocks do not block her).
	if now >= stuckCheckAt then
		local moving = (state == "Hunting" and target ~= nil) or state == "Returning" or state == "Patrolling"
		if moving and flatDistance(root.Position, stuckFrom) < 1 then
			humanoid.Jump = true
		end
		stuckFrom = root.Position
		stuckCheckAt = now + 1.5
	end

	publish()
end

---------------------------------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------------------------------

-- Noise from grabbing or carrying eggs near the nest. Only matters while she sleeps.
function GuardianService.AddNoise(amount)
	if state ~= "Sleeping" or typeof(amount) ~= "number" or amount <= 0 then
		return
	end
	noise = math.min(CFG.WakeThreshold, noise + amount)
end

function GuardianService.GetState()
	return state
end

-- Studio testing.
function GuardianService.ForceWake()
	if state == "Sleeping" or state == "Returning" then
		noise = CFG.WakeThreshold
		wake("noise")
	end
end

function GuardianService.Init(dependencies)
	deps = dependencies
	buildModel()
	setState("Sleeping")

	deps.Cycle.OnPhaseChanged(function(phase)
		if phase == "Midnight" then
			if state == "Sleeping" or state == "Returning" then
				wake("midnight")
			end
		elseif state ~= "Sleeping" then
			setState("Returning")
			notifyAll("🌅 The moon sets... Mama Moss heads home to sleep.", "info")
		end
		setEyes(state ~= "Sleeping")
	end)

	Players.PlayerRemoving:Connect(function(player)
		immunity[player] = nil
		if target == player then
			target = nil
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local ok, err = pcall(step, now - last)
			last = now
			if not ok then
				warn("[GuardianService] " .. tostring(err))
			end
		end
	end)
end

return GuardianService
