--!nocheck
-- Studio-less integration test. Not part of the Roblox place.
-- Run from the repository root:  lune run tests/smoke.luau
--
-- Builds the Rojo tree in a simulated DataModel (Lune's Roblox library checks every property name and
-- type against Roblox's API database), runs Main.server.lua plus MainUI and WorldFX for one local
-- player, routes RemoteEvents, moves Mama Moss toward her MoveTo goals, and walks scripted players
-- through the acceptance list: single claim under contention, one reward per egg, repeated input,
-- drop locks, leaving mid-carry, a teleport exploit, Giant-egg helpers, the guardian waking and
-- catching a carrier, Midnight, equipping, malformed requests and the rate limit.
-- Not covered (needs Studio): real physics, rendering, touch input, network latency, DataStores.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Instance, Enum = roblox.Instance, roblox.Enum
local Vector3, Vector2, CFrame = roblox.Vector3, roblox.Vector2, roblox.CFrame

local problems = {}
local function problem(message)
	table.insert(problems, message)
	print("  !! " .. message)
end

---------------------------------------------------------------------------------------------------
-- Signals and engine shims
---------------------------------------------------------------------------------------------------

local function newSignal(label)
	local connections = {}
	local signal = {}
	function signal:Connect(fn)
		local connection = { Connected = true, Fn = fn }
		function connection:Disconnect()
			connection.Connected = false
		end
		table.insert(connections, connection)
		return connection
	end
	function signal:Once(fn)
		local connection
		connection = signal:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end
	function signal:Wait()
		local thread = coroutine.running()
		local connection
		connection = signal:Connect(function(...)
			connection:Disconnect()
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	function signal:Fire(...)
		for _, connection in table.clone(connections) do
			if connection.Connected then
				task.spawn(function(...)
					local ok, err = pcall(connection.Fn, ...)
					if not ok then
						problem("error in " .. label .. " handler: " .. tostring(err))
					end
				end, ...)
			end
		end
	end
	return signal
end

local signalStore = {}
local function signalFor(instance, name)
	local bucket = signalStore[instance]
	if not bucket then
		bucket = {}
		signalStore[instance] = bucket
	end
	local signal = bucket[name]
	if not signal then
		signal = newSignal(name)
		bucket[name] = signal
	end
	return signal
end

local function event(className, name)
	roblox.implementProperty(className, name, function(self)
		return signalFor(self, name)
	end)
end
for _, spec in
	{
		{ "Players", "PlayerAdded" },
		{ "Players", "PlayerRemoving" },
		{ "Player", "CharacterAdded" },
		{ "Player", "CharacterRemoving" },
		{ "Humanoid", "Died" },
		{ "Instance", "DescendantAdded" },
		{ "Instance", "ChildAdded" },
		{ "Instance", "Destroying" },
		{ "RemoteEvent", "OnServerEvent" },
		{ "RemoteEvent", "OnClientEvent" },
		{ "GuiButton", "Activated" },
		{ "RunService", "Heartbeat" },
		{ "RunService", "RenderStepped" },
		{ "UserInputService", "InputBegan" },
		{ "UserInputService", "LastInputTypeChanged" },
	}
do
	event(spec[1], spec[2])
end

local function method(className, name, fn)
	roblox.implementMethod(className, name, fn)
end

method("Instance", "WaitForChild", function(self, name, timeout)
	local deadline = os.clock() + (timeout or 5)
	while true do
		local child = self:FindFirstChild(name)
		if child then
			return child
		end
		if os.clock() > deadline then
			if not timeout then
				problem(("WaitForChild(%q) on %s never resolved"):format(name, self:GetFullName()))
			end
			return nil
		end
		task.wait(0.02)
	end
end)
method("Instance", "GetAttributeChangedSignal", function(self, name)
	return signalFor(self, "Attribute:" .. name)
end)
method("Instance", "GetPropertyChangedSignal", function(self, name)
	return signalFor(self, "Property:" .. name)
end)

-- Lune keeps Position separately from CFrame, so everything that moves sets both.
local function place(part, cframe)
	part.CFrame = cframe
	part.Position = cframe.Position
end
local function syncPositions(root)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Position = descendant.CFrame.Position
		end
	end
end
local function modelPivot(model)
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant.CFrame
		end
	end
	return CFrame.new()
end
method("Model", "GetPivot", modelPivot)
method("Model", "PivotTo", function(self, target)
	local delta = target * modelPivot(self):Inverse()
	for _, descendant in self:GetDescendants() do
		if descendant:IsA("BasePart") then
			place(descendant, delta * descendant.CFrame)
		end
	end
end)

method("BasePart", "SetNetworkOwner", function() end)
local impulses = {}
method("BasePart", "ApplyImpulse", function(self, impulse)
	impulses[self] = impulse
end)

local moveGoals = {}
method("Humanoid", "MoveTo", function(self, goal)
	moveGoals[self] = goal
end)
method("Humanoid", "SetStateEnabled", function() end)

method("Players", "GetPlayers", function(self)
	local list = {}
	for _, child in self:GetChildren() do
		if child:IsA("Player") then
			table.insert(list, child)
		end
	end
	return list
end)
method("Players", "GetPlayerByUserId", function(self, userId)
	for _, child in self:GetChildren() do
		if child:IsA("Player") and child.UserId == userId then
			return child
		end
	end
	return nil
end)

local CONTEXT = "server"
method("RunService", "IsServer", function()
	return CONTEXT == "server"
end)
method("RunService", "IsClient", function()
	return CONTEXT == "client"
end)
method("RunService", "IsStudio", function()
	return true
end)
local renderBindings = {}
method("RunService", "BindToRenderStep", function(_, name, _, fn)
	renderBindings[name] = fn
end)

local groups = {}
method("PhysicsService", "IsCollisionGroupRegistered", function(_, name)
	return groups[name] == true
end)
method("PhysicsService", "RegisterCollisionGroup", function(_, name)
	groups[name] = true
end)
method("PhysicsService", "CollisionGroupSetCollidable", function(_, a, b)
	assert(groups[a] and groups[b], "collision group used before it was registered")
end)

method("TweenService", "Create", function(_, instance, _, goals)
	local tween = { Completed = newSignal("Tween.Completed") }
	function tween:Play()
		for key, value in goals do
			instance[key] = value -- checks the property name and type
		end
		tween.Completed:Fire(Enum.PlaybackState.Completed)
	end
	function tween:Cancel() end
	return tween
end)

local boundActions = {}
method("ContextActionService", "BindAction", function(_, name, fn)
	boundActions[name] = fn
end)

local clockStart = os.clock()
method("Workspace", "GetServerTimeNow", function()
	return 1e6 + (os.clock() - clockStart)
end)
method("Workspace", "Raycast", function(_, origin, direction)
	if direction.Y >= 0 then
		return nil
	end
	return { Position = Vector3.new(origin.X, 0, origin.Z), Normal = Vector3.yAxis, Distance = origin.Y }
end)

---------------------------------------------------------------------------------------------------
-- The DataModel, laid out like default.project.json
---------------------------------------------------------------------------------------------------

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
UserInputService.TouchEnabled = true -- the phone layout
UserInputService.KeyboardEnabled = false
workspace.CurrentCamera.ViewportSize = Vector2.new(812, 375)

local sources = {} -- [script instance] = file path

local function mount(parent, directory)
	for _, entry in fs.readDir(directory) do
		local path = directory .. "/" .. entry
		if fs.isDir(path) then
			local folder = Instance.new("Folder")
			folder.Name = entry
			folder.Parent = parent
			mount(folder, path)
		else
			local name, kind = entry:match("^(.-)%.(server)%.lua$")
			if not name then
				name, kind = entry:match("^(.-)%.(client)%.lua$")
			end
			if not name then
				name, kind = entry:match("^(.-)%.lua$"), "module"
			end
			local className = if kind == "server"
				then "Script"
				elseif kind == "client" then "LocalScript"
				else "ModuleScript"
			local script = Instance.new(className)
			script.Name = name
			script.Parent = parent
			sources[script] = path
		end
	end
end

local modules = Instance.new("Folder")
modules.Name = "Modules"
modules.Parent = ReplicatedStorage
mount(modules, "src/ReplicatedStorage/Modules")
mount(ServerScriptService, "src/ServerScriptService")
local starterScripts = Instance.new("Folder")
starterScripts.Name = "StarterPlayerScripts"
mount(starterScripts, "src/StarterPlayer/StarterPlayerScripts")

local function makeRandom(seed)
	local state = math.max(1, math.floor((seed or os.clock() * 1e6) % 4294967296))
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

local caches = { server = {}, client = {} }
local run
local function makeEnvironment(script, context)
	return setmetatable({
		game = game,
		workspace = workspace,
		script = script,
		Instance = Instance,
		Enum = Enum,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Font = roblox.Font,
		TweenInfo = {
			new = function(time, style, direction)
				return { Time = time, EasingStyle = style, EasingDirection = direction }
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Random = { new = makeRandom },
		task = task,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			problem("[" .. context .. " warn] " .. table.concat(parts, " "))
		end,
		require = function(target)
			local cache = caches[context]
			if cache[target] == nil then
				cache[target] = run(target, context)
			end
			return cache[target]
		end,
	}, { __index = getfenv(0) })
end

function run(script, context)
	local path = assert(sources[script], "no source for " .. script:GetFullName())
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = makeEnvironment(script, context),
	})
	return chunk()
end

---------------------------------------------------------------------------------------------------
-- Remotes, players and movement
---------------------------------------------------------------------------------------------------

local localPlayer = nil
local received = {} -- [Player] = { [remoteName] = { {args}, ... } }
local function record(player, remoteName, ...)
	received[player] = received[player] or {}
	received[player][remoteName] = received[player][remoteName] or {}
	table.insert(received[player][remoteName], table.pack(...))
end
method("RemoteEvent", "FireServer", function(self, ...)
	signalFor(self, "OnServerEvent"):Fire(localPlayer, ...)
end)
method("RemoteEvent", "FireClient", function(self, player, ...)
	record(player, self.Name, ...)
	if player == localPlayer then
		signalFor(self, "OnClientEvent"):Fire(...)
	end
end)
method("RemoteEvent", "FireAllClients", function(self, ...)
	for _, player in Players:GetPlayers() do
		record(player, self.Name, ...)
	end
	if localPlayer then
		signalFor(self, "OnClientEvent"):Fire(...)
	end
end)

local function count(player, remoteName)
	return #((received[player] or {})[remoteName] or {})
end
local function last(player, remoteName)
	local list = (received[player] or {})[remoteName] or {}
	return list[#list]
end
local function toasts(player)
	local texts = {}
	for _, args in (received[player] or {}).Notify or {} do
		table.insert(texts, args[1])
	end
	return table.concat(texts, " | ")
end

local nextUserId = 1000
local function spawnCharacter(player, position)
	local character = Instance.new("Model")
	character.Name = player.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.AssemblyMass = 12
	root.AssemblyLinearVelocity = Vector3.zero
	place(root, CFrame.new(position))
	root.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 16
	humanoid.Parent = character
	character.PrimaryPart = root
	character.Parent = workspace
	player.Character = character
	signalFor(player, "CharacterAdded"):Fire(character)
	return character
end

local function join(name)
	nextUserId += 1
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = nextUserId
	local gui = Instance.new("PlayerGui")
	gui.Parent = player
	player.Parent = Players
	signalFor(Players, "PlayerAdded"):Fire(player)
	task.wait(0.05)
	spawnCharacter(player, Vector3.new(0, 3, 102))
	task.wait(0.1)
	return player
end

local function leave(player)
	signalFor(Players, "PlayerRemoving"):Fire(player)
	task.wait(0.05)
	if player.Character then
		signalFor(player, "CharacterRemoving"):Fire(player.Character)
		task.wait(0.05)
		player.Character:Destroy()
	end
	player.Parent = nil
end

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function humanoidOf(player)
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end
local function teleport(player, position)
	place(rootOf(player), CFrame.new(Vector3.new(position.X, 3, position.Z)))
end

local Eggs -- Workspace.MidnightMap.Eggs, set after boot
local EGG_LIFT = 2.7

-- Mama Moss walks toward her MoveTo goal; carried eggs follow their carrier (the weld); Heartbeat
-- and RenderStepped fire every frame.
local running = true
local synced = {}
local lastAttributes = {}
local function fireChangedAttributes()
	for instance, bucket in signalStore do
		for name, signal in bucket do
			local attribute = name:match("^Attribute:(.+)$")
			if attribute then
				local ok, value = pcall(instance.GetAttribute, instance, attribute)
				if ok then
					lastAttributes[instance] = lastAttributes[instance] or {}
					local previous = lastAttributes[instance][attribute]
					if previous ~= value then
						lastAttributes[instance][attribute] = value
						if previous ~= nil or value ~= nil then
							signal:Fire()
						end
					end
				end
			end
		end
	end
end
task.spawn(function()
	local previous = os.clock()
	while running do
		task.wait(1 / 60)
		local now = os.clock()
		local dt = math.min(now - previous, 0.1)
		previous = now
		local mapFolder = workspace:FindFirstChild("MidnightMap")
		local mama = mapFolder and mapFolder:FindFirstChild("MamaMoss")
		if mama and not synced[mama] then
			syncPositions(mama) -- built with CFrames only; give her parts a Position before her first step
			synced[mama] = true
		end
		for humanoid, goal in moveGoals do
			local model = humanoid.Parent
			local root = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
			if not root then
				moveGoals[humanoid] = nil
				continue
			end
			if model.Name == "MamaMoss" then
				local position = root.Position
				local offset = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
				if offset.Magnitude > 0.05 then
					local step = math.min(offset.Magnitude, humanoid.WalkSpeed * dt)
					local nextPosition = position + offset.Unit * step
					model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + offset.Unit))
				end
			end
		end
		if Eggs then
			for _, egg in Eggs:GetChildren() do
				if egg:GetAttribute("State") == "Carried" then
					local carrier = Players:GetPlayerByUserId(egg:GetAttribute("CarrierId"))
					local root = carrier and rootOf(carrier)
					local height = egg.PrimaryPart and egg.PrimaryPart.Size.Y or 3
					if root then
						egg:PivotTo(root.CFrame * CFrame.new(0, EGG_LIFT + height / 2, 0))
					end
				end
			end
		end
		fireChangedAttributes()
		signalFor(RunService, "Heartbeat"):Fire(dt)
		signalFor(RunService, "RenderStepped"):Fire(dt)
		for name, binding in renderBindings do
			local ok, err = pcall(binding, dt)
			if not ok then
				problem("render binding " .. name .. ": " .. tostring(err))
			end
		end
	end
end)

