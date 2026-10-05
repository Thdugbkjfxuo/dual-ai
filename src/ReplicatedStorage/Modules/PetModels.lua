-- PetModels
-- Builds the six pets and the three eggs from plain parts, so the game needs no uploaded meshes.
-- Used by the server (eggs in the world) and the client (pet followers, the hatch reveal, the pets
-- panel). Every part is anchored, non-colliding and ignored by raycasts and the camera.
-- Pets face -Z (their front), are about 2 studs tall, and pivot on their centre.

local GameConfig = require(script.Parent.GameConfig)

local PetModels = {}

local BLACK = Color3.fromRGB(25, 20, 30)
local WHITE = Color3.fromRGB(250, 250, 250)
local MIDNIGHT_BODY = Color3.fromRGB(96, 64, 200)
local MIDNIGHT_ACCENT = Color3.fromRGB(196, 160, 255)
local MIDNIGHT_EGG = Color3.fromRGB(122, 84, 232)
local MIDNIGHT_EGG_SPECKLE = Color3.fromRGB(232, 214, 255)

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (X) vertical
local FACING = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis toward the front (Z)

-- options: Shape, Wedge, Ellipsoid, Material, Transparency, Role ("Body" | "Accent" | "Eye" | ...)
local function newPart(model, name, size, cframe, color, options)
	options = options or {}
	local part
	if options.Wedge then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		part.Shape = options.Shape or Enum.PartType.Block
	end
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = options.Material or Enum.Material.SmoothPlastic
	part.Transparency = options.Transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if options.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part:SetAttribute("Role", options.Role or "Body")
	part.Parent = model
	return part
end

local function ball(model, name, diameter, position, color, options)
	options = options or {}
	options.Shape = Enum.PartType.Ball
	return newPart(model, name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, options)
end

local function ellipsoid(model, name, size, cframe, color, options)
	options = options or {}
	options.Ellipsoid = true
	return newPart(model, name, size, cframe, color, options)
end

-- A cylinder's axis runs along its CFrame's X axis.
local function cylinder(model, name, length, diameter, cframe, color, options)
	options = options or {}
	options.Shape = Enum.PartType.Cylinder
	return newPart(model, name, Vector3.new(length, diameter, diameter), cframe, color, options)
end

---------------------------------------------------------------------------------------------------
-- Pets
---------------------------------------------------------------------------------------------------

local function buildToastMoth(m)
	local TOAST = Color3.fromRGB(226, 176, 102)
	local CRUST = Color3.fromRGB(150, 96, 48)
	local JAM = Color3.fromRGB(210, 42, 78)
	local core = newPart(m, "Toast", Vector3.new(1.6, 1.5, 0.4), CFrame.new(0, -0.15, 0), TOAST)
	cylinder(m, "ToastTop", 0.4, 1.6, CFrame.new(0, 0.55, 0) * FACING, TOAST)
	newPart(m, "Crust", Vector3.new(1.78, 1.62, 0.34), CFrame.new(0, -0.15, 0.06), CRUST, { Role = "Accent" })
	cylinder(m, "CrustTop", 0.34, 1.78, CFrame.new(0, 0.55, 0.06) * FACING, CRUST, { Role = "Accent" })
	for _, side in { -1, 1 } do
		local wingTilt = CFrame.Angles(0, 0, math.rad(side * 25))
		ellipsoid(m, "Wing", Vector3.new(1.7, 1.2, 0.12), CFrame.new(side * 1.35, 0.3, 0.25) * wingTilt, JAM, {
			Role = "Accent",
		})
		ball(m, "Eye", 0.32, Vector3.new(side * 0.34, 0.22, -0.22), BLACK, { Role = "Eye" })
		ball(m, "Shine", 0.12, Vector3.new(side * 0.31, 0.3, -0.37), WHITE, { Role = "Eye" })
		local antennaTilt = CFrame.Angles(0, 0, math.rad(90 - side * 20))
		cylinder(m, "Antenna", 0.7, 0.07, CFrame.new(side * 0.32, 1.45, 0) * antennaTilt, CRUST, { Role = "Accent" })
		ball(m, "AntennaTip", 0.2, Vector3.new(side * 0.44, 1.78, 0), CRUST, { Role = "Accent" })
	end
	return core
end

