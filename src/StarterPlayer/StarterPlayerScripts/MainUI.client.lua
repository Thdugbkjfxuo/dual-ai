-- MAIN UI
-- Builds the entire interface in code: HUD currency display, bottom nav bar,
-- and four toggleable panels (Inventory, Shop, Index, Battle Pass), plus the
-- egg hatch reveal popup. Nothing here needs to be manually built in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RarityTable = require(ReplicatedStorage.Modules.RarityTable)
local HatchEgg = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("HatchEgg")

-- ============ ROOT SCREEN GUI ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ============ HUD: currency counter, top-left ============
local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.new(0, 220, 0, 50)
hud.Position = UDim2.new(0, 12, 0, 12)
hud.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
hud.BackgroundTransparency = 0.2
hud.Parent = screenGui

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 10)
hudCorner.Parent = hud

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.Size = UDim2.new(1, -20, 1, 0)
moneyLabel.Position = UDim2.new(0, 10, 0, 0)
moneyLabel.BackgroundTransparency = 1
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.TextSize = 22
moneyLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Text = "$0"
moneyLabel.Parent = hud

local function updateMoney()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild("Money")
		if money then
			moneyLabel.Text = "$" .. tostring(money.Value)
			money:GetPropertyChangedSignal("Value"):Connect(function()
				moneyLabel.Text = "$" .. tostring(money.Value)
			end)
		end
	end
end

if player:FindFirstChild("leaderstats") then
	updateMoney()
else
	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			updateMoney()
		end
	end)
end

-- ============ BOTTOM NAV BAR ============
local navBar = Instance.new("Frame")
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 420, 0, 60)
navBar.Position = UDim2.new(0.5, -210, 1, -75)
navBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
navBar.BackgroundTransparency = 0.2
navBar.Parent = screenGui

local navCorner = Instance.new("UICorner")
navCorner.CornerRadius = UDim.new(0, 12)
navCorner.Parent = navBar

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = navBar

local panels = {}

local function createNavButton(name, label)
	local button = Instance.new("TextButton")
	button.Name = name .. "Button"
	button.Size = UDim2.new(0, 95, 0, 46)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = label
	button.Parent = navBar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		for otherName, panel in pairs(panels) do
			panel.Visible = (otherName == name)
		end
	end)

	return button
end

-- ============ GENERIC PANEL BUILDER ============
local function createPanel(name, title)
	local panel = Instance.new("Frame")
	panel.Name = name .. "Panel"
	panel.Size = UDim2.new(0, 500, 0, 400)
	panel.Position = UDim2.new(0.5, -250, 0.5, -230)
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	panel.Visible = false
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -50, 0, 40)
	titleLabel.Position = UDim2.new(0, 20, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 24
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = title
	titleLabel.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -40, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -30, 1, -70)
	scrollFrame.Position = UDim2.new(0, 15, 0, 60)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = scrollFrame

	panels[name] = panel
	return panel, scrollFrame
end

local function createRow(parent, text, subtext)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 50)
	row.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	row.Parent = parent

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 8)
	rowCorner.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = row

	if subtext then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.4, -12, 1, 0)
		sub.Position = UDim2.new(0.6, 0, 0, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 14
		sub.TextColor3 = Color3.fromRGB(200, 200, 200)
		sub.TextXAlignment = Enum.TextXAlignment.Right
		sub.Text = subtext
		sub.Parent = row
	end

	return row
end

-- ============ INVENTORY PANEL ============
createNavButton("Inventory", "Pets")
local invPanel, invScroll = createPanel("Inventory", "My Pets")
createRow(invScroll, "No pets yet", "Go hatch an egg!")

-- ============ SHOP PANEL (7 booths) ============
createNavButton("Shop", "Shop")
local shopPanel, shopScroll = createPanel("Shop", "Shop")
local shopBooths = {
	"Egg Shop — rotating eggs, limited stock",
	"Treats / Mutation Shop",
	"Potion Shop — Speed & Money potions",
	"Storage Shop — pet & egg slots",
	"Everyday Cosmetics",
	"Premium Cosmetics (weekly, Robux)",
	"Cosmetic Crates",
}
for _, booth in ipairs(shopBooths) do
	createRow(shopScroll, booth)
end

-- ============ INDEX PANEL (rarity tiers) ============
createNavButton("Index", "Index")
local indexPanel, indexScroll = createPanel("Index", "Pet Index")
for _, entry in ipairs(RarityTable.Weights) do
	local row = createRow(indexScroll, entry.Name .. " — ???", "Locked")
	row.BackgroundColor3 = entry.Color
	row.BackgroundTransparency = 0.7
end

-- ============ BATTLE PASS PANEL ============
createNavButton("BattlePass", "Pass")
local passPanel, passScroll = createPanel("BattlePass", "Battle Pass — Level 1")
for level = 1, 30 do
	createRow(passScroll, "Level " .. level, level % 5 == 0 and "Milestone" or "Reward")
end

-- ============ EGG HATCH REVEAL POPUP ============
local hatchPopup = Instance.new("Frame")
hatchPopup.Name = "HatchPopup"
hatchPopup.Size = UDim2.new(0, 320, 0, 100)
hatchPopup.Position = UDim2.new(0.5, -160, 0.3, 0)
hatchPopup.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
hatchPopup.BackgroundTransparency = 1
hatchPopup.Visible = false
hatchPopup.ZIndex = 10
hatchPopup.Parent = screenGui

local hatchCorner = Instance.new("UICorner")
hatchCorner.CornerRadius = UDim.new(0, 14)
hatchCorner.Parent = hatchPopup

local hatchLabel = Instance.new("TextLabel")
hatchLabel.Size = UDim2.new(1, 0, 1, 0)
hatchLabel.BackgroundTransparency = 1
hatchLabel.Font = Enum.Font.GothamBlack
hatchLabel.TextSize = 28
hatchLabel.TextTransparency = 1
hatchLabel.ZIndex = 11
hatchLabel.Text = ""
hatchLabel.Parent = hatchPopup

HatchEgg.OnClientEvent:Connect(function(rarity)
	local entry = RarityTable.GetEntry(rarity)
	local color = entry and entry.Color or Color3.new(1, 1, 1)
	local value = entry and entry.Value or 0

	hatchLabel.Text = "You hatched a\n" .. rarity .. "! (+$" .. value .. ")"
	hatchLabel.TextColor3 = color
	hatchPopup.Visible = true
	hatchPopup.BackgroundTransparency = 1
	hatchLabel.TextTransparency = 1

	local fadeIn = TweenService:Create(hatchPopup, TweenInfo.new(0.25), {BackgroundTransparency = 0.15})
	local textIn = TweenService:Create(hatchLabel, TweenInfo.new(0.25), {TextTransparency = 0})
	fadeIn:Play()
	textIn:Play()

	task.wait(2)

	local fadeOut = TweenService:Create(hatchPopup, TweenInfo.new(0.5), {BackgroundTransparency = 1})
	local textOut = TweenService:Create(hatchLabel, TweenInfo.new(0.5), {TextTransparency = 1})
	fadeOut:Play()
	textOut:Play()
	fadeOut.Completed:Wait()
	hatchPopup.Visible = false
end)
