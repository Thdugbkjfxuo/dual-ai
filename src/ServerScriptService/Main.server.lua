-- Main
-- Starts every server service in order and routes client requests.
-- Replaces the prototype's separate Currency / EggSystem / MapGenerator / PlotManager scripts:
-- one entry point means the map exists before eggs spawn and the guardian wakes up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local PetCatalog = require(Modules.PetCatalog)
local RarityTable = require(Modules.RarityTable)
local Net = require(Modules.Net) -- creates the RemoteEvents

local Services = script.Parent:WaitForChild("Services")
local MapService = require(Services.MapService)
local PlayerDataService = require(Services.PlayerDataService)
local CycleService = require(Services.CycleService)
local PetService = require(Services.PetService)
local GuardianService = require(Services.GuardianService)
local EggService = require(Services.EggService)

-- Config sanity: every egg's odds must name real pets and add up to 100.
for _, kind in GameConfig.EggOrder do
	local total = 0
	for _, entry in GameConfig.Eggs[kind].Odds do
		total += entry.Weight
		if not PetCatalog.Pets[entry.Id] then
			warn(("[Main] %s egg lists unknown pet %s"):format(kind, tostring(entry.Id)))
		end
	end
	if math.abs(total - 100) > 0.001 then
		warn(("[Main] %s egg odds add up to %s, not 100"):format(kind, tostring(total)))
	end
end
for petId, pet in PetCatalog.Pets do
	if not RarityTable.Tiers[pet.Rarity] then
		warn(("[Main] %s has unknown rarity %s"):format(petId, tostring(pet.Rarity)))
	end
end

MapService.Init()
PlayerDataService.Init()
CycleService.Init()
PetService.Init({
	Data = PlayerDataService,
	OnEquipChanged = function(player)
		EggService.RefreshSpeed(player)
	end,
})
GuardianService.Init({ Map = MapService, Cycle = CycleService, Eggs = EggService })
EggService.Init({
	Map = MapService,
	Guardian = GuardianService,
	Data = PlayerDataService,
	Pets = PetService,
	Cycle = CycleService,
})
CycleService.Start()

---------------------------------------------------------------------------------------------------
-- Client requests: Action(name, payload). Each player gets a small token bucket.
---------------------------------------------------------------------------------------------------

local SECURITY = GameConfig.Security
local buckets = {} -- [Player] = { Tokens, Updated }

local function allow(player)
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = SECURITY.ActionBurst, Updated = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(SECURITY.ActionBurst, bucket.Tokens + (now - bucket.Updated) * SECURITY.ActionsPerSecond)
	bucket.Updated = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local handlers = {
	Grab = EggService.HandleGrab,
	Drop = EggService.HandleDrop,
	Equip = PetService.HandleEquip,
	Sync = function(player)
		PlayerDataService.Sync(player)
	end,
}

-- Studio-only test shortcuts (the client sends them from F6-F9; live servers ignore them).
if RunService:IsStudio() then
	handlers.Debug = function(player, command)
		if command == "Midnight" or command == "Dusk" then
			CycleService.Force(command)
		elseif command == "Wake" then
			GuardianService.ForceWake()
		elseif command == "Shells" then
			PlayerDataService.AddShells(player, 1000)
			PlayerDataService.Sync(player)
		end
	end
end

Net.Get("Action").OnServerEvent:Connect(function(player, name, payload)
	if typeof(name) ~= "string" then
		return
	end
	local handler = handlers[name]
	if not handler or not allow(player) then
		return
	end
	local ok, err = pcall(handler, player, payload)
	if not ok then
		warn(("[Main] %s from %s failed: %s"):format(name, player.Name, tostring(err)))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

print(("[Main] Midnight Hatch %s is running."):format(GameConfig.Version))
