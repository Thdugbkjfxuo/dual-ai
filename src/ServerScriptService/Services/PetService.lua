-- PetService
-- Equipping pets and reading their perks. The equipped pet is stored in the player's profile and
-- mirrored to the MH_Pet player attribute, which every client reads to draw the pet following them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetCatalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetCatalog"))

local PetService = {}

local deps -- { Data = PlayerDataService, OnEquipChanged = function(player) }

-- The equipped pet's bonus for one perk kind ("Quiet" | "Carry" | "Shells" | "Swift"), or 0.
function PetService.GetPerk(player, kind)
	local profile = deps.Data.Get(player)
	if not profile or profile.Equipped == "" then
		return 0
	end
	local petId, variant = PetCatalog.ParseKey(profile.Equipped)
	if not petId then
		return 0
	end
	local perkKind, amount = PetCatalog.GetPerk(petId, variant)
	return if perkKind == kind then amount else 0
end

-- Re-applies the profile's equipped pet to the player attribute and movement speed.
function PetService.Apply(player)
	local profile = deps.Data.Get(player)
	player:SetAttribute("MH_Pet", if profile then profile.Equipped else "")
	deps.OnEquipChanged(player)
end

-- Action "Equip": payload is a pet key such as "Moonbean:Midnight" the player owns.
function PetService.HandleEquip(player, key)
	if not PetCatalog.ParseKey(key) then
		return
	end
	if not deps.Data.SetEquipped(player, key) then
		return
	end
	PetService.Apply(player)
	deps.Data.Sync(player)
end

function PetService.Init(dependencies)
	deps = dependencies
	-- PlayerDataService connected first, so the profile exists by the time this runs.
	Players.PlayerAdded:Connect(PetService.Apply)
	for _, player in Players:GetPlayers() do
		PetService.Apply(player)
	end
end

return PetService
