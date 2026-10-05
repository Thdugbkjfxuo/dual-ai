-- Net
-- Creates the game's RemoteEvents from code (server) or waits for them (client), so nothing has to
-- be made by hand in Studio. This replaces the prototype's manual RemoteEvents/HatchEgg.
--
-- Client -> server:  Action(name, payload)   requests only; the server validates every one
-- Server -> client:  Notify(text, style)     toasts
--                    Hatched(result)         a hatch reveal (rolled on the server)
--                    Caught(fromPosition)    the guardian caught you
--                    ProfileSync(snapshot)   Shells, pets, equipped pet

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "MidnightRemotes"
local REMOTE_NAMES = { "Action", "Notify", "Hatched", "Caught", "ProfileSync" }

local Net = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
	end
	for _, name in REMOTE_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Net.Get(name)
	local remote = folder:WaitForChild(name, 15)
	assert(remote, "[Net] missing remote " .. tostring(name))
	return remote
end

return Net
