-- Zombies: bauen, laufen lassen, Schaden, Brennen/Verlangsamen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.ZombieDefense.Config)
local Layout = require(ReplicatedStorage.ZombieDefense.Layout)

export type Zombie = {
	Id: number,
	TypeName: string,
	Model: Model,
	Root: BasePart,
	HealthFill: Frame,
	Health: number,
	MaxHealth: number,
	Speed: number,
	HutDamage: number,
	Scale: number,
	Progress: number, -- 0 = Tor, 1 = Huette
	Offset: number, -- seitlicher Versatz
	SlowUntil: number,
	SlowFactor: number,
	BurnUntil: number,
	BurnDps: number,
	BurnOwner: Player?,
	DamageBy: { [Player]: number }, -- fuer faire Aufteilung der Coins
	Alive: boolean,
}

local ZombieService = {}

local folder: Folder
local remotes: any -- Ordner mit RemoteEvents
local zombies: { [number]: Zombie } = {}
local nextId = 0
local pathLength = (Layout.ZombieEnd - Layout.ZombieStart).Magnitude

-- Wird vom Hauptskript gesetzt
ZombieService.OnKilled = function(_zombie: Zombie) end
ZombieService.OnReachedHut = function(_zombie: Zombie) end
ZombieService.OnDamage = function(_player: Player, _amount: number) end

