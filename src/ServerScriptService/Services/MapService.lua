-- MapService
-- Builds the one Round 1 map when the server starts: a compact moonlit forest with a warm, safe
-- Hatchery at one end, Mama Moss's nest at the other, and a winding trail between them.
-- Replaces the prototype's MapGenerator (a hub ringed by 8 player plots), which fit the old plot design.
-- Everything is generated from GameConfig.Map with a fixed seed, so every server has the same forest.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

local MAP = GameConfig.Map
local GROUPS = GameConfig.CollisionGroups

local MapService = {}

MapService.HatcheryCenter = MAP.HatcheryCenter
MapService.HatcheryRadius = MAP.HatcheryRadius
MapService.NestCenter = MAP.NestCenter
MapService.GroundY = 0
MapService.GuardianHome = CFrame.new() -- ground point behind the eggs, facing the hatchery; set in Init
MapService.Root = nil -- Workspace.MidnightMap
MapService.EggFolder = nil -- Workspace.MidnightMap.Eggs

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (X) vertical
local MOUND_DIAMETER = 80
local MOUND_CENTER_Y = -37 -- a huge ball mostly underground: round collision and a gentle hill

local LEAF_COLORS = {
	Color3.fromRGB(40, 78, 62),
	Color3.fromRGB(52, 70, 92),
	Color3.fromRGB(46, 88, 70),
	Color3.fromRGB(70, 64, 98),
}
local GLOW_COLORS = {
	Color3.fromRGB(110, 255, 220),
	Color3.fromRGB(255, 120, 210),
	Color3.fromRGB(196, 160, 255),
}
local AMBER = Color3.fromRGB(255, 196, 110)

local rng = Random.new(MAP.Seed)
local root
local ourSpawn

