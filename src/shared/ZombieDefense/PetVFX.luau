-- Effekte fuer Pets und Zombies (laeuft nur auf dem Client).
-- Ideen aus Tower-Defense-Spielen: Muendungsblitz beim Schiessen, Geschoss mit
-- Schweif, kurzer Partikel-Burst beim Treffer (Emit statt Dauer-Emitter),
-- aufblitzende Neon-Kugel + Speed-Lines (Anime-Stil), Schadenszahlen,
-- Aura je nach Seltenheit.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)

local TEX = Config.VFX.Textures
local PetVFX = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ZombieDefenseFX"
fxFolder.Parent = workspace

--------------------------------------------------------------------------
-- Bausteine
--------------------------------------------------------------------------

local function elementColor(element: string): Color3
	local e = Config.Elements[element]
	return if e then e.Color else Color3.new(1, 1, 1)
end

local function rarityColor(rarity: string): Color3
	local r = Config.Rarities[rarity]
	return if r then r.Color else Color3.new(1, 1, 1)
end

local function rarityOrder(rarity: string): number
	local r = Config.Rarities[rarity]
	return if r then r.Order else 1
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function fxPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or fxFolder
	return p
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function colorSeq(a: Color3, b: Color3?): ColorSequence
	return ColorSequence.new(a, b or a)
end

-- Einmaliger Partikel-Burst an einer Position
local function burst(position: Vector3, opts: { [string]: any })
	local holder = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = opts.Texture or TEX.Sparkle
	e.Color = opts.Color or colorSeq(Color3.new(1, 1, 1))
	e.Size = opts.Size or seq(1, 0)
	e.Transparency = opts.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = opts.Lifetime or NumberRange.new(0.2, 0.6)
	e.Speed = opts.Speed or NumberRange.new(20, 40)
	e.SpreadAngle = opts.Spread or Vector2.new(180, 180)
	e.Drag = opts.Drag or 8
	e.LightEmission = opts.LightEmission or 1
	e.Acceleration = opts.Acceleration or Vector3.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = opts.RotSpeed or NumberRange.new(-180, 180)
	e.EmissionDirection = opts.Direction or Enum.NormalId.Top
	e.Parent = holder
	e:Emit(opts.Count or 16)
	-- Erst nach der Lebenszeit loeschen, sonst verschwinden die Partikel sofort
	Debris:AddItem(holder, e.Lifetime.Max + 0.3)
end

-- Aufblitzende Neon-Kugel
local function flash(position: Vector3, color: Color3, fromSize: number, toSize: number, duration: number)
	local ball = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * fromSize,
		Position = position,
		Color = color,
		Transparency = 0.1,
	})
	tween(ball, duration, { Size = Vector3.one * toSize, Transparency = 1 })
	Debris:AddItem(ball, duration + 0.05)
end

local function flashLight(position: Vector3, color: Color3, range: number, brightness: number, duration: number)
	local holder = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Transparency = 1 })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = holder
	tween(l, duration, { Brightness = 0 })
	Debris:AddItem(holder, duration + 0.05)
end

-- Echter Ring aus Segmenten, der sich ausbreitet (Schockwelle)
local function ring(position: Vector3, color: Color3, fromRadius: number, toRadius: number, duration: number, segments: number?)
	local n = segments or 16
	for i = 1, n do
		local angle = (i / n) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local function cf(radius: number)
			local p = position + dir * radius
			return CFrame.lookAt(p, p + dir) * CFrame.Angles(0, math.pi / 2, 0)
		end
		local len0 = 2 * math.pi * fromRadius / n * 1.1
		local len1 = 2 * math.pi * toRadius / n * 1.1
		local seg = fxPart({ Size = Vector3.new(0.35, 0.35, len0), CFrame = cf(fromRadius), Color = color, Transparency = 0.05 })
		tween(seg, duration, { CFrame = cf(toRadius), Size = Vector3.new(0.12, 0.12, len1), Transparency = 1 })
		Debris:AddItem(seg, duration + 0.05)
	end
end

