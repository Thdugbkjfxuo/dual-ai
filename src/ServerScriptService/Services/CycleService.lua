-- CycleService
-- The server-wide clock: 4 minutes of Dusk, then a 60-second Midnight surge, forever.
-- No lobby, prep or results screen: you can join, grab and bank at any moment.
-- Publishes MH_Phase and MH_PhaseEndsAt (server time) as ReplicatedStorage attributes; clients
-- draw the timer and change the lighting from those.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local Net = require(Modules.Net)

local CYCLE = GameConfig.Cycle

local CycleService = {}

local phase = "Dusk"
local endsAt = 0
local forced = nil
local listeners = {}

local function publish()
	ReplicatedStorage:SetAttribute("MH_Phase", phase)
	ReplicatedStorage:SetAttribute("MH_PhaseEndsAt", endsAt)
end

local function enter(newPhase)
	phase = newPhase
	local duration = if newPhase == "Midnight" then CYCLE.MidnightSeconds else CYCLE.DuskSeconds
	endsAt = workspace:GetServerTimeNow() + duration
	publish()
	if newPhase == "Midnight" then
		Net.Get("Notify")
			:FireAllClients("🌕 MIDNIGHT! Eggs glow and Mama Moss won't sleep for 60 seconds!", "midnight")
	end
	for _, listener in listeners do
		local ok, err = pcall(listener, newPhase)
		if not ok then
			warn("[CycleService] phase listener failed: " .. tostring(err))
		end
	end
end

function CycleService.GetPhase()
	return phase
end

function CycleService.OnPhaseChanged(listener)
	table.insert(listeners, listener)
end

-- Studio testing: jump straight to "Dusk" or "Midnight".
function CycleService.Force(newPhase)
	if newPhase == "Dusk" or newPhase == "Midnight" then
		forced = newPhase
	end
end

function CycleService.Init()
	phase = "Dusk"
	endsAt = workspace:GetServerTimeNow() + CYCLE.DuskSeconds
	publish()
end

function CycleService.Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			if forced then
				local nextPhase = forced
				forced = nil
				enter(nextPhase)
			elseif workspace:GetServerTimeNow() >= endsAt then
				enter(if phase == "Dusk" then "Midnight" else "Dusk")
			end
		end
	end)
end

return CycleService