local function makePart(parent, props)
	local part = Instance.new(props.ClassName or "Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape -- before Size, so balls and cylinders keep the intended size
	end
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Decoration: no collision, no raycasts, no touch events.
local function decor(props)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return props
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function distanceToSegment(point, a, b)
	local ab = flat(b - a)
	local ap = flat(point - a)
	local lengthSquared = ab:Dot(ab)
	local t = if lengthSquared > 0 then math.clamp(ap:Dot(ab) / lengthSquared, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

local function distanceToTrail(point)
	local best = math.huge
	for i = 1, #MAP.Trail - 1 do
		best = math.min(best, distanceToSegment(point, MAP.Trail[i], MAP.Trail[i + 1]))
	end
	return best
end

local function farFromAll(point, others, minDistance)
	for _, other in others do
		if flat(point - other).Magnitude < minDistance then
			return false
		end
	end
	return true
end

local function inPlayableArea(point, margin)
	local limit = MAP.PlayableHalfSize - margin
	return math.abs(point.X) <= limit and math.abs(point.Z) <= limit
end

---------------------------------------------------------------------------------------------------
-- Public helpers
---------------------------------------------------------------------------------------------------

-- Height of the nest mound's surface at an offset from the nest centre (0 outside the mound).
function MapService.MoundHeight(offsetX, offsetZ)
	local radius = MOUND_DIAMETER / 2
	local distanceSquared = offsetX * offsetX + offsetZ * offsetZ
	if distanceSquared >= radius * radius then
		return 0
	end
	return math.max(0, MOUND_CENTER_Y + math.sqrt(radius * radius - distanceSquared))
end

-- World point on the nest surface for a slot offset.
function MapService.NestSurface(offset)
	local nest = MAP.NestCenter
	return Vector3.new(nest.X + offset.X, MapService.MoundHeight(offset.X, offset.Z), nest.Z + offset.Z)
end

-- World point on the trail surface (stray practice eggs sit on the trail).
function MapService.TrailPoint(position)
	return Vector3.new(position.X, 0.15, position.Z)
end

-- True inside the hatchery fence (plus an optional margin). The guardian never enters it.
function MapService.IsInSafeZone(position, margin)
	local center = MAP.HatcheryCenter
	local dx, dz = position.X - center.X, position.Z - center.Z
	local radius = MAP.HatcheryRadius + (margin or 0)
	return dx * dx + dz * dz <= radius * radius and position.Y > -10 and position.Y < 40
end

---------------------------------------------------------------------------------------------------
-- Builders
---------------------------------------------------------------------------------------------------

local function setupCollisionGroups()
	for _, name in { GROUPS.Guardian, GROUPS.Trees, GROUPS.Players } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	-- The guardian walks through trees and rocks (no pathfinding needed) and through players (no flinging).
	PhysicsService:CollisionGroupSetCollidable(GROUPS.Guardian, GROUPS.Trees, false)
	PhysicsService:CollisionGroupSetCollidable(GROUPS.Guardian, GROUPS.Players, false)
end

local function buildGround()
	makePart(root, {
		Name = "Ground",
		Size = Vector3.new(MAP.GroundSize, 2, MAP.GroundSize),
		CFrame = CFrame.new(0, -1, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(58, 96, 62),
	})

	local half = MAP.PlayableHalfSize + 5
	local size = MAP.GroundSize
	local walls = {
		{ CFrame.new(half, 30, 0), Vector3.new(2, 60, size) },
		{ CFrame.new(-half, 30, 0), Vector3.new(2, 60, size) },
		{ CFrame.new(0, 30, half), Vector3.new(size, 60, 2) },
		{ CFrame.new(0, 30, -half), Vector3.new(size, 60, 2) },
	}
	for _, wall in walls do
		makePart(root, {
			Name = "Boundary",
			CFrame = wall[1],
			Size = wall[2],
			Transparency = 1,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

local function buildTrail()
	local folder = Instance.new("Folder")
	folder.Name = "Trail"
	folder.Parent = root
	local color = Color3.fromRGB(112, 86, 62)

	for i = 1, #MAP.Trail - 1 do
		local a, b = MAP.Trail[i], MAP.Trail[i + 1]
		local mid = (a + b) / 2
		makePart(
			folder,
			decor({
				Name = "TrailSegment",
				Size = Vector3.new(MAP.TrailWidth, 0.2, flat(b - a).Magnitude),
				CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.05, mid.Z), Vector3.new(b.X, 0.05, b.Z)),
				Material = Enum.Material.Ground,
				Color = color,
				CastShadow = false,
			})
		)
	end
	for _, point in MAP.Trail do
		makePart(
			folder,
			decor({
				Name = "TrailBend",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, MAP.TrailWidth, MAP.TrailWidth),
				CFrame = CFrame.new(point.X, 0.05, point.Z) * UPRIGHT,
				Material = Enum.Material.Ground,
				Color = color,
				CastShadow = false,
			})
		)
	end
end

local function buildPuffTree(model, position)
	local height = rng:NextNumber(10, 16)
	local trunk = rng:NextNumber(1.6, 2.4)
	makePart(model, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, trunk, trunk),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(78, 56, 44),
		CollisionGroup = GROUPS.Trees,
	})
	local leafColor = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local crown = rng:NextNumber(8, 11)
	makePart(
		model,
		decor({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(crown, crown, crown),
			CFrame = CFrame.new(position + Vector3.new(0, height + crown * 0.2, 0)),
			Material = Enum.Material.Grass,
			Color = leafColor,
		})
	)
	local small = crown * 0.65
	makePart(
		model,
		decor({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(small, small, small),
			CFrame = CFrame.new(
				position + Vector3.new(rng:NextNumber(-2.5, 2.5), height + crown * 0.55, rng:NextNumber(-2.5, 2.5))
			),
			Material = Enum.Material.Grass,
			Color = leafColor,
			CastShadow = false,
		})
	)
end

local function buildDeadTree(model, position)
	local height = rng:NextNumber(12, 18)
	local trunk = rng:NextNumber(1.2, 1.8)
	local bark = Color3.fromRGB(64, 52, 54)
	makePart(model, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, trunk, trunk),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Material = Enum.Material.Wood,
		Color = bark,
		CollisionGroup = GROUPS.Trees,
	})
	for _ = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local axis = (outward * math.sin(math.rad(40)) + Vector3.new(0, math.cos(math.rad(40)), 0)).Unit
		local length = rng:NextNumber(4, 6.5)
		local start = position + Vector3.new(0, height * rng:NextNumber(0.55, 0.85), 0) + outward * trunk * 0.4
		local center = start + axis * (length / 2)
		makePart(
			model,
			decor({
				Name = "Branch",
				Size = Vector3.new(0.7, length, 0.7),
				CFrame = CFrame.lookAt(center, center + axis) * CFrame.Angles(-math.pi / 2, 0, 0),
				Material = Enum.Material.Wood,
				Color = bark,
				CastShadow = false,
			})
		)
	end
end

