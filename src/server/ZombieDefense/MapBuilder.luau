-- Baut die Zombie-Map nach der Skizze:
--   [ Zombies ]==[ Mitte: Pets oben/unten am Rand ]==[ Huette ]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ZombieDefense.Config)
local Layout = require(ReplicatedStorage.ZombieDefense.Layout)

local M = Config.Map
local W = Layout.World
local TEX = Config.VFX.Textures

local MapBuilder = {}

export type MapRefs = {
	Root: Folder,
	Zombies: Folder,
	PlacedPets: Folder,
	Slots: { [string]: BasePart },
	HutFill: Frame,
	HutText: TextLabel,
	HutModel: Model,
}

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- Boden mit Oberkante bei y = 0
local function floor(parent: Instance, name: string, x: number, z: number, sx: number, sz: number, color: Color3, material: Enum.Material)
	return part({
		Name = name,
		Size = Vector3.new(sx, 4, sz),
		Position = W(x, -2, z),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function stripe(parent: Instance, x: number, z: number, sx: number, sz: number, color: Color3, material: Enum.Material, height: number?)
	local h = height or 0.2
	return part({
		Name = "Path",
		Size = Vector3.new(sx, h, sz),
		Position = W(x, h / 2, z),
		Color = color,
		Material = material,
		CanCollide = false,
		Parent = parent,
	})
end

local function billboardLabel(adornee: BasePart, text: string, color: Color3, studsWide: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(studsWide, 0, studsWide / 4, 0)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return gui
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.5
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Portal mit Torbogen; gibt die Beruehrungsflaeche zurueck
local function portal(parent: Instance, name: string, position: Vector3, color: Color3, text: string): BasePart
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local stone = Color3.fromRGB(70, 70, 80)
	for _, side in { -1, 1 } do
		part({ Size = Vector3.new(1.5, 10, 1.5), Position = position + Vector3.new(0, 5, side * 4), Color = stone, Material = Enum.Material.Slate, Parent = model })
	end
	part({ Size = Vector3.new(1.5, 1.5, 9.5), Position = position + Vector3.new(0, 10.5, 0), Color = stone, Material = Enum.Material.Slate, Parent = model })
	local field = part({
		Name = "Field",
		Size = Vector3.new(0.6, 9, 6.5),
		Position = position + Vector3.new(0, 5, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Parent = model,
	})
	emitter(field, {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(color),
		Rate = 25,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
	})
	light(field, color, 16, 2)
	billboardLabel(field, text, color, 12).StudsOffset = Vector3.new(0, 7.5, 0)
	model.PrimaryPart = field
	return field
end

local function buildLane(env: Folder)
	local laneX = (Layout.LaneMinX + Layout.CenterMinX) / 2
	local halfW = M.LaneWidth / 2
	floor(env, "ZombieLane", laneX, 0, M.LaneLength, M.LaneWidth, Color3.fromRGB(52, 58, 48), Enum.Material.Ground)
	stripe(env, laneX, 0, M.LaneLength, 16, Color3.fromRGB(88, 72, 55), Enum.Material.Ground)

	-- Gruftor, aus dem die Zombies kommen
	local gateX = Layout.LaneMinX + 1.5
	local dark = Color3.fromRGB(45, 45, 52)
	for _, side in { -1, 1 } do
		part({ Size = Vector3.new(3, 14, 3), Position = W(gateX, 7, side * 9), Color = dark, Material = Enum.Material.Slate, Parent = env })
		part({ Size = Vector3.new(1.4, 1.4, 1.4), Position = W(gateX, 14.7, side * 9), Color = Color3.fromRGB(120, 255, 90), Material = Enum.Material.Neon, Parent = env })
	end
	-- Rueckwand, damit man hinten nicht runterfaellt
	part({ Size = Vector3.new(2, 16, M.LaneWidth), Position = W(Layout.LaneMinX - 1, 8, 0), Color = dark, Material = Enum.Material.Slate, Parent = env })
	local beam = part({ Size = Vector3.new(3, 3, 21), Position = W(gateX, 15.5, 0), Color = dark, Material = Enum.Material.Slate, Parent = env })
	billboardLabel(beam, "🧟 ZOMBIES", Color3.fromRGB(140, 255, 110), 14)
	local gate = part({
		Name = "ZombieGate",
		Size = Vector3.new(0.6, 14, 15),
		Position = W(gateX, 7, 0),
		Color = Color3.fromRGB(70, 200, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		Parent = env,
	})
	emitter(gate, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(Color3.fromRGB(90, 220, 80), Color3.fromRGB(30, 60, 30)),
		Rate = 12,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Right,
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.3,
	})
	light(gate, Color3.fromRGB(110, 255, 90), 24, 2.5)

	-- Grabsteine, Laternen und Zaun am Rand
	local rng = Random.new(7)
	local x = Layout.LaneMinX + 10
	local i = 0
	while x < Layout.CenterMinX - 4 do
		i += 1
		for _, side in { -1, 1 } do
			local z = side * (halfW - 2.5) + rng:NextNumber(-0.8, 0.8)
			local tilt = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
			local base = CFrame.new(W(x + rng:NextNumber(-2, 2), 0, z)) * tilt
			local stoneColor = Color3.fromRGB(115, 115, 122):Lerp(Color3.fromRGB(80, 85, 80), rng:NextNumber())
			part({ Size = Vector3.new(0.8, 3, 2.6), CFrame = base * CFrame.new(0, 1.5, 0), Color = stoneColor, Material = Enum.Material.Slate, Parent = env })
			part({
				ClassName = "Part",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 2.6, 2.6),
				CFrame = base * CFrame.new(0, 3, 0),
				Color = stoneColor,
				Material = Enum.Material.Slate,
				Parent = env,
			})
		end
		if i % 2 == 0 then
			for _, side in { -1, 1 } do
				local z = side * (halfW - 0.8)
				part({ Size = Vector3.new(0.5, 7, 0.5), Position = W(x, 3.5, z), Color = Color3.fromRGB(35, 35, 40), Material = Enum.Material.Metal, Parent = env })
				local head = part({ Size = Vector3.new(1.2, 1.2, 1.2), Position = W(x, 7.4, z), Color = Color3.fromRGB(170, 255, 120), Material = Enum.Material.Neon, Parent = env })
				light(head, Color3.fromRGB(150, 255, 110), 18, 1.6)
			end
		end
		x += 11
	end

	for _, side in { -1, 1 } do
		local z = side * halfW
		for px = Layout.LaneMinX, Layout.CenterMinX, 4 do
			part({ Size = Vector3.new(0.4, 3.5, 0.4), Position = W(px, 1.75, z), Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.Metal, Parent = env })
		end
		for _, y in { 1.2, 3 } do
			part({ Size = Vector3.new(M.LaneLength, 0.3, 0.3), Position = W(laneX, y, z), Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.Metal, Parent = env })
		end
	end

	-- Bodennebel
	for _, fx in { 0.2, 0.5, 0.8 } do
		local mist = part({
			Name = "Mist",
			Size = Vector3.new(20, 1, M.LaneWidth - 4),
			Position = W(Layout.LaneMinX + M.LaneLength * fx, 0.5, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = env,
		})
		emitter(mist, {
			Texture = TEX.Smoke,
			Color = ColorSequence.new(Color3.fromRGB(150, 190, 150)),
			Rate = 3,
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(0.3, 0.8),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 10) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.82), NumberSequenceKeypoint.new(1, 1) }),
			LightEmission = 0,
			Shape = Enum.ParticleEmitterShape.Box,
		})
	end
