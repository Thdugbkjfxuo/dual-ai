-- MainUI
-- The whole mobile-first HUD, built in code (nothing to make by hand in Studio):
--   * one big contextual action button (GRAB / HELP CARRY), placed clear of Roblox's jump button,
--     plus a smaller DROP button while you carry. Keyboard: E / Q. Gamepad: X / B.
--   * Shells, the PETS button, the Dusk/Midnight timer and Mama Moss's Wake meter;
--   * a status line (being chased, what you carry, first-time hints) and a red edge when chased;
--   * toasts, the hatch reveal, and the pets panel (tap a pet to equip it).
-- The client never decides anything: it only asks the server and shows what the server says.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local PetCatalog = require(Modules.PetCatalog)
local RarityTable = require(Modules.RarityTable)
local PetModels = require(Modules.PetModels)
local Net = require(Modules.Net)

local ActionRemote = Net.Get("Action")
local NotifyRemote = Net.Get("Notify")
local HatchedRemote = Net.Get("Hatched")
local ProfileRemote = Net.Get("ProfileSync")

local eggFolder = workspace:WaitForChild("MidnightMap"):WaitForChild("Eggs")

local COLORS = {
	Panel = Color3.fromRGB(28, 22, 44),
	PanelLight = Color3.fromRGB(48, 38, 74),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(200, 190, 224),
	Amber = Color3.fromRGB(255, 196, 80),
	Midnight = Color3.fromRGB(165, 125, 255),
	Danger = Color3.fromRGB(255, 84, 96),
	Good = Color3.fromRGB(110, 230, 140),
	Outline = Color3.fromRGB(16, 10, 28),
	Locked = Color3.fromRGB(70, 64, 86),
}
local TOAST_COLORS = {
	info = Color3.fromRGB(40, 32, 62),
	warn = Color3.fromRGB(130, 86, 24),
	danger = Color3.fromRGB(156, 34, 54),
	good = Color3.fromRGB(32, 112, 64),
	rare = Color3.fromRGB(122, 70, 196),
	midnight = Color3.fromRGB(70, 50, 156),
	giant = Color3.fromRGB(156, 104, 32),
}
local FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamBold

local profile = { Shells = 0, Pets = {}, Equipped = "", Stats = { Hatched = 0, Banked = 0 } }
local firstHatchHintUntil = 0

---------------------------------------------------------------------------------------------------
-- Small builders
---------------------------------------------------------------------------------------------------

local function create(className, props)
	local instance = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = radius or UDim.new(0, 14), Parent = parent })
end

local function outline(parent, thickness, color)
	return create("UIStroke", {
		Thickness = thickness or 2,
		Color = color or COLORS.Outline,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.TextSize = props.TextSize or 20
	local textLabel = create("TextLabel", props)
	create("UIStroke", {
		Thickness = 1.5,
		Color = COLORS.Outline,
		Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = textLabel,
	})
	return textLabel
end

local function formatNumber(value)
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

---------------------------------------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------------------------------------

local hud = create("ScreenGui", {
	Name = "MidnightHUD",
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = playerGui,
})
local hudScale = create("UIScale", { Parent = hud })

-- The action buttons live on their own screen in real pixels, so they can sit next to Roblox's
-- touch jump button (which is not scaled either).
local actionGui = create("ScreenGui", {
	Name = "MidnightActions",
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 6,
	Parent = playerGui,
})

local edgeGui = create("ScreenGui", {
	Name = "MidnightEdge",
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.None,
	DisplayOrder = 4,
	Parent = playerGui,
})

---------------------------------------------------------------------------------------------------
-- Top-left: Shells and the PETS button
---------------------------------------------------------------------------------------------------

local shellsChip = create("Frame", {
	Name = "Shells",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 0.42, -4),
	Size = UDim2.fromOffset(168, 46),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	Parent = hud,
})
corner(shellsChip)
outline(shellsChip)
label({ Text = "🐚", TextSize = 24, Size = UDim2.fromOffset(44, 46), Parent = shellsChip })
local shellsLabel = label({
	Text = "0",
	TextSize = 24,
	TextColor3 = COLORS.Amber,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(44, 0),
	Size = UDim2.new(1, -52, 1, 0),
	Parent = shellsChip,
})
local shellsPop = create("UIScale", { Parent = shellsChip })

local petsButton = create("TextButton", {
	Name = "PetsButton",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 12, 0.42, 4),
	Size = UDim2.fromOffset(168, 50),
	BackgroundColor3 = COLORS.PanelLight,
	AutoButtonColor = true,
	Text = "",
	Parent = hud,
})
corner(petsButton)
outline(petsButton, 2, COLORS.Amber)
label({ Text = "🐾 PETS", TextSize = 24, Size = UDim2.fromScale(1, 1), Parent = petsButton })
local petsDot = create("Frame", {
	Name = "NewDot",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -6, 0, 6),
	Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = COLORS.Danger,
	Visible = false,
	Parent = petsButton,
})
corner(petsDot, UDim.new(1, 0))

