local RarityTable = {}

-- Weighted odds, must sum to 100. Value = base currency reward on hatch.
RarityTable.Weights = {
	{Name = "Common", Weight = 45, Value = 5, Color = Color3.fromRGB(200, 200, 200)},
	{Name = "Uncommon", Weight = 25, Value = 15, Color = Color3.fromRGB(120, 220, 120)},
	{Name = "Rare", Weight = 15, Value = 40, Color = Color3.fromRGB(90, 160, 255)},
	{Name = "Epic", Weight = 9, Value = 100, Color = Color3.fromRGB(180, 90, 255)},
	{Name = "Legendary", Weight = 4.5, Value = 300, Color = Color3.fromRGB(255, 180, 40)},
	{Name = "Mythic", Weight = 1.4, Value = 1000, Color = Color3.fromRGB(255, 80, 80)},
	{Name = "Secret", Weight = 0.05, Value = 5000, Color = Color3.fromRGB(40, 40, 40)},
	{Name = "Cosmic", Weight = 0.04, Value = 15000, Color = Color3.fromRGB(150, 60, 220)},
	{Name = "Eternal", Weight = 0.01, Value = 50000, Color = Color3.fromRGB(255, 240, 150)},
}

function RarityTable.GetEntry(name)
	for _, entry in ipairs(RarityTable.Weights) do
		if entry.Name == name then
			return entry
		end
	end
	return nil
end

function RarityTable.RollRarity()
	local roll = math.random() * 100
	local cumulative = 0
	for _, entry in ipairs(RarityTable.Weights) do
		cumulative = cumulative + entry.Weight
		if roll <= cumulative then
			return entry.Name
		end
	end
	return RarityTable.Weights[1].Name -- fallback
end

return RarityTable
