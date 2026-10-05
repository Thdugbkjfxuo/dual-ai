-- Sets up the Money stat every player needs. This also shows up automatically
-- in Roblox's built-in leaderboard (top-right player list) for free.

local Players = game:GetService("Players")

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = 0
	money.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)