local function treeSpotOK(point, placed)
	if not inPlayableArea(point, 4) then
		return false
	end
	if distanceToTrail(point) < MAP.TrailWidth / 2 + 6 then
		return false
	end
	if flat(point - MAP.HatcheryCenter).Magnitude < MAP.HatcheryRadius + 10 then
		return false
	end
	if flat(point - MAP.NestCenter).Magnitude < 26 then
		return false
	end
	return farFromAll(point, placed, 10)
end

local function buildForest()
	local folder = Instance.new("Folder")
	folder.Name = "Forest"
	folder.Parent = root

	local trees = {}
	local function addTree(point)
		local model = Instance.new("Model")
		if rng:NextNumber() < 0.3 then
			model.Name = "DeadTree"
			buildDeadTree(model, point)
		else
			model.Name = "PuffTree"
			buildPuffTree(model, point)
		end
		model.Parent = folder
		table.insert(trees, point)
	end

	-- A ring of trees near the edge frames the forest.
	for i = 1, MAP.EdgeTreeCount do
		local angle = (i / MAP.EdgeTreeCount) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(172, 186)
		local point = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if treeSpotOK(point, trees) then
			addTree(point)
		end
	end
	-- Trees scattered through the middle, kept off the trail and away from the hatchery and nest.
	local attempts = 0
	local placed = 0
	while placed < MAP.TreeCount and attempts < MAP.TreeCount * 30 do
		attempts += 1
		local point = Vector3.new(
			rng:NextNumber(-MAP.PlayableHalfSize, MAP.PlayableHalfSize),
			0,
			rng:NextNumber(-MAP.PlayableHalfSize, MAP.PlayableHalfSize)
		)
		if treeSpotOK(point, trees) then
			addTree(point)
			placed += 1
		end
	end

	-- Glowing mushrooms near trees (Neon, no lights: cheap on phones).
	for _ = 1, if #trees > 0 then MAP.MushroomCount else 0 do
		local base = trees[rng:NextInteger(1, #trees)]
		local point = base + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		local stemHeight = rng:NextNumber(0.6, 1.2)
		local cap = rng:NextNumber(1.0, 1.6)
		makePart(
			folder,
			decor({
				Name = "MushroomStem",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(stemHeight, 0.35, 0.35),
				CFrame = CFrame.new(point + Vector3.new(0, stemHeight / 2, 0)) * UPRIGHT,
				Color = Color3.fromRGB(230, 225, 210),
				CastShadow = false,
			})
		)
		makePart(
			folder,
			decor({
				Name = "MushroomCap",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(cap, cap, cap),
				CFrame = CFrame.new(point + Vector3.new(0, stemHeight, 0)),
				Material = Enum.Material.Neon,
				Color = GLOW_COLORS[rng:NextInteger(1, #GLOW_COLORS)],
				CastShadow = false,
			})
		)
	end

	-- Bushes you can walk through (good for sneaking), and rocks you cannot (the guardian can).
	local others = {}
	for _ = 1, MAP.BushCount do
		local point = Vector3.new(rng:NextNumber(-180, 180), 0, rng:NextNumber(-180, 180))
		if distanceToTrail(point) > MAP.TrailWidth / 2 + 1 and not MapService.IsInSafeZone(point, 4) then
			local size = rng:NextNumber(4, 6.5)
			makePart(
				folder,
				decor({
					Name = "Bush",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(size, size, size),
					CFrame = CFrame.new(point + Vector3.new(0, size * 0.25, 0)),
					Material = Enum.Material.Grass,
					Color = Color3.fromRGB(46, 82, 58),
					CastShadow = false,
				})
			)
		end
	end
	for _ = 1, MAP.RockCount do
		local point = Vector3.new(rng:NextNumber(-185, 185), 0, rng:NextNumber(-185, 185))
		if
			distanceToTrail(point) > MAP.TrailWidth / 2 + 3
			and not MapService.IsInSafeZone(point, 6)
			and flat(point - MAP.NestCenter).Magnitude > 22
			and farFromAll(point, others, 8)
		then
			local size = rng:NextNumber(2.5, 5)
			makePart(folder, {
				Name = "Rock",
				Size = Vector3.new(size * rng:NextNumber(1, 1.6), size, size * rng:NextNumber(1, 1.5)),
				CFrame = CFrame.new(point + Vector3.new(0, size * 0.35, 0))
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
				Material = Enum.Material.Slate,
				Color = Color3.fromRGB(108, 108, 120),
				CollisionGroup = GROUPS.Trees,
			})
			table.insert(others, point)
		end
	end
end

local function lantern(parent, position, range)
	local bulb = makePart(
		parent,
		decor({
			Name = "Lantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = CFrame.new(position),
			Material = Enum.Material.Neon,
			Color = AMBER,
			CastShadow = false,
		})
	)
	local light = Instance.new("PointLight")
	light.Color = AMBER
	light.Range = range
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = bulb
	return bulb
end

local function buildHatchery()
	local model = Instance.new("Model")
	model.Name = "Hatchery"
	model.Parent = root
	local center = MAP.HatcheryCenter
	local radius = MAP.HatcheryRadius
	local wood = Color3.fromRGB(112, 76, 50)

	makePart(model, {
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * UPRIGHT,
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(150, 105, 70),
	})
	makePart(
		model,
		decor({
			Name = "Rug",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7, 22, 22),
			CFrame = CFrame.new(center) * UPRIGHT,
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(176, 72, 60),
			CastShadow = false,
		})
	)

	-- Fence posts and rails, with a gate gap facing the nest (-Z).
	local gateHalfAngle = math.rad(28)
	local function onRing(angle, ringRadius, y)
		return center + Vector3.new(math.sin(angle) * ringRadius, y, math.cos(angle) * ringRadius)
	end
	local function inGate(angle)
		return math.abs((angle % (math.pi * 2)) - math.pi) < gateHalfAngle -- angular distance from -Z
	end
	local postCount = 24
	for i = 0, postCount - 1 do
		local angle = i / postCount * math.pi * 2
		local nextAngle = (i + 1) / postCount * math.pi * 2
		if not inGate(angle) then
			makePart(model, {
				Name = "Post",
				Size = Vector3.new(1.1, 4.2, 1.1),
				CFrame = CFrame.new(onRing(angle, radius, 2.4)),
				Material = Enum.Material.Wood,
				Color = wood,
			})
			if not inGate(nextAngle) then
				local a, b = onRing(angle, radius, 3.6), onRing(nextAngle, radius, 3.6)
				makePart(model, {
					Name = "Rail",
					Size = Vector3.new(0.5, 0.5, (b - a).Magnitude),
					CFrame = CFrame.lookAt((a + b) / 2, b),
					Material = Enum.Material.Wood,
					Color = wood,
				})
			end
		end
	end

	-- The gate arch with a sign and two lanterns.
	local left = onRing(math.pi - gateHalfAngle, radius, 5)
	local right = onRing(math.pi + gateHalfAngle, radius, 5)
	for _, base in { left, right } do
		makePart(model, {
			Name = "GatePost",
			Size = Vector3.new(1.6, 10, 1.6),
			CFrame = CFrame.new(base),
			Material = Enum.Material.Wood,
			Color = wood,
		})
	end
	local beamCenter = (left + right) / 2 + Vector3.new(0, 5, 0)
	makePart(model, {
		Name = "GateBeam",
		Size = Vector3.new((right - left).Magnitude + 1.6, 1.4, 1.4),
		CFrame = CFrame.new(beamCenter),
		Material = Enum.Material.Wood,
		Color = wood,
	})
	local sign = makePart(
		model,
		decor({
			Name = "Sign",
			Size = Vector3.new(14, 3, 0.4),
			CFrame = CFrame.new(beamCenter + Vector3.new(0, -2.2, -0.2)),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(70, 46, 34),
		})
	)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front -- -Z, toward the trail
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.FredokaOne
	signText.Text = "HATCHERY"
	signText.TextScaled = true
	signText.TextColor3 = AMBER
	signText.Parent = surface
	for _, side in { -1, 1 } do
		lantern(model, beamCenter + Vector3.new(side * 9, -1.6, -0.9), 22)
	end
	-- two more on top of fence posts (posts stand every 15 degrees; their tops are at y = 4.5)
	lantern(model, onRing(math.rad(75), radius, 5.3), 16)
	lantern(model, onRing(math.rad(285), radius, 5.3), 16)

	-- The hatch altar in the middle, and a few hay bales.
	makePart(model, {
		Name = "Altar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 7, 7),
		CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)) * UPRIGHT,
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(110, 104, 124),
	})
	makePart(
		model,
		decor({
			Name = "AltarGlow",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 7.4, 7.4),
			CFrame = CFrame.new(center + Vector3.new(0, 2.75, 0)) * UPRIGHT,
			Material = Enum.Material.Neon,
			Color = AMBER,
			CastShadow = false,
		})
	)
	for _, degrees in { 35, 0, -35 } do
		local position = onRing(math.rad(degrees), radius - 5, 1.5)
		makePart(model, {
			Name = "HayBale",
			Size = Vector3.new(5, 2.4, 2.6),
			CFrame = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(210, 180, 92),
		})
	end

	ourSpawn = Instance.new("SpawnLocation")
	ourSpawn.Name = "HatcherySpawn"
	ourSpawn.Size = Vector3.new(8, 0.3, 8)
	ourSpawn.CFrame = CFrame.new(center + Vector3.new(0, 0.45, 12))
	ourSpawn.Anchored = true
	ourSpawn.CanCollide = false
	ourSpawn.CanQuery = false
	ourSpawn.Transparency = 1
	ourSpawn.Neutral = true
	ourSpawn.Duration = 0
	ourSpawn.Parent = model