---------------------------------------------------------------------------------------------------
-- Top-centre: the Dusk/Midnight timer and Mama Moss's Wake meter
---------------------------------------------------------------------------------------------------

local phaseChip = create("Frame", {
	Name = "Phase",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(300, 44),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	Parent = hud,
})
corner(phaseChip)
local phaseStroke = outline(phaseChip, 2, COLORS.Amber)
local phaseLabel = label({ Text = "🌆 DUSK", TextSize = 22, Size = UDim2.fromScale(1, 1), Parent = phaseChip })

local wakeBar = create("Frame", {
	Name = "WakeMeter",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 58),
	Size = UDim2.fromOffset(300, 30),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	ClipsDescendants = true,
	Parent = hud,
})
corner(wakeBar, UDim.new(0, 10))
outline(wakeBar)
local wakeFill = create("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = COLORS.Good,
	BorderSizePixel = 0,
	Parent = wakeBar,
})
corner(wakeFill, UDim.new(0, 10))
local wakeLabel = label({
	Text = "😴 Mama Moss is asleep",
	TextSize = 16,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 2,
	Parent = wakeBar,
})

---------------------------------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------------------------------

local toastList = create("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(470, 200),
	BackgroundTransparency = 1,
	Parent = hud,
})
create("UIListLayout", {
	Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = toastList,
})
local toastOrder = 0

local function toast(text, style)
	toastOrder += 1
	local toastFrame = create("Frame", {
		Name = "Toast",
		LayoutOrder = toastOrder,
		Size = UDim2.fromOffset(470, 38),
		BackgroundColor3 = TOAST_COLORS[style] or TOAST_COLORS.info,
		BackgroundTransparency = 0.1,
		Parent = toastList,
	})
	corner(toastFrame, UDim.new(0, 12))
	local toastLabel = label({
		Text = text,
		TextSize = 17,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Parent = toastFrame,
	})

	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #toasts - 4 do
		toasts[index]:Destroy() -- keep the newest four
	end

	task.delay(3.4, function()
		if toastFrame.Parent then
			local fade = TweenInfo.new(0.4)
			TweenService:Create(toastFrame, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(toastLabel, fade, { TextTransparency = 1 }):Play()
			task.wait(0.45)
			toastFrame:Destroy()
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Bottom-centre status line, and the red screen edge while you are being chased
---------------------------------------------------------------------------------------------------

local statusChip = create("Frame", {
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(470, 44),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = hud,
})
corner(statusChip)
local statusStroke = outline(statusChip, 2, COLORS.Amber)
local statusLabel = label({
	Text = "",
	TextSize = 18,
	TextWrapped = true,
	Size = UDim2.new(1, -16, 1, 0),
	Position = UDim2.fromOffset(8, 0),
	Parent = statusChip,
})

local edges = {}
local edgeSpecs = {
	{ UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.16, 0), 90 },
	{ UDim2.new(0, 0, 0.84, 0), UDim2.new(1, 0, 0.16, 0), -90 },
	{ UDim2.fromScale(0, 0), UDim2.new(0.12, 0, 1, 0), 0 },
	{ UDim2.new(0.88, 0, 0, 0), UDim2.new(0.12, 0, 1, 0), 180 },
}
for _, spec in edgeSpecs do
	local edge = create("Frame", {
		Position = spec[1],
		Size = spec[2],
		BackgroundColor3 = COLORS.Danger,
		BorderSizePixel = 0,
		Visible = false,
		Parent = edgeGui,
	})
	create("UIGradient", {
		Rotation = spec[3],
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Parent = edge,
	})
	table.insert(edges, edge)
end

---------------------------------------------------------------------------------------------------
-- Action buttons
---------------------------------------------------------------------------------------------------

local actionButton = create("TextButton", {
	Name = "ActionButton",
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = COLORS.Amber,
	AutoButtonColor = true,
	Text = "",
	Visible = false,
	Parent = actionGui,
})
corner(actionButton, UDim.new(1, 0))
outline(actionButton, 3, COLORS.Outline)
local actionTitle = label({
	Text = "GRAB",
	TextSize = 26,
	TextColor3 = COLORS.Outline,
	Position = UDim2.fromScale(0, 0.18),
	Size = UDim2.fromScale(1, 0.4),
	Parent = actionButton,
})
actionTitle:FindFirstChildOfClass("UIStroke").Enabled = false
local actionSub = label({
	Text = "",
	Font = BODY_FONT,
	TextSize = 12,
	TextColor3 = COLORS.Outline,
	TextWrapped = true,
	Position = UDim2.fromScale(0.08, 0.56),
	Size = UDim2.fromScale(0.84, 0.26),
	Parent = actionButton,
})
actionSub:FindFirstChildOfClass("UIStroke").Enabled = false
local actionKey = label({
	Text = "E",
	TextSize = 16,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.85, 0.12),
	Size = UDim2.fromOffset(28, 28),
	BackgroundTransparency = 0,
	BackgroundColor3 = COLORS.Panel,
	Parent = actionButton,
})
corner(actionKey, UDim.new(1, 0))