local function weld(a: BasePart, b: BasePart, name: string, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = a
	m.Part1 = b
	m.C0 = c0
	m.C1 = c1
	m.Parent = a
	return m
end

-- Feste Verbindung ueber C0 (wird von Model:ScaleTo mitskaliert)
local function attach(part0: BasePart, part1: BasePart, offset: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = offset
	w.Parent = part1
end

local function newPart(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Blockiger Zombie mit Gelenken (die Laufanimation macht der Client)
local function buildModel(typeName: string, def: any): (Model, BasePart, Frame)
	local model = Instance.new("Model")
	model.Name = typeName

	local root = newPart(model, "Root", Vector3.new(2, 2, 1), Color3.new(), nil)
	root.Transparency = 1
	root.Anchored = true

	local torso = newPart(model, "Torso", Vector3.new(2, 2, 1), def.Shirt)
	local head = newPart(model, "Head", Vector3.new(1.25, 1.25, 1.25), def.Skin)
	local lArm = newPart(model, "LeftArm", Vector3.new(1, 2, 1), def.Skin)
	local rArm = newPart(model, "RightArm", Vector3.new(1, 2, 1), def.Skin)
	local lLeg = newPart(model, "LeftLeg", Vector3.new(1, 2, 1), def.Pants)
	local rLeg = newPart(model, "RightLeg", Vector3.new(1, 2, 1), def.Pants)

	weld(root, torso, "RootJoint", CFrame.new(), CFrame.new())
	weld(torso, head, "Neck", CFrame.new(0, 1, 0), CFrame.new(0, -0.625, 0))
	-- Arme nach vorne gestreckt (typische Zombie-Haltung)
	local armPose = CFrame.Angles(math.rad(90), 0, 0)
	weld(torso, lArm, "LeftShoulder", CFrame.new(-1.5, 0.5, 0) * armPose, CFrame.new(0, 0.5, 0))
	weld(torso, rArm, "RightShoulder", CFrame.new(1.5, 0.5, 0) * armPose, CFrame.new(0, 0.5, 0))
	weld(torso, lLeg, "LeftHip", CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	weld(torso, rLeg, "RightHip", CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))

	-- Leuchtende Augen
	for _, x in { -0.28, 0.28 } do
		local eye = newPart(model, "Eye", Vector3.new(0.25, 0.2, 0.1), def.Eyes, Enum.Material.Neon)
		attach(head, eye, CFrame.new(x, 0.12, -0.63))
	end
	-- Zerrissenes Hemd: ein dunkler Fleck
	local rip = newPart(model, "Rip", Vector3.new(0.8, 0.6, 0.05), def.Shirt:Lerp(Color3.new(), 0.45))
	attach(torso, rip, CFrame.new(0.3, -0.4, -0.52))

	if def.IsBoss then
		-- Hoerner + Aura fuer den Boss
		for _, x in { -0.45, 0.45 } do
			local horn = newPart(model, "Horn", Vector3.new(0.3, 0.8, 0.3), Color3.fromRGB(240, 230, 200))
			attach(head, horn, CFrame.new(x, 0.9, 0) * CFrame.Angles(0, 0, if x > 0 then -0.35 else 0.35))
		end
		local aura = Instance.new("ParticleEmitter")
		aura.Texture = Config.VFX.Textures.Smoke
		aura.Color = ColorSequence.new(Color3.fromRGB(160, 60, 255), Color3.fromRGB(40, 0, 60))
		aura.Rate = 10
		aura.Lifetime = NumberRange.new(1, 1.6)
		aura.Speed = NumberRange.new(1, 2)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3) })
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		aura.LightEmission = 0.6
		aura.Parent = torso
	end

	-- Lebensbalken
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.new(if def.IsBoss then 4 else 2.6, 0, if def.IsBoss then 0.5 else 0.32, 0)
	gui.StudsOffset = Vector3.new(0, 1.3, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	gui.Parent = head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if def.IsBoss then Color3.fromRGB(190, 70, 255) else Color3.fromRGB(110, 230, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	if def.IsBoss then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1.2, 0)
		label.Position = UDim2.fromScale(0, -1.3)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(230, 170, 255)
		label.TextStrokeTransparency = 0
		label.Text = "👑 BOSS"
		label.Parent = gui
	end

	model.PrimaryPart = root
	return model, root, fill
end

local function positionAt(z: Zombie): CFrame
	local flat = Layout.ZombieStart:Lerp(Layout.ZombieEnd, z.Progress)
	local pos = flat + Vector3.new(0, 3 * z.Scale, z.Offset)
	-- Blick Richtung Huette (+X)
	return CFrame.lookAt(pos, pos + Vector3.xAxis)
end

local function updateHealthBar(z: Zombie)
	local ratio = math.clamp(z.Health / z.MaxHealth, 0, 1)
	z.HealthFill.Size = UDim2.fromScale(ratio, 1)
	if not Config.ZombieTypes[z.TypeName].IsBoss then
		z.HealthFill.BackgroundColor3 = Color3.fromRGB(230, 60, 50):Lerp(Color3.fromRGB(110, 230, 90), ratio)
	end
end

function ZombieService.Init(zombieFolder: Folder, remoteFolder: any)
	folder = zombieFolder
	remotes = remoteFolder
	RunService.Heartbeat:Connect(ZombieService.Step)
end

function ZombieService.Spawn(typeName: string, wave: number): Zombie
	local def = Config.ZombieTypes[typeName]
	nextId += 1
	local model, root, fill = buildModel(typeName, def)
	local w = wave - 1
	local healthMult = 1 + w * Config.Waves.HealthGrowthPerWave + w * w * (Config.Waves.HealthGrowthQuadratic or 0)
	local maxHealth = math.floor(def.Health * healthMult + 0.5)

	local z: Zombie = {
		Id = nextId,
		TypeName = typeName,
		Model = model,
		Root = root,
		HealthFill = fill,
		Health = maxHealth,
		MaxHealth = maxHealth,
		Speed = def.Speed,
		HutDamage = def.HutDamage,
		Scale = def.Scale,
		Progress = 0,
		Offset = if def.IsBoss then 0 else (math.random() * 2 - 1) * Layout.ZombieSpreadZ,
		SlowUntil = 0,
		SlowFactor = 1,
		BurnUntil = 0,
		BurnDps = 0,
		BurnOwner = nil,
		DamageBy = {},
		Alive = true,
	}

	if def.Scale ~= 1 then
		model:ScaleTo(def.Scale)
	end
	model.Name = "Z" .. z.Id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- immer komplett laden
	model:SetAttribute("ZombieId", z.Id)
	model:SetAttribute("ZombieType", typeName)
	model:SetAttribute("Speed", def.Speed)
	model:PivotTo(positionAt(z))
	model.Parent = folder
	zombies[z.Id] = z
	return z
end

local function kill(z: Zombie)
	if not z.Alive then
		return
	end
	z.Alive = false
	zombies[z.Id] = nil
	z.Model:SetAttribute("Dead", true)
	remotes.ZombieDied:FireAllClients(z.Id, z.Root.Position, z.TypeName)
	ZombieService.OnKilled(z)
	-- Kurz warten, damit der Client den Aufloese-Effekt zeigen kann
	task.delay(0.6, function()
		z.Model:Destroy()
	end)
end

-- Fuegt Schaden zu; gibt true zurueck, wenn der Zombie gestorben ist
function ZombieService.Damage(z: Zombie, amount: number, owner: Player?, element: string, isCrit: boolean): boolean
	if not z.Alive or amount <= 0 then
		return false
	end
	-- Nur echten Schaden zaehlen (Overkill nicht)
	local dealt = math.min(amount, z.Health)
	z.Health -= amount
	if owner then
		z.DamageBy[owner] = (z.DamageBy[owner] or 0) + dealt
		ZombieService.OnDamage(owner, dealt)
	end
	remotes.Damage:FireAllClients(z.Id, math.floor(amount + 0.5), element, isCrit)
	if z.Health <= 0 then
		kill(z)
		return true
	end
	updateHealthBar(z)
	return false
end

function ZombieService.ApplySlow(z: Zombie, factor: number, duration: number)
	z.SlowFactor = math.min(z.SlowFactor, factor)
	z.SlowUntil = math.max(z.SlowUntil, os.clock() + duration)
	z.Model:SetAttribute("Slowed", true)
end

function ZombieService.ApplyBurn(z: Zombie, dps: number, duration: number, owner: Player?)
	z.BurnDps = math.max(z.BurnDps, dps)
	z.BurnUntil = math.max(z.BurnUntil, os.clock() + duration)
	z.BurnOwner = owner
	z.Model:SetAttribute("Burning", true)
end

local burnAccumulator = 0

function ZombieService.Step(dt: number)
	local now = os.clock()
	burnAccumulator += dt
	local burnTick = burnAccumulator >= 0.5
	if burnTick then
		burnAccumulator = 0
	end

	for _, z in zombies do
		if not z.Alive then
			continue
		end

		if z.SlowUntil > 0 and now >= z.SlowUntil then
			z.SlowUntil = 0
			z.SlowFactor = 1
			z.Model:SetAttribute("Slowed", false)
		end

		if burnTick and z.BurnUntil > 0 then
			if now >= z.BurnUntil then
				z.BurnUntil = 0
				z.BurnDps = 0
				z.Model:SetAttribute("Burning", false)
			elseif ZombieService.Damage(z, z.BurnDps * 0.5, z.BurnOwner, "Fire", false) then
				continue
			end
		end

		z.Progress += z.Speed * z.SlowFactor * dt / pathLength
		if z.Progress >= 1 then
			z.Alive = false
			zombies[z.Id] = nil
			remotes.HutHit:FireAllClients(z.Root.Position, z.HutDamage)
			ZombieService.OnReachedHut(z)
			z.Model:Destroy()
		else
			z.Model:PivotTo(positionAt(z))
		end
	end
end

-- Lebende Zombies in Reichweite (nur waagerechter Abstand)
function ZombieService.InRange(position: Vector3, range: number): { Zombie }
	local result = {}
	local flatPos = Vector3.new(position.X, 0, position.Z)
	for _, z in zombies do
		if z.Alive then
			local p = z.Root.Position
			if (Vector3.new(p.X, 0, p.Z) - flatPos).Magnitude <= range then
				table.insert(result, z)
			end
		end
	end
	return result
end

function ZombieService.AliveCount(): number
	local n = 0
	for _ in zombies do
		n += 1
	end
	return n
end

function ZombieService.ClearAll()
	for id, z in zombies do
		z.Alive = false
		z.Model:Destroy()
		zombies[id] = nil
	end
end

return ZombieService