end

local function buildNest()
	local model = Instance.new("Model")
	model.Name = "Nest"
	model.Parent = root
	local nest = MAP.NestCenter

	makePart(model, {
		Name = "Mound",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(MOUND_DIAMETER, MOUND_DIAMETER, MOUND_DIAMETER),
		CFrame = CFrame.new(nest.X, MOUND_CENTER_Y, nest.Z),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(66, 104, 60),
	})

	-- Two rings of twigs around the eggs.
	for ring = 1, 2 do
		local count = if ring == 1 then 16 else 12
		local ringRadius = if ring == 1 then 15.5 else 13
		for i = 0, count - 1 do
			local angle = (i + ring * 0.5) / count * math.pi * 2
			local offsetX, offsetZ = math.sin(angle) * ringRadius, math.cos(angle) * ringRadius
			local position = Vector3.new(
				nest.X + offsetX,
				MapService.MoundHeight(offsetX, offsetZ) + 0.4 + ring * 0.3,
				nest.Z + offsetZ
			)
			local tangent = Vector3.new(math.cos(angle), 0, -math.sin(angle))
			makePart(
				model,
				decor({
					Name = "Twig",
					Size = Vector3.new(0.9, 0.9, 7.5),
					CFrame = CFrame.lookAt(position, position + tangent)
						* CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.2, 0.2)),
					Material = Enum.Material.Wood,
					Color = Color3.fromRGB(104, 74, 48),
					CastShadow = false,
				})
			)
		end
	end

	local home = MapService.NestSurface(MAP.GuardianHomeOffset)
	MapService.GuardianHome = CFrame.lookAt(home, home + Vector3.new(0, 0, 1))