local dropButton = create("TextButton", {
	Name = "DropButton",
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = COLORS.PanelLight,
	AutoButtonColor = true,
	Text = "",
	Visible = false,
	Parent = actionGui,
})
corner(dropButton, UDim.new(0, 16))
outline(dropButton, 2, COLORS.Amber)
local dropTitle = label({ Text = "DROP", TextSize = 20, Size = UDim2.fromScale(1, 1), Parent = dropButton })
local dropKey = label({
	Text = "Q",
	TextSize = 14,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(24, 24),
	BackgroundTransparency = 0,
	BackgroundColor3 = COLORS.Panel,
	Parent = dropButton,
})
corner(dropKey, UDim.new(1, 0))

local function layoutActionButtons()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local size, right, bottom
	if UserInputService.TouchEnabled then
		-- Roblox's jump button: 70 px at (w-95, h-90) on small screens, 120 px at (w-170, h-210) on
		-- large ones. Ours sits just to its left.
		if math.min(viewport.X, viewport.Y) <= 500 then
			size, right, bottom = 92, 105, 16
		else
			size, right, bottom = 128, 185, 86
		end
	else
		size, right, bottom = 118, 40, 40
	end
	actionButton.Size = UDim2.fromOffset(size, size)
	actionButton.Position = UDim2.new(1, -right, 1, -bottom)
	actionTitle.TextSize = math.floor(size * 0.24)
	actionSub.TextSize = math.max(11, math.floor(size * 0.11))

	local dropWidth, dropHeight = math.floor(size * 0.95), math.floor(size * 0.5)
	dropButton.Size = UDim2.fromOffset(dropWidth, dropHeight)
	dropButton.Position = UDim2.new(1, -right - math.floor((size - dropWidth) / 2), 1, -bottom - size - 10)
	dropTitle.TextSize = math.floor(dropHeight * 0.42)

	local keyboard = UserInputService.KeyboardEnabled
	actionKey.Visible = keyboard
	dropKey.Visible = keyboard

	hudScale.Scale = math.clamp(math.min(viewport.X / 960, viewport.Y / 540), 0.6, 1.35)
end

---------------------------------------------------------------------------------------------------
-- Hatch reveal
---------------------------------------------------------------------------------------------------

local revealCard = create("TextButton", {
	Name = "HatchReveal",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(310, 330),
	BackgroundColor3 = COLORS.Panel,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	ZIndex = 20,
	Parent = hud,
})
corner(revealCard, UDim.new(0, 22))
local revealStroke = outline(revealCard, 4, COLORS.Amber)
local revealScale = create("UIScale", { Parent = revealCard })
local revealTitle = label({
	Text = "HATCHING...",
	TextSize = 26,
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 34),
	ZIndex = 21,
	Parent = revealCard,
})
local revealViewport = create("ViewportFrame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.fromOffset(240, 170),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(170, 160, 190),
	LightColor = Color3.fromRGB(255, 245, 230),
	LightDirection = Vector3.new(0.3, -1, 0.6),
	ZIndex = 21,
	Parent = revealCard,
})
local revealCamera = create("Camera", { FieldOfView = 40, Parent = revealViewport })
revealViewport.CurrentCamera = revealCamera
local revealName = label({
	Text = "",
	TextSize = 30,
	Position = UDim2.fromOffset(0, 214),
	Size = UDim2.new(1, 0, 0, 36),
	ZIndex = 21,
	Parent = revealCard,
})
local revealRarity = label({
	Text = "",
	TextSize = 19,
	Position = UDim2.fromOffset(0, 248),
	Size = UDim2.new(1, 0, 0, 24),
	ZIndex = 21,
	Parent = revealCard,
})
local revealPerk = label({
	Text = "",
	Font = BODY_FONT,
	TextSize = 15,
	TextColor3 = COLORS.Muted,
	Position = UDim2.fromOffset(0, 274),
	Size = UDim2.new(1, 0, 0, 20),
	ZIndex = 21,
	Parent = revealCard,
})
local revealShells = label({
	Text = "",
	TextSize = 20,
	TextColor3 = COLORS.Amber,
	Position = UDim2.fromOffset(0, 296),
	Size = UDim2.new(1, 0, 0, 26),
	ZIndex = 21,
	Parent = revealCard,
})
local revealNew = label({
	Text = "NEW!",
	TextSize = 20,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -24, 0, 18),
	Size = UDim2.fromOffset(74, 32),
	Rotation = 14,
	BackgroundTransparency = 0,
	BackgroundColor3 = COLORS.Danger,
	ZIndex = 22,
	Visible = false,
	Parent = revealCard,
})
corner(revealNew, UDim.new(0, 10))
local revealFlash = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	ZIndex = 23,
	Parent = revealCard,
})
corner(revealFlash, UDim.new(0, 22))

local revealQueue = {}
local revealing = false
local skipReveal = false
revealCard.Activated:Connect(function()
	skipReveal = true
end)

local function waitSkippable(seconds)
	local start = os.clock()
	while os.clock() - start < seconds and not skipReveal do
		RunService.RenderStepped:Wait()
	end
end

local function playReveal(result)
	local pet = PetCatalog.Pets[result.PetId]
	if not pet then
		return
	end
	local tier = RarityTable.Get(pet.Rarity)
	local isMidnight = result.Variant == "Midnight"
	local accent = if isMidnight then RarityTable.MidnightColor else tier.Color
	skipReveal = false

	-- 1. the egg wobbles
	local eggKind = if GameConfig.Eggs[result.EggKind] then result.EggKind else "Pebble"
	local eggCfg = GameConfig.Eggs[eggKind]
	local egg = PetModels.BuildEgg(eggKind, isMidnight, math.random(1, 100000), false)
	egg.Parent = revealViewport
	revealCamera.CFrame = CFrame.lookAt(Vector3.new(0, eggCfg.Height * 0.1, -eggCfg.Height * 2.6), Vector3.zero)
	revealTitle.Text = if result.Helped then "SHARED HATCH!" else "HATCHING..."
	revealName.Text = ""
	revealRarity.Text = ""
	revealPerk.Text = ""
	revealShells.Text = ""
	revealNew.Visible = false
	revealStroke.Color = COLORS.Amber
	revealCard.Visible = true
	revealScale.Scale = 0.6
	TweenService:Create(revealScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local start = os.clock()
	while os.clock() - start < 0.9 and not skipReveal do
		local t = (os.clock() - start) / 0.9
		egg:PivotTo(CFrame.Angles(0, 0, math.sin(os.clock() * 38) * 0.28 * t))
		RunService.RenderStepped:Wait()
	end
	egg:Destroy()

	-- 2. flash, then the pet
	revealFlash.BackgroundTransparency = 0
	TweenService:Create(revealFlash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	local model = PetModels.BuildPet(result.PetId, result.Variant)
	if model then
		model.Parent = revealViewport
	end
	revealCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, -5.4), Vector3.zero)
	revealTitle.Text = if result.IsNew then "NEW PET!" else "YOU HATCHED"
	revealName.Text = if isMidnight then "🌙 " .. pet.Name else pet.Name
	revealName.TextColor3 = accent
	revealRarity.Text = pet.Rarity .. (if isMidnight then " · Midnight" else "")
	revealRarity.TextColor3 = accent
	revealPerk.Text = "Job: " .. PetCatalog.DescribePerk(result.PetId, result.Variant)
	revealShells.Text = ("+%s 🐚"):format(formatNumber(result.Shells or 0))
	revealNew.Visible = result.IsNew == true
	revealStroke.Color = accent
	skipReveal = false
	start = os.clock()
	while os.clock() - start < 2.6 and not skipReveal do
		if model then
			model:PivotTo(CFrame.Angles(0, math.sin((os.clock() - start) * 1.8) * 0.7, 0))
		end
		RunService.RenderStepped:Wait()
	end

	-- 3. out
	TweenService:Create(revealScale, TweenInfo.new(0.18), { Scale = 0.7 }):Play()
	waitSkippable(0.18)
	revealCard.Visible = false
	if model then
		model:Destroy()
	end