-- Walks at the speed the server allows, like a real character. follow: other players who stay alongside.
local function walkTo(player, target, follow, stopWhen)
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	while true do
		local position = root.Position
		local offset = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if offset.Magnitude < 0.5 or (stopWhen and stopWhen()) then
			return
		end
		local dt = task.wait(1 / 30)
		local step = math.min(offset.Magnitude, humanoid.WalkSpeed * dt)
		local nextPosition = position + offset.Unit * step
		place(root, CFrame.lookAt(nextPosition, nextPosition + offset.Unit))
		for index, other in follow or {} do
			teleport(other, nextPosition + Vector3.new(3 * index, 0, 0))
		end
	end
end

local function serverAction(player, name, payload)
	local remote = ReplicatedStorage.MidnightRemotes.Action
	signalFor(remote, "OnServerEvent"):Fire(player, name, payload)
end

local function eggModel(predicate)
	local best, bestDistance = nil, math.huge
	for _, egg in Eggs:GetChildren() do
		if predicate(egg) then
			local distance = egg.PrimaryPart.Position.Magnitude
			if distance < bestDistance then
				best, bestDistance = egg, distance
			end
		end
	end
	return best
end

local function waitFor(seconds, condition)
	local function test()
		local ok, value = pcall(condition) -- Lune errors on destroyed instances; count that as "not yet"
		return ok and value
	end
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if test() then
			return true
		end
		task.wait(0.05)
	end
	return test()