end

local function buildCenter(env: Folder, slotFolder: Folder): { [string]: BasePart }
	local halfDepth = M.CenterDepth / 2
	local hw = M.PathHalfWidth
	floor(env, "Center", 0, 0, M.CenterWidth, M.CenterDepth, Color3.fromRGB(78, 135, 62), Enum.Material.Grass)
	stripe(env, 0, 0, M.CenterWidth, hw * 2 - 4, Color3.fromRGB(88, 72, 55), Enum.Material.Ground)

	-- Die Linien = der "Rand" zwischen Weg und Pet-Flaechen
	for _, side in { -1, 1 } do
		stripe(env, 0, side * hw, M.CenterWidth, 1, Color3.fromRGB(225, 215, 190), Enum.Material.Concrete, 0.35)
		-- Hecke aussen
		part({ Size = Vector3.new(M.CenterWidth, 3, 2), Position = W(0, 1.5, side * (halfDepth - 1)), Color = Color3.fromRGB(45, 95, 45), Material = Enum.Material.Grass, Parent = env })
		-- Hecken an den Seiten der Pet-Flaechen
		local bandLen = halfDepth - hw
		for _, xSide in { Layout.CenterMinX + 1, Layout.CenterMaxX - 1 } do
			part({ Size = Vector3.new(2, 3, bandLen), Position = W(xSide, 1.5, side * (hw + bandLen / 2)), Color = Color3.fromRGB(45, 95, 45), Material = Enum.Material.Grass, Parent = env })
		end
	end

	local slots = {}
	for _, slot in Layout.Slots do
		local pos = slot.Position
		local pad = part({
			Name = "Slot_" .. slot.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 8, 8),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(205, 195, 175),
			Material = Enum.Material.Slate,
			Parent = slotFolder,
		})
		pad:SetAttribute("SlotId", slot.Id)
		pad:SetAttribute("Occupied", false)
		local ring = part({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7, 9, 9),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			CanCollide = false,
			CanQuery = false,
			Parent = pad,
		})
		ring:SetAttribute("BaseColor", ring.Color)

		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 300
		click.Parent = pad

		local plus = billboardLabel(pad, "+ Pet", Color3.fromRGB(255, 255, 255), 5)
		plus.Name = "PlusGui"
		plus.StudsOffset = Vector3.new(0, 2.5, 0)
		slots[slot.Id] = pad
	end
	return slots
