-- REQUIRES (create manually in Studio, Rojo doesn't sync these instance types by default):
--   ReplicatedStorage > RemoteEvents (Folder) > HatchEgg (RemoteEvent)
--   workspace > Egg (Part) with a ProximityPrompt child
--     ActionText = "Grab", ObjectText = "Egg", HoldDuration = 0.5, MaxActivationDistance = 6

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityTable = require(ReplicatedStorage.Modules.RarityTable)
local HatchEgg = ReplicatedStorage.RemoteEvents.HatchEgg

local egg = workspace:WaitForChild("Egg")
local prompt = egg:WaitForChild("ProximityPrompt")

prompt.Triggered:Connect(function(player)
	local rarity = RarityTable.RollRarity()
	local entry = RarityTable.GetEntry(rarity)
	print(player.Name .. " hatched a " .. rarity .. " pet!")

	-- grant currency reward
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild("Money")
		if money and entry then
			money.Value = money.Value + entry.Value
		end
	end

	HatchEgg:FireClient(player, rarity)
end)