end

local function buildMarkers()
	local markers = Instance.new("Model")
	markers.Name = "Markers"
	markers.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- always visible to everyone
	markers.Parent = root

	local function marker(name, position, text, color)
		local anchor =
			makePart(markers, decor({ Name = name, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position) }))
		anchor.Transparency = 1
		local gui = Instance.new("BillboardGui")
		gui.Name = "Label"
		gui.Size = UDim2.fromOffset(240, 44)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 900
		gui.LightInfluence = 0
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 24
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
	end

	marker(
		"HatcheryMarker",
		MAP.HatcheryCenter + Vector3.new(0, 16, -MAP.HatcheryRadius),
		"🏠 HATCHERY · SAFE",
		AMBER
	)
	marker("NestMarker", MAP.NestCenter + Vector3.new(0, 24, 0), "🥚 MAMA MOSS'S NEST", Color3.fromRGB(200, 170, 255))
end

-- Runtime-only tidy-up of things the old prototype left in the place. Nothing here is saved.
local function cleanUpPrototype()
	local legacyEgg = workspace:FindFirstChild("Egg")
	if legacyEgg and legacyEgg:FindFirstChildOfClass("ProximityPrompt") then
		legacyEgg:Destroy()
		print("[MapService] Removed the prototype's Workspace.Egg for this test. You can delete it in Studio.")
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.CFrame += Vector3.new(0, -40, 0) -- out of sight under the forest floor
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant ~= ourSpawn then
			descendant.Enabled = false
		end
	end
end

function MapService.Init()
	setupCollisionGroups()

	local old = workspace:FindFirstChild("MidnightMap")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "MidnightMap"
	MapService.Root = root

	buildGround()
	buildTrail()
	buildForest()
	buildHatchery()
	buildNest()
	buildMarkers()

	local eggs = Instance.new("Folder")
	eggs.Name = "Eggs"
	eggs.Parent = root
	MapService.EggFolder = eggs

	root.Parent = workspace
	cleanUpPrototype()

	local parts = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	print(("[MapService] Built the forest: %d parts."):format(parts))
end

return MapService
