-- WorldFX
-- Client-only visuals. Nothing here changes the game; it runs on each player's own device:
--   * Dusk and Midnight lighting, eased in when the phase changes;
--   * every player's equipped pet following them (built locally from the MH_Pet attribute, so it
--     costs no network traffic);
--   * Mama Moss's "z Z z" while she sleeps and a "!" when she is awake, with a camera shake nearby;
--   * a shake and a shove when she catches you;
--   * glowing ropes from Giant-egg helpers to the egg;
--   * fireflies around you.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetCatalog = require(Modules.PetCatalog)
local PetModels = require(Modules.PetModels)
local Net = require(Modules.Net)

local mapRoot = workspace:WaitForChild("MidnightMap")
local eggFolder = mapRoot:WaitForChild("Eggs")

local AMBER = Color3.fromRGB(255, 196, 110)

local clientFolder = Instance.new("Folder")
clientFolder.Name = "MidnightClientFX"
clientFolder.Parent = workspace

---------------------------------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------------------------------

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end
local grade = Lighting:FindFirstChild("MH_Grade")
if not grade then
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "MH_Grade"
	grade.Parent = Lighting
end

local PRESETS = {
	Dusk = {
		Lighting = {
			ClockTime = 19.4,
			Brightness = 1.6,
			Ambient = Color3.fromRGB(72, 64, 98),
			OutdoorAmbient = Color3.fromRGB(124, 110, 158),
			ExposureCompensation = 0.2,
		},
		Atmosphere = {
			Density = 0.33,
			Offset = 0.08,
			Color = Color3.fromRGB(196, 168, 236),
			Decay = Color3.fromRGB(96, 66, 140),
			Glare = 0,
			Haze = 1.4,
		},
		Grade = { TintColor = Color3.fromRGB(255, 242, 236), Saturation = 0.08, Contrast = 0.06, Brightness = 0 },
	},
	Midnight = {
		Lighting = {
			ClockTime = 23.8,
			Brightness = 1,
			Ambient = Color3.fromRGB(64, 56, 120),
			OutdoorAmbient = Color3.fromRGB(94, 84, 162),
			ExposureCompensation = 0.45,
		},
		Atmosphere = {
			Density = 0.42,
			Offset = 0.05,
			Color = Color3.fromRGB(130, 100, 210),
			Decay = Color3.fromRGB(46, 30, 96),
			Glare = 0,
			Haze = 2.2,
		},
		Grade = { TintColor = Color3.fromRGB(218, 204, 255), Saturation = -0.02, Contrast = 0.12, Brightness = 0.02 },
	},
}

local function applyPhase(phase, seconds)
	local preset = PRESETS[phase] or PRESETS.Dusk
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, preset.Lighting):Play()
	TweenService:Create(atmosphere, info, preset.Atmosphere):Play()
	TweenService:Create(grade, info, preset.Grade):Play()
end

applyPhase(ReplicatedStorage:GetAttribute("MH_Phase") or "Dusk", 0)
ReplicatedStorage:GetAttributeChangedSignal("MH_Phase"):Connect(function()
	applyPhase(ReplicatedStorage:GetAttribute("MH_Phase") or "Dusk", 3.5)
end)

---------------------------------------------------------------------------------------------------
-- Camera shake
---------------------------------------------------------------------------------------------------

local shakeUntil, shakeDuration, shakeStrength = 0, 1, 0

local function shake(duration, strength)
	shakeUntil = os.clock() + duration
	shakeDuration = duration
	shakeStrength = strength
end

RunService:BindToRenderStep("MH_CameraShake", Enum.RenderPriority.Camera.Value + 1, function()
	local remaining = shakeUntil - os.clock()
	local camera = workspace.CurrentCamera
	if remaining <= 0 or not camera then
		return
	end
	local strength = shakeStrength * (remaining / shakeDuration)
	camera.CFrame *= CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
end)

Net.Get("Caught").OnClientEvent:Connect(function(fromPosition)
	shake(0.45, 1.1)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and typeof(fromPosition) == "Vector3" then
		local away = Vector3.new(root.Position.X - fromPosition.X, 0, root.Position.Z - fromPosition.Z)
		local direction = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
		root:ApplyImpulse((direction * 60 + Vector3.new(0, 28, 0)) * root.AssemblyMass)
	end
end)

---------------------------------------------------------------------------------------------------
-- Pets following their owners
---------------------------------------------------------------------------------------------------

local followers = {} -- [Player] = { Model, Key, Flies, Seed, Pivot }