end

local function buildHut(env: Folder): (Model, Frame, TextLabel)
	local hut = Instance.new("Model")
	hut.Name = "Hut"
	hut.Parent = env

	local areaX = (Layout.HutAreaMinX + Layout.HutAreaMaxX) / 2
	floor(env, "HutArea", areaX, 0, M.HutAreaLength, M.HutAreaWidth, Color3.fromRGB(95, 150, 70), Enum.Material.Grass)
	stripe(env, (Layout.HutAreaMinX + Layout.HutFrontX) / 2, 0, Layout.HutFrontX - Layout.HutAreaMinX, 10, Color3.fromRGB(88, 72, 55), Enum.Material.Ground)

	local cx = Layout.HutCenterX
	local size = Layout.HutSize
	local half = size.X / 2
	local wood = Color3.fromRGB(140, 95, 60)
	local woodMat = Enum.Material.WoodPlanks
	local h = size.Y

	part({ Name = "Floor", Size = Vector3.new(size.X, 0.4, size.Z), Position = W(cx, 0.2, 0), Color = Color3.fromRGB(110, 75, 50), Material = woodMat, Parent = hut })
	part({ Name = "BackWall", Size = Vector3.new(1, h, size.Z), Position = W(cx + half - 0.5, h / 2, 0), Color = wood, Material = woodMat, Parent = hut })
	for _, side in { -1, 1 } do
		part({ Name = "SideWall", Size = Vector3.new(size.X, h, 1), Position = W(cx, h / 2, side * (half - 0.5)), Color = wood, Material = woodMat, Parent = hut })
		-- Vorderwand mit Tueroeffnung (4 breit)
		part({ Name = "FrontWall", Size = Vector3.new(1, h, 6), Position = W(cx - half + 0.5, h / 2, side * 5), Color = wood, Material = woodMat, Parent = hut })
		-- Leuchtende Fenster
		for _, wx in { -3.5, 3.5 } do
			local win = part({ Size = Vector3.new(2.6, 2.6, 0.3), Position = W(cx + wx, 5.5, side * (half + 0.05)), Color = Color3.fromRGB(255, 210, 120), Material = Enum.Material.Neon, Parent = hut })
			win.CanCollide = false
		end
		part({ Size = Vector3.new(0.3, 2.2, 2.2), Position = W(cx - half - 0.05, 5.5, side * 5.5), Color = Color3.fromRGB(255, 210, 120), Material = Enum.Material.Neon, CanCollide = false, Parent = hut })
	end
	part({ Name = "Lintel", Size = Vector3.new(1, 3, 4), Position = W(cx - half + 0.5, h - 1.5, 0), Color = wood, Material = woodMat, Parent = hut })
	part({ Name = "Door", Size = Vector3.new(0.5, 7, 4), Position = W(cx - half + 0.6, 3.5, 0), Color = Color3.fromRGB(90, 58, 35), Material = woodMat, Parent = hut })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Position = W(cx - half + 0.2, 3.5, 1.3), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal, Parent = hut })

	-- Satteldach: zwei Keile, First entlang X
	local roofColor = Color3.fromRGB(160, 60, 45)
	local roofH = 5
	part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(size.X + 2, roofH, size.Z / 2 + 1), CFrame = CFrame.new(W(cx, h + roofH / 2, -(size.Z / 4 + 0.5))), Color = roofColor, Material = Enum.Material.Slate, Parent = hut })
	part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(size.X + 2, roofH, size.Z / 2 + 1), CFrame = CFrame.new(W(cx, h + roofH / 2, size.Z / 4 + 0.5)) * CFrame.Angles(0, math.pi, 0), Color = roofColor, Material = Enum.Material.Slate, Parent = hut })

	local chimney = part({ Name = "Chimney", Size = Vector3.new(2, 6, 2), Position = W(cx + 4, h + 3.5, -3), Color = Color3.fromRGB(150, 80, 65), Material = Enum.Material.Brick, Parent = hut })
	emitter(chimney, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
		Rate = 4,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 3),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(10, 10),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0,
	})

	-- Laterne an der Tuer
	local lantern = part({ Size = Vector3.new(0.8, 1.2, 0.8), Position = W(cx - half - 0.6, 7, -2.8), Color = Color3.fromRGB(255, 170, 70), Material = Enum.Material.Neon, Parent = hut })
	light(lantern, Color3.fromRGB(255, 170, 80), 16, 2)

	-- Zaun rund um den Huettenbereich (Eingang zum Weg bleibt offen)
	local fenceColor = Color3.fromRGB(120, 85, 55)
	local hz = M.HutAreaWidth / 2
	for _, side in { -1, 1 } do
		part({ Size = Vector3.new(M.HutAreaLength, 0.4, 0.4), Position = W(areaX, 2, side * (hz - 0.3)), Color = fenceColor, Material = Enum.Material.Wood, Parent = env })
		for fx = Layout.HutAreaMinX + 2, Layout.HutAreaMaxX, 4 do
			part({ Size = Vector3.new(0.5, 3, 0.5), Position = W(fx, 1.5, side * (hz - 0.3)), Color = fenceColor, Material = Enum.Material.Wood, Parent = env })
		end
	end
	part({ Size = Vector3.new(0.4, 0.4, M.HutAreaWidth), Position = W(Layout.HutAreaMaxX - 0.3, 2, 0), Color = fenceColor, Material = Enum.Material.Wood, Parent = env })

	-- Lebensbalken ueber der Huette
	local anchor = part({ Name = "HealthAnchor", Size = Vector3.new(1, 1, 1), Position = W(cx, h + roofH + 4, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = hut })
	local gui = Instance.new("BillboardGui")
	gui.Name = "HutHealth"
	gui.Size = UDim2.new(14, 0, 3, 0)
	gui.MaxDistance = 300
	gui.LightInfluence = 0
	gui.Parent = anchor
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.45)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.2
	title.Text = "🏠 Hütte"
	title.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.52)
	back.Size = UDim2.fromScale(1, 0.42)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.ZIndex = 2
	text.Parent = back

	hut.PrimaryPart = anchor
	return hut, fill, text