end

---------------------------------------------------------------------------------------------------
-- Checks
---------------------------------------------------------------------------------------------------

local passed, failed = 0, 0
local function check(name, ok, detail)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. (if detail then "  (" .. tostring(detail) .. ")" else ""))
	end
end
local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 0.01)
end

---------------------------------------------------------------------------------------------------
-- Scenarios
---------------------------------------------------------------------------------------------------

local scenarioOk, scenarioError = pcall(function()
	print("Boot")
	local serverConfig = run(modules.GameConfig, "server")
	caches.server[modules.GameConfig] = serverConfig
	serverConfig.Nest.StrayRespawnSeconds = 1 -- shorter waits for the test
	serverConfig.Nest.DroppedEggSeconds = 3
	task.spawn(run, ServerScriptService.Main, "server")
	waitFor(5, function()
		local eggs = workspace:FindFirstChild("MidnightMap") and workspace.MidnightMap:FindFirstChild("Eggs")
		return eggs ~= nil and #eggs:GetChildren() == 9 and ReplicatedStorage:GetAttribute("MH_Phase") ~= nil
	end)
	syncPositions(workspace)
	task.wait(0.3)

	local map = workspace:FindFirstChild("MidnightMap")
	check("the map is built", map ~= nil)
	Eggs = map and map:FindFirstChild("Eggs")
	check(
		"nine eggs spawned (6 in the nest, 3 on the trail)",
		Eggs and #Eggs:GetChildren() == 9,
		Eggs and #Eggs:GetChildren()
	)
	check("Mama Moss exists", map and map:FindFirstChild("MamaMoss") ~= nil)
	check("five remotes exist", #ReplicatedStorage.MidnightRemotes:GetChildren() == 5)
	check("the cycle starts at Dusk", ReplicatedStorage:GetAttribute("MH_Phase") == "Dusk")
	check("she starts asleep", ReplicatedStorage:GetAttribute("MH_GuardianState") == "Sleeping")
	local partCount = 0
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end
	check("the map stays light for phones (under 900 parts)", partCount < 900, partCount)

	print("Join and client UI")
	local ava = join("Ava")
	localPlayer = ava
	Players.LocalPlayer = ava
	CONTEXT = "client"
	for _, script in starterScripts:GetChildren() do
		task.spawn(run, script, "client")
	end
	task.wait(0.6)
	CONTEXT = "server"
	local gui = ava.PlayerGui
	local hud = gui:FindFirstChild("MidnightHUD")
	local actions = gui:FindFirstChild("MidnightActions")
	check("the HUD is built", hud ~= nil and hud:FindFirstChild("PetsPanel") ~= nil)
	check("the action buttons are built", actions ~= nil and actions:FindFirstChild("ActionButton") ~= nil)
	check(
		"leaderstats show Shells",
		ava:FindFirstChild("leaderstats") and ava.leaderstats:FindFirstChild("Shells") ~= nil
	)
	check("the server sent a profile snapshot", count(ava, "ProfileSync") >= 1)
	check("walk speed is set by the server", near(humanoidOf(ava).WalkSpeed, serverConfig.Player.BaseWalkSpeed))
	local actionButton = actions.ActionButton
	check("no action button away from eggs", actionButton.Visible == false)

	print("A. Practice egg: tap GRAB, carry, bank, one reveal")
	local stray = eggModel(function(egg)
		return egg:GetAttribute("Stray") and egg:GetAttribute("State") == "Nest"
	end)
	local strayId = stray:GetAttribute("EggId")
	local strayName = stray.Name
	walkTo(ava, stray.PrimaryPart.Position - Vector3.new(0, 0, 3))
	task.wait(0.3)
	check(
		"the GRAB button appears next to an egg",
		actionButton.Visible and actionButton:FindFirstChild("TextLabel") ~= nil
	)
	signalFor(actionButton, "Activated"):Fire()
	check(
		"tapping GRAB claims the egg",
		waitFor(1, function()
			return ava:GetAttribute("MH_Carrying") == strayId
		end)
	)
	check("carrying slows you down", near(humanoidOf(ava).WalkSpeed, 18 * serverConfig.Eggs.Pebble.CarrySpeed))
	task.wait(0.2)
	check("the DROP button shows while carrying", actions.DropButton.Visible)
	walkTo(ava, Vector3.new(0, 0, 90))
	check(
		"walking into the Hatchery hatches the egg",
		waitFor(1, function()
			return count(ava, "Hatched") == 1
		end)
	)
	local result = last(ava, "Hatched")
	local hatch = result and result[1]
	check(
		"the hatch names a real pet",
		hatch and serverConfig.Eggs.Pebble ~= nil and hatch.PetId ~= nil,
		hatch and hatch.PetId
	)
	check("practice eggs pay half (5 Shells)", hatch and hatch.Shells == 5, hatch and hatch.Shells)
	check("the egg is used up", not Eggs:FindFirstChild(strayName))
	check("you are no longer carrying", ava:GetAttribute("MH_Carrying") == 0)
	check("speed is back to normal", near(humanoidOf(ava).WalkSpeed, 18) or humanoidOf(ava).WalkSpeed > 18)
	check(
		"the first pet is equipped automatically",
		typeof(ava:GetAttribute("MH_Pet")) == "string" and ava:GetAttribute("MH_Pet") ~= ""
	)
	check(
		"the reveal card shows",
		waitFor(1, function()
			return hud.HatchReveal.Visible
		end)
	)
	for _ = 1, 10 do
		ReplicatedStorage.MidnightRemotes.Action:FireServer("Grab", strayId) -- repeated input on a used egg
	end
	task.wait(0.4)
	check("repeated grabs of a used egg give nothing", count(ava, "Hatched") == 1)
	check("Shells counted once", ava.leaderstats.Shells.Value == 5, ava.leaderstats.Shells.Value)
	check(
		"the practice slot respawns",
		waitFor(3, function()
			return #Eggs:GetChildren() == 9
		end)
	)
	check(
		"your pet follows you (client model)",
		waitFor(1, function()
			local fx = workspace:FindFirstChild("MidnightClientFX")
			return fx ~= nil and fx:FindFirstChild("Ava_Pet") ~= nil
		end)
	)

	print("B. Two players grab the same egg at the same moment")
	local bo, cy = join("Bo"), join("Cy")
	local moss = eggModel(function(egg)
		return egg:GetAttribute("Kind") == "Moss" and egg:GetAttribute("State") == "Nest"
	end)
	local mossId = moss:GetAttribute("EggId")
	teleport(bo, moss.PrimaryPart.Position + Vector3.new(3, 0, 0))
	teleport(cy, moss.PrimaryPart.Position + Vector3.new(-3, 0, 0))
	task.wait(0.1)
	serverAction(bo, "Grab", mossId)
	serverAction(cy, "Grab", mossId)
	task.wait(0.3)
	local boHas = bo:GetAttribute("MH_Carrying") == mossId
	local cyHas = cy:GetAttribute("MH_Carrying") == mossId
	check("exactly one of them gets it", (boHas and not cyHas) or (cyHas and not boHas))
	local winner, loser = if boHas then bo else cy, if boHas then cy else bo
	check("the other is told", toasts(loser):find("Too slow") ~= nil, toasts(loser))

	print("C. Teleporting into the Hatchery with an egg")
	local hatchesBefore = count(winner, "Hatched")
	teleport(winner, Vector3.new(0, 0, 90))
	task.wait(0.4)
	check("no hatch for a teleport", count(winner, "Hatched") == hatchesBefore)
	check("the egg is taken away", winner:GetAttribute("MH_Carrying") == 0)
	check(
		"the egg goes back to its nest slot",
		moss:GetAttribute("State") == "Nest" and moss.PrimaryPart.Position.Z < -70
	)

	print("D. A Giant egg with a helper (guardian kept asleep for this one)")
	local giantNoise = { serverConfig.Eggs.Giant.GrabNoise, serverConfig.Eggs.Giant.CarryNoisePerSecond }
	serverConfig.Eggs.Giant.GrabNoise = 0
	serverConfig.Eggs.Giant.CarryNoisePerSecond = 0
	teleport(bo, Vector3.new(0, 0, 30))
	teleport(cy, Vector3.new(0, 0, 30))
	task.wait(0.3)
	local giant = eggModel(function(egg)
		return egg:GetAttribute("Kind") == "Giant" and egg:GetAttribute("State") == "Nest"
	end)
	local giantId = giant:GetAttribute("EggId")
	walkTo(bo, giant.PrimaryPart.Position + Vector3.new(0, 0, 4))
	serverAction(bo, "Grab", giantId)
	task.wait(0.2)
	check("Bo carries the Giant egg", bo:GetAttribute("MH_Carrying") == giantId)
	local solo = humanoidOf(bo).WalkSpeed
	check("alone it is very slow", near(solo, 18 * serverConfig.Eggs.Giant.CarrySpeed, 0.05), solo)
	teleport(cy, rootOf(bo).Position + Vector3.new(3, 0, 0))
	task.wait(0.1)
	serverAction(cy, "Grab", giantId)
	task.wait(0.2)
	check("Cy joins as a helper", cy:GetAttribute("MH_Helping") == giantId)
	check("a helper speeds the carrier up", humanoidOf(bo).WalkSpeed > solo + 2, humanoidOf(bo).WalkSpeed)
	local boHatches, cyHatches = count(bo, "Hatched"), count(cy, "Hatched")
	walkTo(bo, Vector3.new(0, 0, 90), { cy })
	check(
		"both get a hatch",
		waitFor(1.5, function()
			return count(bo, "Hatched") == boHatches + 1 and count(cy, "Hatched") == cyHatches + 1
		end),
		("%d %d"):format(count(bo, "Hatched"), count(cy, "Hatched"))
	)
	local cyHatch = last(cy, "Hatched")
	check("Cy's hatch is marked shared", cyHatch and cyHatch[1].Helped == true)
	check("Giant eggs pay 100 Shells each", bo.leaderstats.Shells.Value == 100 and cy.leaderstats.Shells.Value == 100)
	check("the helper is released", cy:GetAttribute("MH_Helping") == 0)
	serverConfig.Eggs.Giant.GrabNoise = giantNoise[1]
	serverConfig.Eggs.Giant.CarryNoisePerSecond = giantNoise[2]

	print("E. Drop, pickup lock, and leaving with an egg")
	local pebble = eggModel(function(egg)
		return egg:GetAttribute("Kind") == "Pebble"
			and egg:GetAttribute("State") == "Nest"
			and not egg:GetAttribute("Stray")
	end)
	local pebbleId = pebble:GetAttribute("EggId")
	teleport(bo, pebble.PrimaryPart.Position + Vector3.new(2, 0, 0))
	teleport(cy, pebble.PrimaryPart.Position + Vector3.new(-2, 0, 0))
	task.wait(0.1)
	serverAction(bo, "Grab", pebbleId)
	task.wait(0.15)
	serverAction(bo, "Drop")
	task.wait(0.05)
	serverAction(cy, "Grab", pebbleId)
	task.wait(0.1)
	check(
		"a just-dropped egg is locked",
		pebble:GetAttribute("State") == "Dropped" and cy:GetAttribute("MH_Carrying") == 0
	)
	task.wait(0.8)
	serverAction(cy, "Grab", pebbleId)
	task.wait(0.15)
	check("after the lock anyone can grab it", cy:GetAttribute("MH_Carrying") == pebbleId)
	leave(cy)
	task.wait(0.2)
	check("leaving drops the egg", pebble:GetAttribute("State") == "Dropped")
	check(
		"an unclaimed dropped egg rolls home",
		waitFor(5, function()
			return pebble:GetAttribute("State") == "Nest"
		end)
	)
	teleport(bo, pebble.PrimaryPart.Position + Vector3.new(2, 0, 0))
	task.wait(0.1)
	serverAction(bo, "Grab", pebbleId)
	task.wait(0.15)
	check("Bo picks it up again", bo:GetAttribute("MH_Carrying") == pebbleId)
	local boHatchesBeforeDeath = count(bo, "Hatched")
	humanoidOf(bo).Health = 0
	signalFor(humanoidOf(bo), "Died"):Fire()
	task.wait(0.2)
	check("dying drops the egg", pebble:GetAttribute("State") == "Dropped" and bo:GetAttribute("MH_Carrying") == 0)
	check("dying gives no reward", count(bo, "Hatched") == boHatchesBeforeDeath)
	signalFor(bo, "CharacterRemoving"):Fire(bo.Character)
	task.wait(0.05)
	bo.Character:Destroy()
	spawnCharacter(bo, Vector3.new(0, 3, 102))
	task.wait(0.3)
	check("Bo respawns at full speed", humanoidOf(bo).WalkSpeed >= 18, humanoidOf(bo).WalkSpeed)

	print("F. Mama Moss wakes, chases and catches a lone Giant carrier")
	check(
		"she is asleep before the heist",
		waitFor(30, function()
			return ReplicatedStorage:GetAttribute("MH_GuardianState") == "Sleeping"
		end),
		ReplicatedStorage:GetAttribute("MH_GuardianState")
	)
	local giant2 = nil
	check(
		"a new Giant egg respawns",
		waitFor(35, function()
			giant2 = eggModel(function(egg)
				return egg:GetAttribute("Kind") == "Giant" and egg:GetAttribute("State") == "Nest"
			end)
			return giant2 ~= nil
		end)
	)
	if giant2 then
		local id = giant2:GetAttribute("EggId")
		teleport(bo, giant2.PrimaryPart.Position + Vector3.new(0, 0, 4))
		task.wait(0.1)
		serverAction(bo, "Grab", id)
		local caughtBefore = count(bo, "Caught")
		local walker = task.spawn(walkTo, bo, Vector3.new(0, 0, 90), nil, function()
			return count(bo, "Caught") > caughtBefore
		end)
		check(
			"the noise wakes her",
			waitFor(6, function()
				local state = ReplicatedStorage:GetAttribute("MH_GuardianState")
				return state == "Waking" or state == "Hunting"
			end),
			ReplicatedStorage:GetAttribute("MH_GuardianNoise")
		)
		check(
			"she hunts the carrier",
			waitFor(4, function()
				return ReplicatedStorage:GetAttribute("MH_GuardianTarget") == bo.UserId
			end)
		)
		check(
			"she catches him",
			waitFor(12, function()
				return count(bo, "Caught") > caughtBefore
			end)
		)
		task.cancel(walker)
		task.wait(0.15)
		check("the egg drops", giant2:GetAttribute("State") == "Dropped")
		check("he is stunned", near(humanoidOf(bo).WalkSpeed, serverConfig.Player.StunWalkSpeed))
		check(
			"the stun wears off",
			waitFor(2.5, function()
				return humanoidOf(bo).WalkSpeed >= 18
			end)
		)
	end

	print("G. Midnight")
	serverAction(ava, "Debug", "Midnight")
	check(
		"Midnight starts",
		waitFor(1, function()
			return ReplicatedStorage:GetAttribute("MH_Phase") == "Midnight"
		end)
	)
	local glowing = 0
	for _, egg in Eggs:GetChildren() do
		if egg:GetAttribute("State") == "Nest" and not egg:GetAttribute("Stray") and egg:GetAttribute("Midnight") then
			glowing += 1
		end
	end
	check("nest eggs glow", glowing > 0, glowing)
	check(
		"she never sleeps at Midnight",
		waitFor(2, function()
			return ReplicatedStorage:GetAttribute("MH_GuardianState") ~= "Sleeping"
		end)
	)
	serverAction(ava, "Debug", "Dusk")
	check(
		"Dusk returns",
		waitFor(1, function()
			return ReplicatedStorage:GetAttribute("MH_Phase") == "Dusk"
		end)
	)
	task.wait(0.3)
	local stillGlowing = 0
	for _, egg in Eggs:GetChildren() do
		if egg:GetAttribute("State") == "Nest" and egg:GetAttribute("Midnight") then
			stillGlowing += 1
		end
	end
	check("the glow fades at dawn", stillGlowing == 0, stillGlowing)

	print("H. Equipping, bad requests, rate limit")
	local avaPet = ava:GetAttribute("MH_Pet")
	serverAction(ava, "Equip", "Wispurr:Midnight") -- not owned
	for _, payload in { 123, false, string.rep("x", 500), "ToastMoth" } do
		serverAction(ava, "Equip", payload)
	end
	for _, payload in { "abc", false, 1 / 0, -1, 1e12 } do
		serverAction(ava, "Grab", payload)
	end
	serverAction(ava, "Hack", "everything")
	task.wait(0.4)
	check("you can't equip a pet you don't own", ava:GetAttribute("MH_Pet") == avaPet)
	local syncsBefore = count(ava, "ProfileSync")
	task.wait(1.2) -- let the request bucket refill
	for _ = 1, 50 do
		serverAction(ava, "Sync")
	end
	task.wait(0.4)
	local syncs = count(ava, "ProfileSync") - syncsBefore
	check("the rate limit caps a burst of 50 requests", syncs <= 10 and syncs >= 1, syncs)

	print("I. Pets panel")
	signalFor(hud.PetsButton, "Activated"):Fire()
	task.wait(0.2)
	check("the pets panel opens", hud.PetsPanel.Visible)
	task.wait(0.2)
end)
if not scenarioOk then
	problem("harness error: " .. tostring(scenarioError))
end

running = false
task.wait(0.1)
print(("\n%d checks passed, %d failed, %d engine problems"):format(passed, failed, #problems))
for _, message in problems do
	print("  problem: " .. message)
end
process.exit(if failed == 0 and #problems == 0 then 0 else 1)
