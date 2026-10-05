-- REQUIRES (create manually in Studio, Rojo doesn't sync these instance types by default):
--   workspace > Plots (Folder) containing Plot1, Plot2, Plot3, Plot4 (Parts, anchored,
--     each with a string Attribute called "Owner" left blank)

local Players = game:GetService("Players")
local plotsFolder = workspace:WaitForChild("Plots")

local function getAvailablePlot()
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("Owner") == "" or plot:GetAttribute("Owner") == nil then
			return plot
		end
	end
	return nil -- no free plots; handle overflow later
end

local function assignPlot(player)
	local plot = getAvailablePlot()
	if not plot then
		warn("No available plots for " .. player.Name)
		return
	end

	plot:SetAttribute("Owner", player.UserId)
	player:SetAttribute("AssignedPlot", plot.Name)

	player.CharacterAdded:Connect(function(character)
		local hrp = character:WaitForChild("HumanoidRootPart")
		local spawnCFrame = plot.CFrame + Vector3.new(0, 5, 0)
		hrp.CFrame = spawnCFrame
	end)

	player:LoadCharacter()
end

local function releasePlot(player)
	local plotName = player:GetAttribute("AssignedPlot")
	if plotName then
		local plot = plotsFolder:FindFirstChild(plotName)
		if plot then
			plot:SetAttribute("Owner", "")
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Wait()
	assignPlot(player)
end)

Players.PlayerRemoving:Connect(releasePlot)