end

local function queueReveal(result)
	table.insert(revealQueue, result)
	if revealing then
		return
	end
	revealing = true
	task.spawn(function()
		while #revealQueue > 0 do
			local ok, err = pcall(playReveal, table.remove(revealQueue, 1))
			if not ok then
				warn("[MainUI] reveal failed: " .. tostring(err))
				revealCard.Visible = false
			end
		end
		revealing = false
	end)
end

---------------------------------------------------------------------------------------------------
-- Pets panel
---------------------------------------------------------------------------------------------------

local panel = create("Frame", {
	Name = "PetsPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 404),
	BackgroundColor3 = COLORS.Panel,
	Visible = false,
	ZIndex = 10,
	Parent = hud,
})
corner(panel, UDim.new(0, 22))
outline(panel, 3, COLORS.Amber)
label({
	Text = "🐾 MY PETS",
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(18, 8),
	Size = UDim2.fromOffset(300, 38),
	ZIndex = 11,
	Parent = panel,
})
local indexLabel = label({
	Text = "0/12 found",
	TextSize = 18,
	TextColor3 = COLORS.Amber,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(1, -240, 0, 12),
	Size = UDim2.fromOffset(170, 30),
	ZIndex = 11,
	Parent = panel,
})
label({
	Text = "Tap a pet to equip it. Every pet has a job, and 🌙 Midnight pets do it 50% better.",
	Font = BODY_FONT,
	TextSize = 13,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(18, 44),
	Size = UDim2.new(1, -36, 0, 18),
	ZIndex = 11,
	Parent = panel,
})
local closeButton = create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = COLORS.Danger,
	Text = "",
	ZIndex = 11,
	Parent = panel,
})
corner(closeButton, UDim.new(1, 0))
label({ Text = "✕", TextSize = 24, Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = closeButton })

local grid = create("Frame", {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.new(1, -32, 1, -84),
	BackgroundTransparency = 1,
	ZIndex = 11,
	Parent = panel,
})
create("UIGridLayout", {
	CellSize = UDim2.fromOffset(196, 156),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = grid,
})

local cards = {} -- [petId] = { Button, Stroke, Viewport, Name, Rarity, Info, Counts, Badge, ModelKey }