-- Anime-Speed-Lines vom Treffpunkt nach aussen
local function speedLines(position: Vector3, color: Color3, count: number, length: number, duration: number)
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.2, math.random() - 0.5).Unit
		local start = position + dir * 0.5
		local line = fxPart({ Size = Vector3.new(0.15, 0.15, length), CFrame = CFrame.lookAt(start + dir * length / 2, start + dir * length), Color = color, Transparency = 0 })
		local finish = position + dir * (length * 1.8)
		tween(line, duration, { CFrame = CFrame.lookAt(finish, finish + dir), Size = Vector3.new(0.05, 0.05, length * 0.3), Transparency = 1 })
		Debris:AddItem(line, duration + 0.05)
	end
end

-- Kleine Splitter (Eis, Holz), die wegfliegen
local function shards(position: Vector3, color: Color3, count: number, material: Enum.Material?)
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.9 + 0.2, math.random() - 0.5).Unit
		local s = fxPart({
			Size = Vector3.new(0.3, 0.3, 0.9) * (0.6 + math.random() * 0.6),
			CFrame = CFrame.lookAt(position, position + dir),
			Color = color,
			Material = material or Enum.Material.Neon,
			Transparency = 0.1,
		})
		local target = position + dir * (3 + math.random() * 3)
		tween(s, 0.45, { CFrame = CFrame.lookAt(target, target + dir) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Transparency = 1 })
		Debris:AddItem(s, 0.5)
	end
end

-- Zickzack-Blitz zwischen zwei Punkten
local function bolt(a: Vector3, b: Vector3, color: Color3, width: number)
	local dist = (b - a).Magnitude
	local n = math.max(3, math.floor(dist / 3))
	local points = { a }
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = side:Cross(dir).Unit
	for i = 1, n - 1 do
		local jitter = (side * (math.random() - 0.5) + up * (math.random() - 0.5)) * 2.2
		table.insert(points, a:Lerp(b, i / n) + jitter)
	end
	table.insert(points, b)
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		local len = (p1 - p0).Magnitude
		local mid = (p0 + p1) / 2
		local core = fxPart({ Size = Vector3.new(width, width, len), CFrame = CFrame.lookAt(mid, p1), Color = Color3.new(1, 1, 1) })
		local glow = fxPart({ Size = Vector3.new(width * 3, width * 3, len), CFrame = CFrame.lookAt(mid, p1), Color = color, Transparency = 0.55 })
		tween(core, 0.18, { Transparency = 1 })
		tween(glow, 0.22, { Transparency = 1, Size = Vector3.new(width * 5, width * 5, len) })
		Debris:AddItem(core, 0.2)
		Debris:AddItem(glow, 0.25)
	end
end

local function billboardAt(position: Vector3, size: UDim2): (BillboardGui, BasePart)
	local holder = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Adornee = holder
	gui.Parent = holder
	return gui, holder
end

--------------------------------------------------------------------------
-- Treffer
--------------------------------------------------------------------------