local function buildSocktopus(m)
	local SOCK = Color3.fromRGB(86, 156, 232)
	local SOCK_ALT = Color3.fromRGB(236, 92, 92)
	local CUFF = Color3.fromRGB(245, 245, 245)
	local FABRIC = Enum.Material.Fabric
	local core = ball(m, "Head", 1.7, Vector3.new(0, 0.3, 0), SOCK, { Material = FABRIC })
	cylinder(m, "Cuff", 0.4, 1.25, CFrame.new(0, 1.15, 0) * UPRIGHT, CUFF, { Role = "Accent", Material = FABRIC })
	cylinder(m, "Stripe", 0.25, 1.74, CFrame.new(0, 0.45, 0) * UPRIGHT, CUFF, { Role = "Accent", Material = FABRIC })
	for i, angle in { 45, 135, 225, 315 } do
		local dir = Vector3.new(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle)))
		local axis = Vector3.new(-dir.Z, 0, dir.X) -- tilts each sock outward
		local cf = CFrame.new(dir * 0.55 + Vector3.new(0, -0.55, 0)) * CFrame.fromAxisAngle(axis, math.rad(28))
		local color = if i % 2 == 0 then SOCK_ALT else SOCK
		newPart(m, "Tentacle", Vector3.new(0.42, 1.0, 0.42), cf, color, { Material = FABRIC })
		ball(m, "Toe", 0.5, (cf * CFrame.new(0, -0.5, 0)).Position, CUFF, { Role = "Accent", Material = FABRIC })
	end
	for _, side in { -1, 1 } do
		ball(m, "EyeWhite", 0.55, Vector3.new(side * 0.32, 0.45, -0.66), WHITE, { Role = "Eye" })
		ball(m, "Pupil", 0.28, Vector3.new(side * 0.32, 0.45, -0.9), BLACK, { Role = "Eye" })
	end
	return core
end

local function buildMarshmole(m)
	local MARSH = Color3.fromRGB(250, 246, 240)
	local TOASTED = Color3.fromRGB(222, 172, 110)
	local PINK = Color3.fromRGB(255, 150, 175)
	local core = cylinder(m, "Body", 1.5, 1.6, CFrame.new() * UPRIGHT, MARSH)
	cylinder(m, "Toasted", 0.22, 1.62, CFrame.new(0, 0.72, 0) * UPRIGHT, TOASTED, { Role = "Accent" })
	ball(m, "Nose", 0.45, Vector3.new(0, 0.05, -0.84), PINK, { Role = "Accent" })
	for _, side in { -1, 1 } do
		ball(m, "Eye", 0.22, Vector3.new(side * 0.3, 0.32, -0.78), BLACK, { Role = "Eye" })
		ball(m, "Ear", 0.32, Vector3.new(side * 0.56, 0.62, -0.18), MARSH)
		ellipsoid(m, "Paw", Vector3.new(0.42, 0.18, 0.32), CFrame.new(side * 0.42, -0.7, -0.74), PINK, {
			Role = "Accent",
		})
	end
	return core
end

local function buildPumpkit(m)
	local ORANGE = Color3.fromRGB(255, 140, 40)
	local DARK = Color3.fromRGB(226, 106, 30)
	local STEM = Color3.fromRGB(84, 140, 62)
	local GLOW = Color3.fromRGB(255, 228, 92)
	local core = ball(m, "Body", 1.8, Vector3.new(0, 0, 0), ORANGE)
	ellipsoid(m, "Lobes", Vector3.new(2.0, 1.6, 1.3), CFrame.new(), DARK)
	cylinder(m, "Stem", 0.45, 0.28, CFrame.new(0, 1.05, 0) * UPRIGHT, STEM, { Role = "Accent" })
	for _, side in { -1, 1 } do
		newPart(m, "Ear", Vector3.new(0.18, 0.5, 0.45), CFrame.new(side * 0.55, 0.92, -0.12), DARK, { Wedge = true })
		ball(m, "Eye", 0.36, Vector3.new(side * 0.36, 0.2, -0.78), GLOW, {
			Role = "Eye",
			Material = Enum.Material.Neon,
		})
	end
	newPart(m, "Grin", Vector3.new(0.7, 0.1, 0.08), CFrame.new(0, -0.24, -0.86), BLACK, { Role = "Eye" })
	newPart(m, "Tail", Vector3.new(0.16, 0.16, 0.9), CFrame.new(0, 0.25, 1.0) * CFrame.Angles(math.rad(35), 0, 0), DARK)
	return core
end

local function buildMoonbean(m)
	local MOON = Color3.fromRGB(250, 240, 196)
	local CRATER = Color3.fromRGB(222, 206, 150)
	local PINK = Color3.fromRGB(255, 160, 180)
	local STAR = Color3.fromRGB(255, 236, 140)
	local core = ellipsoid(m, "Body", Vector3.new(1.45, 1.9, 1.35), CFrame.new(), MOON)
	ball(m, "Crater", 0.38, Vector3.new(0.36, 0.55, -0.46), CRATER)
	ball(m, "Crater", 0.3, Vector3.new(-0.44, -0.32, -0.44), CRATER)
	ball(m, "Crater", 0.28, Vector3.new(0.52, -0.5, 0.2), CRATER)
	for _, side in { -1, 1 } do
		ellipsoid(m, "SleepyEye", Vector3.new(0.34, 0.08, 0.1), CFrame.new(side * 0.3, 0.18, -0.63), BLACK, {
			Role = "Eye",
		})
		ellipsoid(m, "Blush", Vector3.new(0.28, 0.14, 0.06), CFrame.new(side * 0.48, -0.02, -0.53), PINK, {
			Role = "Accent",
		})
	end
	ball(m, "Star", 0.26, Vector3.new(0.85, 0.95, 0), STAR, { Role = "Accent", Material = Enum.Material.Neon })
	return core