local function silhouette(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(14, 10, 22)
			part.Material = Enum.Material.SmoothPlastic
			part.Transparency = 0
		elseif part:IsA("ParticleEmitter") then
			part.Enabled = false
		end
	end
end

for order, petId in PetCatalog.Order do
	local pet = PetCatalog.Pets[petId]
	local button = create("TextButton", {
		Name = petId,
		LayoutOrder = order,
		BackgroundColor3 = COLORS.PanelLight,
		AutoButtonColor = true,
		Text = "",
		ZIndex = 12,
		Parent = grid,
	})
	corner(button, UDim.new(0, 16))
	local stroke = outline(button, 2, COLORS.Outline)
	local viewport = create("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(150, 80),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 160, 190),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(0.3, -1, 0.6),
		ZIndex = 13,
		Parent = button,
	})
	local camera = create("Camera", {
		FieldOfView = 40,
		CFrame = CFrame.lookAt(Vector3.new(1.6, 0.9, -4.4), Vector3.new(0, 0.1, 0)),
		Parent = viewport,
	})
	viewport.CurrentCamera = camera
	local nameLabel = label({
		Text = pet.Name,
		TextSize = 18,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 13,
		Parent = button,
	})
	local rarityLabel = label({
		Text = pet.Rarity,
		TextSize = 14,
		TextColor3 = RarityTable.Get(pet.Rarity).Color,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 13,
		Parent = button,
	})
	local infoLabel = label({
		Text = "",
		Font = BODY_FONT,
		TextSize = 12,
		TextColor3 = COLORS.Muted,
		TextWrapped = true,
		Position = UDim2.fromOffset(6, 116),
		Size = UDim2.new(1, -12, 0, 18),
		ZIndex = 13,
		Parent = button,
	})
	local countsLabel = label({
		Text = "",
		TextSize = 14,
		Position = UDim2.fromOffset(0, 134),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 13,
		Parent = button,
	})
	local badge = label({
		Text = "EQUIPPED",
		TextSize = 12,
		TextColor3 = COLORS.Outline,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(76, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = COLORS.Amber,
		ZIndex = 14,
		Visible = false,
		Parent = button,
	})
	badge:FindFirstChildOfClass("UIStroke").Enabled = false
	corner(badge, UDim.new(0, 8))

	button.Activated:Connect(function()
		local midnightKey = PetCatalog.Key(petId, "Midnight")
		local normalKey = PetCatalog.Key(petId, "Normal")
		local key = if (profile.Pets[midnightKey] or 0) > 0
			then midnightKey
			elseif (profile.Pets[normalKey] or 0) > 0 then normalKey
			else nil
		if key and key ~= profile.Equipped then
			ActionRemote:FireServer("Equip", key)
		end
	end)

	cards[petId] = {
		Stroke = stroke,
		Viewport = viewport,
		Name = nameLabel,
		Rarity = rarityLabel,
		Info = infoLabel,
		Counts = countsLabel,
		Badge = badge,
		ModelKey = nil,
	}
end

local function refreshPanel()
	local found = 0
	for _, petId in PetCatalog.Order do
		local card = cards[petId]
		local pet = PetCatalog.Pets[petId]
		local normal = profile.Pets[PetCatalog.Key(petId, "Normal")] or 0
		local midnight = profile.Pets[PetCatalog.Key(petId, "Midnight")] or 0
		found += (if normal > 0 then 1 else 0) + (if midnight > 0 then 1 else 0)
		local owned = normal + midnight > 0
		local bestVariant = if midnight > 0 then "Midnight" else "Normal"

		local modelKey = if owned then bestVariant else "Locked"
		if card.ModelKey ~= modelKey then
			card.ModelKey = modelKey
			card.Viewport:ClearAllChildren()
			local camera = create("Camera", {
				FieldOfView = 40,
				CFrame = CFrame.lookAt(Vector3.new(1.6, 0.9, -4.4), Vector3.new(0, 0.1, 0)),
				Parent = card.Viewport,
			})
			card.Viewport.CurrentCamera = camera
			local model = PetModels.BuildPet(petId, if owned then bestVariant else "Normal")
			if model then
				if not owned then
					silhouette(model)
				end
				model.Parent = card.Viewport
			end
		end

		if owned then
			card.Name.Text = pet.Name
			card.Info.Text = "Job: " .. PetCatalog.DescribePerk(petId, bestVariant)
			card.Counts.Text = ("x%d   🌙 x%d"):format(normal, midnight)
		else
			card.Name.Text = "???"
			card.Info.Text = "Found in: " .. table.concat(PetCatalog.FoundIn(petId), ", ")
			card.Counts.Text = "LOCKED"
		end
		local equippedId = PetCatalog.ParseKey(profile.Equipped)
		local equipped = equippedId == petId
		card.Badge.Visible = equipped
		card.Stroke.Color = if equipped then COLORS.Amber else COLORS.Outline
		card.Stroke.Thickness = if equipped then 3 else 2
	end
	indexLabel.Text = ("%d/%d found"):format(found, #PetCatalog.Order * #PetCatalog.Variants)
end

local function setPanelOpen(open)
	panel.Visible = open
	if open then
		petsDot.Visible = false
		refreshPanel()
	end
end

petsButton.Activated:Connect(function()
	setPanelOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setPanelOpen(false)
end)

---------------------------------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------------------------------

local function applyProfile(snapshot)
	if typeof(snapshot) ~= "table" then
		return
	end
	local previousShells = profile.Shells
	profile.Shells = snapshot.Shells or 0
	profile.Pets = snapshot.Pets or {}
	profile.Equipped = snapshot.Equipped or ""
	profile.Stats = snapshot.Stats or profile.Stats
	shellsLabel.Text = formatNumber(profile.Shells)
	if profile.Shells > previousShells then
		shellsPop.Scale = 1.18
		TweenService:Create(shellsPop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if panel.Visible then
		refreshPanel()
	end
end

ProfileRemote.OnClientEvent:Connect(applyProfile)
NotifyRemote.OnClientEvent:Connect(function(text, style)
	if typeof(text) == "string" then
		toast(text, style)
	end
end)
HatchedRemote.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		return
	end
	if result.IsNew then
		petsDot.Visible = not panel.Visible
	end
	if (profile.Stats.Hatched or 0) <= 1 then
		firstHatchHintUntil = os.clock() + 9
	end
	queueReveal(result)
end)

local GUARDIAN_TEXT = {
	Waking = "😾 MAMA MOSS IS WAKING UP!",
	Hunting = "😾 MAMA MOSS IS AWAKE!",
	Gloating = "😾 MAMA MOSS IS AWAKE!",
	Panting = "😮‍💨 Mama Moss is out of breath!",
	Returning = "🥱 Mama Moss is heading home...",
	Patrolling = "🌕 Mama Moss is on the prowl!",
}

local function updateTopBar()
	local phase = ReplicatedStorage:GetAttribute("MH_Phase") or "Dusk"
	local endsAt = ReplicatedStorage:GetAttribute("MH_PhaseEndsAt") or 0
	local left = formatTime(endsAt - workspace:GetServerTimeNow())
	if phase == "Midnight" then
		phaseLabel.Text = "🌕 MIDNIGHT! " .. left
		phaseChip.BackgroundColor3 = Color3.fromRGB(62, 40, 130)
		phaseStroke.Color = COLORS.Midnight
	else
		phaseLabel.Text = "🌆 Midnight in " .. left
		phaseChip.BackgroundColor3 = COLORS.Panel
		phaseStroke.Color = COLORS.Amber
	end

	local state = ReplicatedStorage:GetAttribute("MH_GuardianState") or "Sleeping"
	local noise = ReplicatedStorage:GetAttribute("MH_GuardianNoise") or 0
	if state == "Sleeping" then
		local fraction = math.clamp(noise / GameConfig.Guardian.WakeThreshold, 0, 1)
		wakeFill.Size = UDim2.fromScale(fraction, 1)
		wakeFill.BackgroundColor3 = COLORS.Good:Lerp(COLORS.Danger, fraction)
		wakeLabel.Text = if fraction >= 0.6 then "😟 Mama Moss is stirring..." else "😴 Mama Moss is asleep"
	else
		wakeFill.Size = UDim2.fromScale(1, 1)
		local calm = state == "Returning" or state == "Panting"
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
		wakeFill.BackgroundColor3 = if calm then COLORS.Amber else COLORS.Danger:Lerp(COLORS.Amber, pulse * 0.4)
		wakeLabel.Text = GUARDIAN_TEXT[state] or "😾 MAMA MOSS IS AWAKE!"
	end
end

local currentTarget = nil
local lastPress = 0

local function findTarget(root)
	if (player:GetAttribute("MH_Carrying") or 0) ~= 0 or (player:GetAttribute("MH_Helping") or 0) ~= 0 then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	local best, bestDistance = nil, math.huge
	for _, model in eggFolder:GetChildren() do
		local shell = model.PrimaryPart
		local kind = model:GetAttribute("Kind")
		local cfg = if kind then GameConfig.Eggs[kind] else nil
		if not shell or not cfg then
			continue
		end
		local state = model:GetAttribute("State")
		local distance = (shell.Position - root.Position).Magnitude
		if distance >= bestDistance then
			continue
		end
		if state == "Nest" or state == "Dropped" then
			local unlocked = (model:GetAttribute("LockedUntil") or 0) <= now
			if unlocked and distance <= GameConfig.Player.GrabRange + cfg.Height / 2 then
				best, bestDistance =
					{
						Kind = "Grab",
						EggId = model:GetAttribute("EggId"),
						EggKind = kind,
						Midnight = model:GetAttribute("Midnight") == true,
					}, distance
			end
		elseif state == "Carried" and kind == "Giant" and model:GetAttribute("CarrierId") ~= player.UserId then
			local helpers = model:GetAttribute("HelperCount") or 0
			local inReach = distance <= GameConfig.Player.HelpRange + cfg.Height / 2 + 3
			if inReach and helpers < GameConfig.GiantCarry.MaxHelpers then
				best, bestDistance =
					{
						Kind = "Help",
						EggId = model:GetAttribute("EggId"),
						EggKind = kind,
						Helpers = helpers,
					}, distance
			end
		end
	end
	return best
end

local function updateActionButtons()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local carrying = (player:GetAttribute("MH_Carrying") or 0) ~= 0
	local helping = (player:GetAttribute("MH_Helping") or 0) ~= 0
	currentTarget = if root then findTarget(root) else nil

	if currentTarget then
		local cfg = GameConfig.Eggs[currentTarget.EggKind]
		if currentTarget.Kind == "Help" then
			actionTitle.Text = "HELP"
			actionSub.Text = ("Giant Egg %d/%d"):format(currentTarget.Helpers, GameConfig.GiantCarry.MaxHelpers)
			actionButton.BackgroundColor3 = COLORS.Good
		else
			actionTitle.Text = "GRAB"
			actionSub.Text = (if currentTarget.Midnight then "🌙 " else "") .. cfg.DisplayName
			actionButton.BackgroundColor3 = if currentTarget.Midnight then COLORS.Midnight else COLORS.Amber
		end
	end
	actionButton.Visible = currentTarget ~= nil
	dropButton.Visible = carrying or helping
	dropTitle.Text = if helping then "LET GO" else "DROP"
end

local function updateStatus()
	local chased = ReplicatedStorage:GetAttribute("MH_GuardianTarget") == player.UserId
	local stunned = player:GetAttribute("MH_Stunned") == true
	local carryKind = player:GetAttribute("MH_CarryKind") or ""
	local helping = (player:GetAttribute("MH_Helping") or 0) ~= 0

	local text, color = nil, COLORS.Amber
	if stunned then
		text, color = "💫 Dizzy! Shake it off...", COLORS.Muted
	elseif chased then
		text, color = "😱 RUN! Mama Moss is chasing YOU!", COLORS.Danger
	elseif carryKind == "Giant" then
		local helpers = 0
		local eggId = player:GetAttribute("MH_Carrying")
		for _, model in eggFolder:GetChildren() do
			if model:GetAttribute("EggId") == eggId then
				helpers = model:GetAttribute("HelperCount") or 0
				break
			end
		end
		text = ("🥚 GIANT egg! Friends can tap HELP to carry it faster (%d/%d)"):format(
			helpers,
			GameConfig.GiantCarry.MaxHelpers
		)
	elseif carryKind ~= "" then
		text = "🥚 " .. GameConfig.Eggs[carryKind].DisplayName .. ": run it back to the 🏠 Hatchery!"
	elseif helping then
		text, color = "👥 Helping carry the Giant egg: stay close to share the hatch!", COLORS.Good
	elseif os.clock() < firstHatchHintUntil then
		text, color = "🐾 Your pet follows you and has a job! Tap PETS to see it.", COLORS.Good
	elseif (profile.Stats.Hatched or 0) == 0 then
		text = "🥚 Grab an egg (try the small ones on the trail) and bring it to the 🏠 Hatchery!"
	end

	statusChip.Visible = text ~= nil
	if text then
		statusLabel.Text = text
		statusStroke.Color = color
	end

	local pulse = 0.25 + 0.15 * math.sin(os.clock() * 7)
	for _, edge in edges do
		edge.Visible = chased
		edge.BackgroundTransparency = pulse
	end
end

---------------------------------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------------------------------

local function pressAction()
	if os.clock() - lastPress < 0.25 or not currentTarget then
		return
	end
	lastPress = os.clock()
	ActionRemote:FireServer("Grab", currentTarget.EggId)
end

local function pressDrop()
	if os.clock() - lastPress < 0.25 then
		return
	end
	lastPress = os.clock()
	ActionRemote:FireServer("Drop")
end

actionButton.Activated:Connect(pressAction)
dropButton.Activated:Connect(pressDrop)

ContextActionService:BindAction("MH_Action", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if currentTarget then
		pressAction()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

ContextActionService:BindAction("MH_Drop", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if dropButton.Visible then
		pressDrop()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

-- Studio-only test keys (the server ignores these outside Studio).
if RunService:IsStudio() then
	local debugKeys = {
		[Enum.KeyCode.F6] = "Midnight",
		[Enum.KeyCode.F7] = "Dusk",
		[Enum.KeyCode.F8] = "Wake",
		[Enum.KeyCode.F9] = "Shells",
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		local command = debugKeys[input.KeyCode]
		if command and not processed then
			ActionRemote:FireServer("Debug", command)
			toast("[Studio] " .. command, "info")
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------

local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutActionButtons)
	end
	layoutActionButtons()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
UserInputService.LastInputTypeChanged:Connect(layoutActionButtons)

task.spawn(function()
	while true do
		local ok, err = pcall(function()
			updateActionButtons()
			updateStatus()
			updateTopBar()
		end)
		if not ok then
			warn("[MainUI] " .. tostring(err))
		end
		task.wait(0.1)
	end
end)

ActionRemote:FireServer("Sync") -- in case the first snapshot arrived before this script ran