function PetVFX.Impact(position: Vector3, element: string, rarity: string, isCrit: boolean)
	local color = elementColor(element)
	local order = rarityOrder(rarity)
	local scale = 1 + order * 0.12 + (if isCrit then 0.5 else 0)

	flash(position, color, 0.8, 3.5 * scale, 0.18)
	flash(position, Color3.new(1, 1, 1), 0.4, 1.8 * scale, 0.1)
	burst(position, {
		Color = colorSeq(Color3.new(1, 1, 1), color),
		Count = 10 + order * 3,
		Size = seq(0.6 * scale, 0),
		Speed = NumberRange.new(18, 34),
	})
	flashLight(position, color, 10 * scale, 3, 0.25)

	if element == "Fire" then
		burst(position, {
			Texture = TEX.Fire,
			Color = colorSeq(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 20)),
			Count = 10 + order * 2,
			Size = seq(2 * scale, 0),
			Speed = NumberRange.new(6, 14),
			Lifetime = NumberRange.new(0.3, 0.6),
			Acceleration = Vector3.new(0, 12, 0),
		})
		burst(position, {
			Texture = TEX.Smoke,
			Color = colorSeq(Color3.fromRGB(80, 70, 60)),
			Count = 4,
			Size = seq(1.5, 3.5),
			Speed = NumberRange.new(2, 5),
			Lifetime = NumberRange.new(0.6, 1),
			LightEmission = 0,
			Transparency = seq(0.4, 1),
		})
	elseif element == "Ice" then
		ring(position - Vector3.new(0, 1.5, 0), color, 0.5, 4 * scale, 0.35, 14)
		shards(position, color, 5 + order)
		burst(position, { Color = colorSeq(Color3.new(1, 1, 1), color), Count = 8, Speed = NumberRange.new(3, 8), Lifetime = NumberRange.new(0.6, 1), Acceleration = Vector3.new(0, -10, 0) })
	elseif element == "Lightning" then
		speedLines(position, color, 6 + order, 2.5, 0.2)
		flash(position, Color3.new(1, 1, 0.8), 1, 5 * scale, 0.08)
	elseif element == "Magic" then
		local radius = Config.Elements.Magic.SplashRadius
		ring(position - Vector3.new(0, 1.5, 0), color, 0.5, radius, 0.4, 20)
		burst(position, {
			Color = colorSeq(Color3.fromRGB(255, 150, 240), color),
			Count = 18 + order * 2,
			Size = seq(0.9, 0),
			Speed = NumberRange.new(8, 20),
			Lifetime = NumberRange.new(0.4, 0.8),
			Acceleration = Vector3.new(0, 6, 0),
		})
	end

	if isCrit then
		speedLines(position, Color3.new(1, 1, 1), 8, 3, 0.22)
		ring(position, Color3.fromRGB(255, 230, 120), 0.5, 3.5, 0.25, 12)
	end
end

--------------------------------------------------------------------------
-- Angriff (Muendungsblitz + Geschoss + Treffer)
--------------------------------------------------------------------------

type Projectile = {
	Part: BasePart,
	From: Vector3,
	GetTarget: () -> Vector3,
	Start: number,
	Duration: number,
	Element: string,
	Rarity: string,
	Crit: boolean,
	Seed: number,
}

local projectiles: { Projectile } = {}

local function makeProjectile(element: string, rarity: string, from: Vector3): BasePart
	local color = elementColor(element)
	local order = rarityOrder(rarity)
	local size = 0.8 + order * 0.15
	local p: BasePart
	if element == "Ice" then
		p = fxPart({ Size = Vector3.new(size * 0.6, size * 0.6, size * 2), Position = from, Color = color, Material = Enum.Material.Glass, Transparency = 0.15 })
	else
		p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Position = from, Color = color })
	end

	-- Schweif
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.45, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.45, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = colorSeq(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = seq(1, 0)
	trail.Lifetime = 0.18 + order * 0.03
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = p

	-- Partikel hinter dem Geschoss
	local e = Instance.new("ParticleEmitter")
	e.Texture = if element == "Fire" then TEX.Fire else TEX.Sparkle
	e.Color = if element == "Fire" then colorSeq(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 60, 10)) else colorSeq(Color3.new(1, 1, 1), color)
	e.Size = seq(if element == "Fire" then size * 1.6 else size * 0.7, 0)
	e.Transparency = seq(0, 1)
	e.Lifetime = NumberRange.new(0.2, 0.4)
	e.Rate = 30 + order * 8
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Parent = p

	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 6 + order
	l.Brightness = 2
	l.Parent = p
	return p
end

