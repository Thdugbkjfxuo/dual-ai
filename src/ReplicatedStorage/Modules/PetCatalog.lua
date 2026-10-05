-- PetCatalog
-- The six Midnight Hatch creatures. Every pet has a job: equip one and it follows you and changes how
-- you run. Pets only come from play (never sold), so a perk is never pay-to-win.

local GameConfig = require(script.Parent.GameConfig)

local PetCatalog = {}

PetCatalog.Order = { "ToastMoth", "Socktopus", "Marshmole", "Pumpkit", "Moonbean", "Wispurr" }
PetCatalog.Variants = { "Normal", "Midnight" }

-- Perk kinds: Quiet (less noise), Carry (faster with an egg), Shells (more Shells per hatch),
-- Swift (faster without an egg). Amount is a fraction: 0.10 = 10%.
PetCatalog.Pets = {
	ToastMoth = {
		Name = "Toast Moth",
		Rarity = "Common",
		Flies = true,
		Perk = "Quiet",
		Amount = 0.10,
		Flavor = "Crunchy wings. Very sneaky.",
	},
	Socktopus = {
		Name = "Socktopus",
		Rarity = "Common",
		Flies = false,
		Perk = "Carry",
		Amount = 0.06,
		Flavor = "Eight arms, zero matching socks.",
	},
	Marshmole = {
		Name = "Marshmole",
		Rarity = "Uncommon",
		Flies = false,
		Perk = "Shells",
		Amount = 0.15,
		Flavor = "Digs up shells. Slightly sticky.",
	},
	Pumpkit = {
		Name = "Pumpkit",
		Rarity = "Rare",
		Flies = false,
		Perk = "Swift",
		Amount = 0.07,
		Flavor = "A pumpkin that zooms.",
	},
	Moonbean = {
		Name = "Moonbean",
		Rarity = "Epic",
		Flies = true,
		Perk = "Shells",
		Amount = 0.35,
		Flavor = "Glows when it is happy. It is always happy.",
	},
	Wispurr = {
		Name = "Wispurr",
		Rarity = "Legendary",
		Flies = true,
		Perk = "Carry",
		Amount = 0.15,
		Flavor = "A ghost cat that purrs in whispers.",
	},
}

PetCatalog.PerkText = {
	Quiet = "%d%% quieter",
	Carry = "+%d%% carry speed",
	Shells = "+%d%% Shells",
	Swift = "+%d%% run speed",
}

function PetCatalog.Key(petId, variant)
	return petId .. ":" .. variant
end

-- Validates a key such as "Moonbean:Midnight". Returns petId, variant or nil.
function PetCatalog.ParseKey(key)
	if typeof(key) ~= "string" or #key > 40 then
		return nil
	end
	local petId, variant = string.match(key, "^(%w+):(%w+)$")
	if not petId or not PetCatalog.Pets[petId] then
		return nil
	end
	if variant ~= "Normal" and variant ~= "Midnight" then
		return nil
	end
	return petId, variant
end

-- Returns perkKind, amount for a pet, with the Midnight bonus applied.
function PetCatalog.GetPerk(petId, variant)
	local pet = PetCatalog.Pets[petId]
	if not pet then
		return nil, 0
	end
	local multiplier = if variant == "Midnight" then GameConfig.Variants.MidnightPerkMultiplier else 1
	return pet.Perk, pet.Amount * multiplier
end

function PetCatalog.DescribePerk(petId, variant)
	local kind, amount = PetCatalog.GetPerk(petId, variant)
	if not kind then
		return ""
	end
	return string.format(PetCatalog.PerkText[kind], math.floor(amount * 100 + 0.5))
end

-- Display names of the eggs that can hatch this pet, e.g. { "Pebble Egg", "Moss Egg" }.
function PetCatalog.FoundIn(petId)
	local names = {}
	for _, kind in GameConfig.EggOrder do
		for _, entry in GameConfig.Eggs[kind].Odds do
			if entry.Id == petId and entry.Weight > 0 then
				table.insert(names, GameConfig.Eggs[kind].DisplayName)
				break
			end
		end
	end
	return names
end

return PetCatalog