local function removeFollower(target)
	local follower = followers[target]
	if follower then
		follower.Model:Destroy()
		followers[target] = nil
	end
end

local function refreshFollower(target)
	local key = target:GetAttribute("MH_Pet")
	if typeof(key) ~= "string" then
		key = ""
	end
	local current = followers[target]
	if current and current.Key == key then
		return
	end
	removeFollower(target)
	local petId, variant = PetCatalog.ParseKey(key)
	if not petId then
		return
	end
	local model = PetModels.BuildPet(petId, variant)
	if not model then
		return
	end
	model.Name = target.Name .. "_Pet"
	model.Parent = clientFolder
	followers[target] = {
		Model = model,
		Key = key,
		Flies = PetCatalog.Pets[petId].Flies,
		Seed = math.random() * 10,
		Pivot = nil,
	}
end

local function watchPlayer(target)
	refreshFollower(target)
	target:GetAttributeChangedSignal("MH_Pet"):Connect(function()
		refreshFollower(target)
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(removeFollower)
for _, target in Players:GetPlayers() do
	watchPlayer(target)
end

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	local t = os.clock()
	for target, follower in followers do
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - cameraPosition).Magnitude > 180 then
			if follower.Model.Parent then
				follower.Model.Parent = nil -- out of sight: skip the work
			end
			follower.Pivot = nil
			continue
		end
		if not follower.Model.Parent then
			follower.Model.Parent = clientFolder
		end

		local look = root.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
		local right = forward:Cross(Vector3.yAxis)
		local velocity = root.AssemblyLinearVelocity
		local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
		local height = if follower.Flies
			then 1.4 + math.sin(t * 3 + follower.Seed) * 0.35
			else -2.1 + (if moving then math.abs(math.sin(t * 9 + follower.Seed)) * 0.35 else 0)
		local position = root.Position - forward * 3.4 + right * 2.4 + Vector3.new(0, height, 0)
		local goal = CFrame.lookAt(position, position + forward)
		follower.Pivot = if follower.Pivot then follower.Pivot:Lerp(goal, 1 - math.exp(-dt * 9)) else goal
		follower.Model:PivotTo(follower.Pivot)
	end
end)

---------------------------------------------------------------------------------------------------
-- Mama Moss: sleeping and awake cues
---------------------------------------------------------------------------------------------------

local guardian = mapRoot:WaitForChild("MamaMoss", 30)
local head = guardian and guardian:WaitForChild("Head", 10)
local sleepLabel, alertLabel
if head then
	local sleepGui = Instance.new("BillboardGui")
	sleepGui.Name = "MH_Zzz"
	sleepGui.Adornee = head
	sleepGui.Size = UDim2.fromOffset(150, 60)
	sleepGui.StudsOffsetWorldSpace = Vector3.new(4, 7, 0)
	sleepGui.MaxDistance = 260
	sleepGui.LightInfluence = 0
	sleepGui.Parent = playerGui
	sleepLabel = Instance.new("TextLabel")
	sleepLabel.Size = UDim2.fromScale(1, 1)
	sleepLabel.BackgroundTransparency = 1
	sleepLabel.Font = Enum.Font.FredokaOne
	sleepLabel.TextSize = 36
	sleepLabel.Text = "z Z z"
	sleepLabel.TextColor3 = Color3.fromRGB(210, 190, 255)
	sleepLabel.TextStrokeTransparency = 0.3
	sleepLabel.Parent = sleepGui

	local alertGui = Instance.new("BillboardGui")
	alertGui.Name = "MH_Alert"
	alertGui.Adornee = head
	alertGui.Size = UDim2.fromOffset(90, 90)
	alertGui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	alertGui.MaxDistance = 400
	alertGui.LightInfluence = 0
	alertGui.Parent = playerGui
	alertLabel = Instance.new("TextLabel")
	alertLabel.Size = UDim2.fromScale(1, 1)
	alertLabel.BackgroundTransparency = 1
	alertLabel.Font = Enum.Font.FredokaOne
	alertLabel.TextSize = 72
	alertLabel.Text = "!"
	alertLabel.TextColor3 = Color3.fromRGB(255, 84, 96)
	alertLabel.TextStrokeTransparency = 0
	alertLabel.Visible = false
	alertLabel.Parent = alertGui
end

local function onGuardianState()
	local state = ReplicatedStorage:GetAttribute("MH_GuardianState") or "Sleeping"
	if state == "Waking" and head then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - head.Position).Magnitude < 90 then
			shake(0.7, 0.7)
		end
	end