-- data: Tabelle vom Server (siehe PetService.attack)
-- getTargetPosition: liefert die aktuelle Position des Ziels (fuer Zielsuche)
function PetVFX.Attack(data: { [string]: any }, getTargetPosition: (() -> Vector3?)?)
	local element: string = data.Element
	local rarity: string = data.Rarity
	local from: Vector3 = data.From
	local to: Vector3 = data.To
	local color = elementColor(element)
	local order = rarityOrder(rarity)

	-- Muendungsblitz am Pet
	flash(from, color, 0.6, 2 + order * 0.3, 0.14)
	burst(from, { Color = colorSeq(Color3.new(1, 1, 1), color), Count = 4 + order, Size = seq(0.4, 0), Speed = NumberRange.new(6, 12), Lifetime = NumberRange.new(0.15, 0.3) })

	if element == "Lightning" then
		bolt(from, to, color, 0.18 + order * 0.03)
		task.delay(0.05, function()
			bolt(from, to, color, 0.12)
		end)
		local prev = to
		for _, pos in data.Chain or {} do
			bolt(prev, pos, color, 0.14)
			PetVFX.Impact(pos, element, rarity, false)
			prev = pos
		end
		PetVFX.Impact(to, element, rarity, data.Crit)
		return
	end

	if #projectiles >= Config.VFX.MaxActiveProjectiles then
		task.delay(data.Travel, PetVFX.Impact, to, element, rarity, data.Crit)
		return
	end

	local lastKnown = to
	table.insert(projectiles, {
		Part = makeProjectile(element, rarity, from),
		From = from,
		GetTarget = function()
			local p = getTargetPosition and getTargetPosition()
			if p then
				lastKnown = p
			end
			return lastKnown
		end,
		Start = os.clock(),
		Duration = math.max(data.Travel, 0.05),
		Element = element,
		Rarity = rarity,
		Crit = data.Crit,
		Seed = math.random() * 10,
	})
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		local alpha = math.clamp((now - pr.Start) / pr.Duration, 0, 1)
		local target = pr.GetTarget()
		local pos = pr.From:Lerp(target, alpha)
		local dir = (target - pr.From)
		-- Bogen nach oben; Magie fliegt in einer Spirale
		pos += Vector3.new(0, math.sin(alpha * math.pi) * math.min(dir.Magnitude * 0.12, 4), 0)
		if pr.Element == "Magic" and dir.Magnitude > 0.1 then
			local side = dir.Unit:Cross(Vector3.yAxis)
			if side.Magnitude > 0.01 then
				pos += side.Unit * math.sin(alpha * math.pi * 3 + pr.Seed) * 1.2 * (1 - alpha)
			end
		end
		local look = if (pos - pr.Part.Position).Magnitude > 0.01 then pos + (pos - pr.Part.Position) else pos + Vector3.xAxis
		pr.Part.CFrame = CFrame.lookAt(pos, look)

		if alpha >= 1 then
			table.remove(projectiles, i)
			PetVFX.Impact(target, pr.Element, pr.Rarity, pr.Crit)
			-- Schweif ausklingen lassen
			pr.Part.Transparency = 1
			for _, d in pr.Part:GetChildren() do
				if d:IsA("ParticleEmitter") then
					d.Enabled = false
				elseif d:IsA("PointLight") then
					d.Enabled = false
				end
			end
			Debris:AddItem(pr.Part, 0.5)
		end
	end
end)

--------------------------------------------------------------------------
-- Schadenszahlen und Coins
--------------------------------------------------------------------------

local function popText(position: Vector3, text: string, color: Color3, scale: number, rise: number, duration: number)
	local gui, holder = billboardAt(position + Vector3.new((math.random() - 0.5) * 1.5, 1, (math.random() - 0.5) * 1.5), UDim2.fromScale(4 * scale, 1.6 * scale))
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.3
	uiScale.Parent = label
	tween(uiScale, 0.15, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		tween(uiScale, 0.1, { Scale = 1 })
	end)
	tween(gui, duration, { StudsOffset = Vector3.new(0, rise, 0) }, Enum.EasingStyle.Quad)
	task.delay(duration * 0.55, function()
		tween(label, duration * 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(holder, duration + 0.05)
end

function PetVFX.DamageNumber(position: Vector3, amount: number, element: string, isCrit: boolean)
	if not Config.VFX.ShowDamageNumbers then
		return
	end
	if isCrit then
		popText(position, "KRIT! " .. amount, Color3.fromRGB(255, 90, 60), 1.5, 4, 0.9)
	else
		popText(position, tostring(amount), elementColor(element):Lerp(Color3.new(1, 1, 1), 0.3), 1, 3, 0.7)
	end
end

function PetVFX.CoinPop(position: Vector3, amount: number)
	popText(position + Vector3.new(0, 1.5, 0), ("+%d 💰"):format(amount), Color3.fromRGB(255, 215, 60), 1.3, 5, 1.1)
	local coin = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 1.4, 1.4),
		Position = position,
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
	})
	tween(coin, 0.8, { CFrame = CFrame.new(position + Vector3.new(0, 6, 0)) * CFrame.Angles(0, math.pi * 4, 0), Transparency = 1 })
	Debris:AddItem(coin, 0.85)
	burst(position, { Color = colorSeq(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 190, 30)), Count = 10, Size = seq(0.5, 0), Speed = NumberRange.new(6, 14) })
