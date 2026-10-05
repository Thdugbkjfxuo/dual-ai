-- MAP LAYOUT GENERATOR
-- Run this once (see instructions below) to auto-build a ring of plots
-- arranged in a circle around a central hub point.
--
-- HOW TO RUN IT:
-- This is written as a Script that runs once on server start and then
-- deletes itself, OR you can run it manually via the Command Bar.
-- Easiest: just let it run automatically when you hit Play — it checks
-- if plots already exist first, so it won't duplicate them on repeat runs.

local NUM_PLOTS = 8          -- how many player plots around the ring
local RING_RADIUS = 150      -- distance from center to each plot
local PLOT_SIZE = Vector3.new(20, 1, 20)
local HUB_RADIUS = 40        -- size of the central hub platform

local function buildHub()
	if workspace:FindFirstChild("Hub") then return end

	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Shape = Enum.PartType.Cylinder
	hub.Size = Vector3.new(4, HUB_RADIUS * 2, HUB_RADIUS * 2)
	hub.Orientation = Vector3.new(0, 0, 90)
	hub.Position = Vector3.new(0, 0, 0)
	hub.Anchored = true
	hub.BrickColor = BrickColor.new("Institutional white")
	hub.Parent = workspace
end

local function buildPlots()
	if workspace:FindFirstChild("Plots") then return end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	for i = 1, NUM_PLOTS do
		local angle = (i - 1) * (2 * math.pi / NUM_PLOTS)
		local x = math.cos(angle) * RING_RADIUS
		local z = math.sin(angle) * RING_RADIUS

		local plot = Instance.new("Part")
		plot.Name = "Plot" .. i
		plot.Size = PLOT_SIZE
		plot.Position = Vector3.new(x, 0, z)
		plot.Anchored = true
		plot.BrickColor = BrickColor.new("Pastel green")
		plot:SetAttribute("Owner", "")
		plot.Parent = plotsFolder
	end
end

buildHub()
buildPlots()

print("Map layout generated: 1 hub + " .. NUM_PLOTS .. " plots in a ring.")