end

local function buildWispurr(m)
	local GHOST = Color3.fromRGB(130, 230, 255)
	local NEON = Enum.Material.Neon
	local core = ball(m, "Body", 1.6, Vector3.new(0, 0, 0), GHOST, { Material = NEON, Transparency = 0.2 })
	for _, side in { -1, 1 } do
		newPart(m, "Ear", Vector3.new(0.16, 0.5, 0.42), CFrame.new(side * 0.45, 0.85, -0.05), GHOST, {
			Wedge = true,
			Material = NEON,
			Transparency = 0.2,
		})
		ellipsoid(m, "Eye", Vector3.new(0.26, 0.4, 0.1), CFrame.new(side * 0.3, 0.12, -0.74), BLACK, { Role = "Eye" })
	end
	ball(m, "Tail", 0.85, Vector3.new(0, -0.45, 0.85), GHOST, { Material = NEON, Transparency = 0.35 })
	ball(m, "Tail", 0.55, Vector3.new(0, -0.8, 1.35), GHOST, { Material = NEON, Transparency = 0.35 })
	ball(m, "Tail", 0.3, Vector3.new(0, -1.0, 1.75), GHOST, { Material = NEON, Transparency = 0.35 })
	return core
end

local BUILDERS = {
	ToastMoth = buildToastMoth,
	Socktopus = buildSocktopus,
	Marshmole = buildMarshmole,
	Pumpkit = buildPumpkit,
	Moonbean = buildMoonbean,
	Wispurr = buildWispurr,
}

local function applyMidnight(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Role")
			if role == "Body" then
				part.Color = part.Color:Lerp(MIDNIGHT_BODY, 0.6)
			elseif role == "Accent" then
				part.Color = MIDNIGHT_ACCENT
				part.Material = Enum.Material.Neon
			end
		end
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "MidnightSparkles"
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(0.4, 1.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Color = ColorSequence.new(MIDNIGHT_ACCENT)
	sparkles.LightEmission = 1
	sparkles.Parent = model.PrimaryPart
end

-- Returns a Model (PrimaryPart set, pivot at the pet's centre) or nil for an unknown pet.
function PetModels.BuildPet(petId, variant)
	local builder = BUILDERS[petId]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = petId
	model.PrimaryPart = builder(model)
	if variant == "Midnight" then
		applyMidnight(model)
	end
	return model
end

---------------------------------------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------------------------------------

-- Switches an egg between its normal look and its glowing Midnight look.
-- withLight adds a small PointLight (world eggs only; viewports ignore lights).
function PetModels.SetEggMidnight(model, kind, isMidnight, withLight)
	local cfg = GameConfig.Eggs[kind]
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Role")
			if role == "Shell" then
				part.Color = if isMidnight then MIDNIGHT_EGG else cfg.Color
				part.Material = if isMidnight then Enum.Material.Neon else Enum.Material.SmoothPlastic
			elseif role == "Speckle" then
				part.Color = if isMidnight then MIDNIGHT_EGG_SPECKLE else cfg.SpeckleColor
				part.Material = if isMidnight then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
	end

	local shell = model.PrimaryPart
	if not shell then
		return
	end
	local light = shell:FindFirstChild("MidnightGlow")
	if isMidnight and withLight and not light then
		light = Instance.new("PointLight")
		light.Name = "MidnightGlow"
		light.Color = Color3.fromRGB(176, 136, 255)
		light.Range = cfg.Height * 2.5 + 4
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = shell
	elseif not isMidnight and light then
		light:Destroy()
	end
end

-- An egg-shaped shell with speckles welded to it (the welds hold it together while carried).
-- seed makes the speckle pattern repeatable.
function PetModels.BuildEgg(kind, isMidnight, seed, withLight)
	local cfg = GameConfig.Eggs[kind]
	local model = Instance.new("Model")
	model.Name = kind .. "Egg"

	local height = cfg.Height
	local width = height * 0.78
	local shell = ellipsoid(model, "Shell", Vector3.new(width, height, width), CFrame.new(), cfg.Color, {
		Role = "Shell",
	})
	shell.CastShadow = kind == "Giant"

	local rng = Random.new(seed or 1)
	for _ = 1, cfg.Speckles do
		local y = rng:NextNumber(-0.5, 0.92)
		local angle = rng:NextNumber(0, math.pi * 2)
		local ring = math.sqrt(math.max(0, 1 - y * y))
		local surface =
			Vector3.new(math.cos(angle) * ring * width / 2, y * height / 2, math.sin(angle) * ring * width / 2)
		local diameter = height * rng:NextNumber(0.1, 0.17)
		local speckle = ball(model, "Speckle", diameter, surface * 0.94, cfg.SpeckleColor, { Role = "Speckle" })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = shell
		weld.Part1 = speckle
		weld.Parent = speckle
	end

	model.PrimaryPart = shell
	PetModels.SetEggMidnight(model, kind, isMidnight, withLight)
	return model
end

return PetModels