end

--------------------------------------------------------------------------
-- Pets: Aura, Erscheinen
--------------------------------------------------------------------------

export type AuraHandle = {
	Update: (t: number) -> (),
	Destroy: () -> (),
}

function PetVFX.Aura(model: Model, padPosition: Vector3): AuraHandle
	local rarity = model:GetAttribute("Rarity") or "Common"
	local element = model:GetAttribute("Element") or "Normal"
	local order = rarityOrder(rarity)
	local rColor = rarityColor(rarity)
	local eColor = elementColor(element)
	local cleanup: { Instance } = {}

	local cf, size = model:GetBoundingBox()
	-- Unsichtbarer Anker im Model, damit Effekte mitschweben
	local anchor = fxPart({ Name = "AuraAnchor", Size = size * 0.8, CFrame = cf, Transparency = 1, Parent = model })
	table.insert(cleanup, anchor)

	local main = Instance.new("ParticleEmitter")
	main.Texture = TEX.Sparkle
	main.Color = colorSeq(Color3.new(1, 1, 1), rColor)
	main.Size = seq(0.3 + order * 0.08, 0)
	main.Transparency = seq(0.1, 1)
	main.Lifetime = NumberRange.new(0.8, 1.4)
	main.Rate = 2 + order * 3
	main.Speed = NumberRange.new(0.5, 1.5)
	main.SpreadAngle = Vector2.new(180, 180)
	main.Acceleration = Vector3.new(0, 1 + order * 0.6, 0)
	main.LightEmission = 1
	main.Shape = Enum.ParticleEmitterShape.Box
	main.Parent = anchor

	-- Element-Partikel
	if element ~= "Normal" then
		local e = Instance.new("ParticleEmitter")
		e.LightEmission = 1
		e.Rotation = NumberRange.new(0, 360)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Parent = anchor
		if element == "Fire" then
			e.Texture = TEX.Fire
			e.Color = colorSeq(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 60, 10))
			e.Size = seq(0.7, 0)
			e.Lifetime = NumberRange.new(0.4, 0.8)
			e.Rate = 8
			e.Speed = NumberRange.new(1, 3)
			e.Acceleration = Vector3.new(0, 6, 0)
		elseif element == "Ice" then
			e.Texture = TEX.Sparkle
			e.Color = colorSeq(Color3.new(1, 1, 1), eColor)
			e.Size = seq(0.35, 0.1)
			e.Lifetime = NumberRange.new(1, 1.6)
			e.Rate = 6
			e.Speed = NumberRange.new(0.2, 0.6)
			e.Acceleration = Vector3.new(0, -2, 0)
			e.RotSpeed = NumberRange.new(-60, 60)
		elseif element == "Lightning" then
			e.Texture = TEX.Sparkle
			e.Color = colorSeq(Color3.new(1, 1, 1), eColor)
			e.Size = seq(0.5, 0)
			e.Lifetime = NumberRange.new(0.08, 0.15)
			e.Rate = 10
			e.Speed = NumberRange.new(8, 14)
			e.SpreadAngle = Vector2.new(180, 180)
		elseif element == "Magic" then
			e.Texture = TEX.Sparkle
			e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 240)), ColorSequenceKeypoint.new(1, eColor) })
			e.Size = seq(0.45, 0)
			e.Lifetime = NumberRange.new(0.8, 1.2)
			e.Rate = 7
			e.Speed = NumberRange.new(0.5, 1)
			e.RotSpeed = NumberRange.new(-120, 120)
			e.Acceleration = Vector3.new(0, 2, 0)
		end
	end

	if order >= 3 then
		local l = Instance.new("PointLight")
		l.Color = rColor
		l.Range = 6 + order * 2
		l.Brightness = 1 + order * 0.25
		l.Shadows = false
		l.Parent = anchor
	end

	-- Leuchtkreis unter dem Pet
	local circle = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 6.5, 6.5),
		CFrame = CFrame.new(padPosition + Vector3.new(0, 0.85, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rColor,
		Transparency = 0.55,
	})
	table.insert(cleanup, circle)

	-- Ab Legendary: Lichtsaeule und Umriss
	local highlight: Highlight? = nil
	if order >= 5 then
		local pillar = fxPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 3, 3),
			CFrame = CFrame.new(padPosition + Vector3.new(0, 7.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rColor,
			Transparency = 0.85,
		})
		table.insert(cleanup, pillar)
		local h = Instance.new("Highlight")
		h.Adornee = model
		h.FillTransparency = 1
		h.OutlineColor = rColor
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = anchor
		highlight = h
	end

	-- Mythic: Kugeln, die um das Pet kreisen
	local orbs: { BasePart } = {}
	if order >= 6 then
		for i = 1, 3 do
			local orb = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Position = cf.Position, Color = rColor })
			local trail0 = Instance.new("Attachment")
			trail0.Position = Vector3.new(0, 0.25, 0)
			trail0.Parent = orb
			local trail1 = Instance.new("Attachment")
			trail1.Position = Vector3.new(0, -0.25, 0)
			trail1.Parent = orb
			local trail = Instance.new("Trail")
			trail.Attachment0 = trail0
			trail.Attachment1 = trail1
			trail.Lifetime = 0.3
			trail.LightEmission = 1
			trail.FaceCamera = true
			trail.Transparency = seq(0.2, 1)
			trail.Parent = orb
			orb:SetAttribute("Index", i)
			table.insert(orbs, orb)
			table.insert(cleanup, orb)
		end
	end

	local rainbow = order >= 6
	local handle: AuraHandle = {
		Update = function(t: number)
			circle.Transparency = 0.55 + math.sin(t * 3) * 0.15
			if rainbow then
				local c = Color3.fromHSV((t * 0.25) % 1, 0.7, 1)
				main.Color = colorSeq(Color3.new(1, 1, 1), c)
				circle.Color = c
				if highlight then
					highlight.OutlineColor = c
				end
				local center = anchor.Position
				for i, orb in orbs do
					local a = t * 2.5 + i * (math.pi * 2 / #orbs)
					orb.Position = center + Vector3.new(math.cos(a) * 3, math.sin(t * 3 + i) * 0.8, math.sin(a) * 3)
					orb.Color = c
				end
			end
		end,
		Destroy = function()
			for _, inst in cleanup do
				inst:Destroy()
			end
		end,
	}
	return handle
end

function PetVFX.Spawn(model: Model, padPosition: Vector3)
	local rarity = model:GetAttribute("Rarity") or "Common"
	local order = rarityOrder(rarity)
	local color = rarityColor(rarity)
	local ground = padPosition + Vector3.new(0, 1, 0)

	-- Lichtsaeule
	local pillar = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(30, 4 + order, 4 + order),
		CFrame = CFrame.new(ground + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.2,
	})
	tween(pillar, 0.6, { Size = Vector3.new(30, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	Debris:AddItem(pillar, 0.65)

	ring(ground, color, 1, 7 + order, 0.5, 18)
	if order >= 4 then
		task.delay(0.12, ring, ground, Color3.new(1, 1, 1), 1, 10 + order, 0.55, 22)
	end
	burst(ground, {
		Color = colorSeq(Color3.new(1, 1, 1), color),
		Count = 20 + order * 8,
		Size = seq(0.8, 0),
		Speed = NumberRange.new(10, 25),
		Lifetime = NumberRange.new(0.5, 1),
		Spread = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -15, 0),
	})
	flash(ground + Vector3.new(0, 3, 0), color, 1, 7 + order, 0.3)
	flashLight(ground, color, 20, 4, 0.6)
	if order >= 5 then
		speedLines(ground + Vector3.new(0, 3, 0), color, 12, 4, 0.35)
	end
end

--------------------------------------------------------------------------
-- Zombies: Laufanimation, Treffer-Aufblitzen, Status, Tod
--------------------------------------------------------------------------

export type ZombieVisual = {
	Model: Model,
	Animate: (t: number) -> (),
	Flash: () -> (),
	SetSlowed: (on: boolean) -> (),
	SetBurning: (on: boolean) -> (),
	Die: () -> (),
}

local ICE = Color3.fromRGB(140, 210, 255)

function PetVFX.Zombie(model: Model): ZombieVisual
	local torso = model:WaitForChild("Torso", 5) :: BasePart?
	local parts: { { Part: BasePart, Color: Color3 } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Name ~= "Eye" then
			table.insert(parts, { Part = d, Color = d.Color })
		end
	end
	local function joint(name: string): Motor6D?
		return if torso then torso:FindFirstChild(name) :: Motor6D? else nil
	end
	local rootPart = model:FindFirstChild("Root")
	local rootJoint = if rootPart then rootPart:FindFirstChild("RootJoint") :: Motor6D? else nil
	local neck, lArm, rArm, lLeg, rLeg = joint("Neck"), joint("LeftShoulder"), joint("RightShoulder"), joint("LeftHip"), joint("RightHip")

	local speed = model:GetAttribute("Speed") or 5
	local seed = math.random() * 10
	local slowed, flashing, dead = false, false, false
	local frost: ParticleEmitter? = nil
	local fire: ParticleEmitter? = nil

	local function recolor()
		for _, entry in parts do
			local c = entry.Color
			if slowed then
				c = c:Lerp(ICE, 0.55)
			end
			if flashing then
				c = c:Lerp(Color3.new(1, 1, 1), 0.75)
			end
			entry.Part.Color = c
		end
	end

	local visual: ZombieVisual = {
		Model = model,
		Animate = function(t: number)
			if dead then
				return
			end
			local rate = speed * 0.9 * (if slowed then 0.5 else 1)
			local phase = t * rate + seed
			local swing = math.sin(phase) * 0.7
			if lLeg then
				lLeg.Transform = CFrame.Angles(swing, 0, 0)
			end
			if rLeg then
				rLeg.Transform = CFrame.Angles(-swing, 0, 0)
			end
			if lArm then
				lArm.Transform = CFrame.Angles(math.sin(phase + 1) * 0.15, 0, 0.05)
			end
			if rArm then
				rArm.Transform = CFrame.Angles(math.sin(phase + 2.5) * 0.15, 0, -0.05)
			end
			if neck then
				neck.Transform = CFrame.Angles(math.sin(phase * 0.5) * 0.1, 0, 0.3 + math.sin(phase * 0.7) * 0.1)
			end
			if rootJoint then
				rootJoint.Transform = CFrame.new(0, math.abs(math.sin(phase)) * 0.15, 0) * CFrame.Angles(0, 0, math.sin(phase) * 0.08)
			end
		end,
		Flash = function()
			if dead then
				return
			end
			flashing = true
			recolor()
			task.delay(0.07, function()
				flashing = false
				if not dead then
					recolor()
				end
			end)
		end,
		SetSlowed = function(on: boolean)
			slowed = on
			recolor()
			if on and not frost and torso then
				local e = Instance.new("ParticleEmitter")
				e.Texture = TEX.Sparkle
				e.Color = colorSeq(Color3.new(1, 1, 1), ICE)
				e.Size = seq(0.4, 0)
				e.Lifetime = NumberRange.new(0.5, 0.9)
				e.Rate = 12
				e.Speed = NumberRange.new(0.5, 1.5)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Acceleration = Vector3.new(0, -3, 0)
				e.LightEmission = 1
				e.Shape = Enum.ParticleEmitterShape.Box
				e.Parent = torso
				frost = e
			elseif not on and frost then
				frost:Destroy()
				frost = nil
			end
		end,
		SetBurning = function(on: boolean)
			if on and not fire and torso then
				local e = Instance.new("ParticleEmitter")
				e.Texture = TEX.Fire
				e.Color = colorSeq(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 50, 10))
				e.Size = seq(1.4, 0)
				e.Lifetime = NumberRange.new(0.3, 0.6)
				e.Rate = 25
				e.Speed = NumberRange.new(1, 3)
				e.Acceleration = Vector3.new(0, 8, 0)
				e.LightEmission = 1
				e.Shape = Enum.ParticleEmitterShape.Box
				e.Parent = torso
				fire = e
			elseif not on and fire then
				fire:Destroy()
				fire = nil
			end
		end,
		Die = function()
			if dead then
				return
			end
			dead = true
			local isBoss = model:GetAttribute("ZombieType") == "Boss"
			local _, size = model:GetBoundingBox()
			local pos = if torso then torso.Position else model:GetPivot().Position
			-- Aufloesen: gruen einfaerben, schrumpfen, durchsichtig werden
			for _, entry in parts do
				tween(entry.Part, 0.45, { Color = Color3.fromRGB(60, 255, 90), Transparency = 1 })
			end
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Eye" then
					d.Transparency = 1
				elseif d:IsA("BillboardGui") then
					d.Enabled = false
				elseif d:IsA("ParticleEmitter") then
					d.Enabled = false
				end
			end
			local s = if isBoss then 2 else 1
			flash(pos, Color3.fromRGB(90, 255, 110), 1, size.Y * 0.9, 0.3)
			burst(pos, {
				Texture = TEX.Smoke,
				Color = colorSeq(Color3.fromRGB(120, 255, 120), Color3.fromRGB(30, 70, 30)),
				Count = 10 * s,
				Size = seq(1.5 * s, 4 * s),
				Speed = NumberRange.new(3, 8),
				Lifetime = NumberRange.new(0.6, 1.1),
				Transparency = seq(0.3, 1),
				LightEmission = 0.3,
			})
			burst(pos, { Color = colorSeq(Color3.new(1, 1, 1), Color3.fromRGB(90, 255, 90)), Count = 14 * s, Size = seq(0.6, 0), Speed = NumberRange.new(10, 22) })
			-- Kleiner Geist, der nach oben schwebt
			popText(pos, "👻", Color3.new(1, 1, 1), 0.8 * s, 6, 1)
			if isBoss then
				ring(pos - Vector3.new(0, size.Y * 0.4, 0), Color3.fromRGB(190, 90, 255), 1, 18, 0.7, 28)
				speedLines(pos, Color3.fromRGB(220, 160, 255), 14, 6, 0.4)
				flashLight(pos, Color3.fromRGB(190, 90, 255), 40, 6, 0.8)
			end
		end,
	}
	return visual
end

function PetVFX.ZombieAppear(position: Vector3)
	burst(position, {
		Texture = TEX.Smoke,
		Color = colorSeq(Color3.fromRGB(110, 230, 100), Color3.fromRGB(30, 60, 30)),
		Count = 6,
		Size = seq(2, 4),
		Speed = NumberRange.new(2, 5),
		Lifetime = NumberRange.new(0.5, 0.9),
		Transparency = seq(0.4, 1),
		LightEmission = 0.4,
	})
end

--------------------------------------------------------------------------
-- Huette wird getroffen
--------------------------------------------------------------------------

function PetVFX.HutHit(position: Vector3, damage: number)
	local s = math.clamp(damage / 20, 0.6, 3)
	shards(position + Vector3.new(0, 2, 0), Color3.fromRGB(140, 95, 60), math.floor(6 * s), Enum.Material.WoodPlanks)
	burst(position + Vector3.new(0, 2, 0), {
		Texture = TEX.Smoke,
		Color = colorSeq(Color3.fromRGB(150, 130, 110)),
		Count = math.floor(6 * s),
		Size = seq(1.5, 4),
		Speed = NumberRange.new(3, 8),
		Lifetime = NumberRange.new(0.5, 1),
		Transparency = seq(0.3, 1),
		LightEmission = 0,
	})
	flash(position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 60, 40), 1, 4 * s, 0.2)
	popText(position + Vector3.new(0, 4, 0), "-" .. damage, Color3.fromRGB(255, 70, 50), 1.3, 4, 0.9)
end

return PetVFX