end
ReplicatedStorage:GetAttributeChangedSignal("MH_GuardianState"):Connect(onGuardianState)

---------------------------------------------------------------------------------------------------
-- Giant-egg helper ropes and fireflies (updated a few times a second)
---------------------------------------------------------------------------------------------------

local ropes = {} -- ["eggId:userId"] = { A0, A1, Beam, Shell, Root }

local function destroyRope(rope)
	rope.Beam:Destroy()
	rope.A0:Destroy()
	rope.A1:Destroy()
end

local function updateRopes()
	local wanted = {}
	for _, model in eggFolder:GetChildren() do
		local shell = model.PrimaryPart
		local helpers = model:GetAttribute("Helpers") or ""
		if shell and helpers ~= "" and model:GetAttribute("State") == "Carried" then
			for idText in string.gmatch(helpers, "%d+") do
				local helper = Players:GetPlayerByUserId(tonumber(idText))
				local character = helper and helper.Character
				local helperRoot = character and character:FindFirstChild("HumanoidRootPart")
				if helperRoot then
					local key = tostring(model:GetAttribute("EggId")) .. ":" .. idText
					wanted[key] = true
					local rope = ropes[key]
					if not rope or rope.Shell ~= shell or rope.Root ~= helperRoot then
						if rope then
							destroyRope(rope)
						end
						local a0 = Instance.new("Attachment")
						a0.Name = "MH_Rope"
						a0.Parent = helperRoot
						local a1 = Instance.new("Attachment")
						a1.Name = "MH_Rope"
						a1.Parent = shell
						local beam = Instance.new("Beam")
						beam.Attachment0 = a0
						beam.Attachment1 = a1
						beam.Width0 = 0.3
						beam.Width1 = 0.3
						beam.FaceCamera = true
						beam.LightEmission = 1
						beam.Segments = 8
						beam.CurveSize0 = -2
						beam.CurveSize1 = 2
						beam.Color = ColorSequence.new(AMBER)
						beam.Transparency = NumberSequence.new(0.15)
						beam.Parent = a0
						ropes[key] = { A0 = a0, A1 = a1, Beam = beam, Shell = shell, Root = helperRoot }
					end
				end
			end
		end
	end
	for key, rope in ropes do
		if not wanted[key] then
			destroyRope(rope)
			ropes[key] = nil
		end
	end
end

local fireflies = Instance.new("Part")
fireflies.Name = "Fireflies"
fireflies.Anchored = true
fireflies.CanCollide = false
fireflies.CanQuery = false
fireflies.CanTouch = false
fireflies.Transparency = 1
fireflies.Size = Vector3.new(70, 14, 70)
fireflies.Parent = clientFolder
local emitter = Instance.new("ParticleEmitter")
emitter.Shape = Enum.ParticleEmitterShape.Box
emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
emitter.Rate = 7
emitter.Lifetime = NumberRange.new(3, 5)
emitter.Speed = NumberRange.new(0.2, 0.8)
emitter.SpreadAngle = Vector2.new(180, 180)
emitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.2, 0.22),
	NumberSequenceKeypoint.new(0.8, 0.22),
	NumberSequenceKeypoint.new(1, 0),
})
emitter.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
emitter.LightEmission = 1
emitter.LightInfluence = 0
emitter.Parent = fireflies

task.spawn(function()
	while true do
		local ok, err = pcall(function()
			updateRopes()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				fireflies.CFrame = CFrame.new(root.Position + Vector3.new(0, 5, 0))
			end
			local state = ReplicatedStorage:GetAttribute("MH_GuardianState") or "Sleeping"
			if sleepLabel then
				sleepLabel.Visible = state == "Sleeping"
			end
			if alertLabel then
				alertLabel.Visible = state == "Waking" or state == "Hunting" or state == "Gloating"
			end
		end)
		if not ok then
			warn("[WorldFX] " .. tostring(err))
		end
		task.wait(0.25)
	end
end)

-- A gentle bob on the sleeping "z Z z" and a pulse on the "!".
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	if sleepLabel and sleepLabel.Visible then
		sleepLabel.Position = UDim2.fromOffset(0, math.sin(t * 2) * 6)
		sleepLabel.TextTransparency = 0.25 + 0.25 * math.sin(t * 2.5)
	end
	if alertLabel and alertLabel.Visible then
		alertLabel.TextSize = 64 + math.floor(math.abs(math.sin(t * 6)) * 14)
	end
end)
