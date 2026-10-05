-- PlayerDataService
-- Each player's Shells, pets and stats. Replaces the prototype's Currency script.
-- Round 1 keeps profiles in memory only (they reset when you leave). Round 2 swaps the inside of
-- this module for a session-locked DataStore; the functions other services call stay the same.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetCatalog = require(Modules.PetCatalog)
local Net = require(Modules.Net)

local PlayerDataService = {}

local profiles = {} -- [Player] = profile
local profileSync

local function newProfile()
	return {
		Shells = 0,
		Pets = {}, -- [petKey] = count, e.g. ["Socktopus:Normal"] = 2
		Equipped = "", -- petKey or ""
		Stats = { Banked = 0, Hatched = 0 },
	}
end

local function makeLeaderstats(player, profile)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local shells = Instance.new("IntValue")
	shells.Name = "Shells"
	shells.Value = profile.Shells
	shells.Parent = folder
	local hatched = Instance.new("IntValue")
	hatched.Name = "Hatched"
	hatched.Value = profile.Stats.Hatched
	hatched.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player, profile)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local shells = folder:FindFirstChild("Shells")
	if shells then
		shells.Value = profile.Shells
	end
	local hatched = folder:FindFirstChild("Hatched")
	if hatched then
		hatched.Value = profile.Stats.Hatched
	end
end

function PlayerDataService.Get(player)
	return profiles[player]
end

-- Sends the player their own snapshot (the pets panel and HUD read it).
function PlayerDataService.Sync(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	updateLeaderstats(player, profile)
	profileSync:FireClient(player, {
		Shells = profile.Shells,
		Pets = profile.Pets,
		Equipped = profile.Equipped,
		Stats = profile.Stats,
	})
end

function PlayerDataService.AddShells(player, amount)
	local profile = profiles[player]
	if not profile or typeof(amount) ~= "number" or amount ~= amount then
		return
	end
	profile.Shells = math.max(0, math.floor(profile.Shells + amount))
end

function PlayerDataService.AddStat(player, name, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Stats[name] = (profile.Stats[name] or 0) + amount
end

-- Returns isNew (first copy of this pet + variant), autoEquipped (it became the equipped pet).
function PlayerDataService.AddPet(player, petId, variant)
	local profile = profiles[player]
	if not profile or not PetCatalog.Pets[petId] then
		return false, false
	end
	local key = PetCatalog.Key(petId, variant)
	local count = (profile.Pets[key] or 0) + 1
	profile.Pets[key] = count
	local autoEquipped = false
	if profile.Equipped == "" then
		profile.Equipped = key
		autoEquipped = true
	end
	return count == 1, autoEquipped
end

function PlayerDataService.Owns(player, key)
	local profile = profiles[player]
	return profile ~= nil and (profile.Pets[key] or 0) > 0
end

function PlayerDataService.SetEquipped(player, key)
	local profile = profiles[player]
	if not profile or not PlayerDataService.Owns(player, key) then
		return false
	end
	profile.Equipped = key
	return true
end

local function onPlayerAdded(player)
	if profiles[player] then
		return
	end
	local profile = newProfile()
	profiles[player] = profile
	makeLeaderstats(player, profile)
	PlayerDataService.Sync(player)
end

function PlayerDataService.Init()
	profileSync = Net.Get("ProfileSync")
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerDataService
