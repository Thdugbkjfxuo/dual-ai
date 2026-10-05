-- RarityTable
-- Rarity tiers (colour, rank) and the weighted roll every egg uses.
-- Round 1: five tiers plus the Midnight variant replace the prototype's nine tiers. With six creatures,
-- nine tiers (down to a 0.01% "Eternal") would mostly be empty labels; five read clearly on a phone.

local RarityTable = {}

RarityTable.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

RarityTable.Tiers = {
	Common = { Rank = 1, Color = Color3.fromRGB(205, 205, 205) },
	Uncommon = { Rank = 2, Color = Color3.fromRGB(120, 220, 120) },
	Rare = { Rank = 3, Color = Color3.fromRGB(90, 160, 255) },
	Epic = { Rank = 4, Color = Color3.fromRGB(190, 100, 255) },
	Legendary = { Rank = 5, Color = Color3.fromRGB(255, 185, 45) },
}

RarityTable.MidnightColor = Color3.fromRGB(165, 125, 255)

function RarityTable.Get(name)
	return RarityTable.Tiers[name] or RarityTable.Tiers.Common
end

-- odds: array of { Id = string, Weight = number }. rng: a Random object (the server passes its own).
-- Returns the chosen Id, or nil when no entry has a positive weight.
function RarityTable.Roll(odds, rng)
	local total = 0
	for _, entry in odds do
		if entry.Weight > 0 then
			total += entry.Weight
		end
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber() * total
	local last = nil
	for _, entry in odds do
		if entry.Weight > 0 then
			last = entry.Id
			roll -= entry.Weight
			if roll < 0 then
				return entry.Id
			end
		end
	end
	return last -- floating-point edge: roll landed exactly on the total
end

-- Percent chance (0-100) of one Id in an odds table.
function RarityTable.Percent(odds, id)
	local total, weight = 0, 0
	for _, entry in odds do
		if entry.Weight > 0 then
			total += entry.Weight
			if entry.Id == id then
				weight += entry.Weight
			end
		end
	end
	if total <= 0 then
		return 0
	end
	return weight / total * 100
end

return RarityTable