end

local function teleportOnTouch(touchPart: BasePart, target: Vector3)
	local cooldown: { [Player]: number } = {}
	touchPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
		if not player or (cooldown[player] and os.clock() - cooldown[player] < 2) then
			return
		end
		cooldown[player] = os.clock()
		;(character :: Model):PivotTo(CFrame.new(target))
	end)
end

function MapBuilder.Build(): MapRefs
	local old = workspace:FindFirstChild("ZombieDefenseMap")
	if old then
		old:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "ZombieDefenseMap"
	local env = Instance.new("Folder")
	env.Name = "Environment"
	env.Parent = root
	local slotFolder = Instance.new("Folder")
	slotFolder.Name = "Slots"
	slotFolder.Parent = root
	local zombies = Instance.new("Folder")
	zombies.Name = "Zombies"
	zombies.Parent = root
	local pets = Instance.new("Folder")
	pets.Name = "PlacedPets"
	pets.Parent = root

	buildLane(env)
	local slots = buildCenter(env, slotFolder)
	local hutModel, hutFill, hutText = buildHut(env)

	if M.CreateLobbyPortal then
		local portals = Instance.new("Folder")
		portals.Name = "Portals"
		portals.Parent = root
		local toMap = portal(portals, "ZombiePortal", M.LobbyPortalPosition, Color3.fromRGB(110, 255, 90), "🧟 Zombie-Modus")
		teleportOnTouch(toMap, Layout.PlayerSpawn)
		local back = portal(portals, "ReturnPortal", Layout.ReturnPortal, Color3.fromRGB(110, 180, 255), "🏡 Zur Lobby")
		teleportOnTouch(back, M.LobbyPortalPosition + Vector3.new(8, 4, 0))
	end

	root.Parent = workspace

	return {
		Root = root,
		Zombies = zombies,
		PlacedPets = pets,
		Slots = slots,
		HutFill = hutFill,
		HutText = hutText,
		HutModel = hutModel,
	}
end

return MapBuilder
