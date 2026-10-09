-- Zombie-Modus: Client (Anzeige, Pet-Auswahl, Animationen, Effekte).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("ZombieDefense")
local Config = require(Shared:WaitForChild("Config"))
local Layout = require(Shared:WaitForChild("Layout"))
local PetVFX = require(Shared:WaitForChild("PetVFX"))
local SFX = require(Shared:WaitForChild("SFX"))
local Remotes = Shared:WaitForChild("Remotes")

local map = workspace:WaitForChild("ZombieDefenseMap")
local zombieFolder = map:WaitForChild("Zombies")
local petFolder = map:WaitForChild("PlacedPets")

-- Platz-Positionen kommen aus Layout (funktioniert auch mit StreamingEnabled)
local slotPositions: { [string]: Vector3 } = {}
for _, slot in Layout.Slots do
	slotPositions[slot.Id] = slot.Position
end

local ELEMENT_ICON = { Normal = "⭐", Fire = "🔥", Ice = "❄️", Lightning = "⚡", Magic = "✨" }
local ELEMENT_NAME = { Normal = "Normal", Fire = "Feuer", Ice = "Eis", Lightning = "Blitz", Magic = "Magie" }

-- Effekte nur zeigen, wenn die Kamera in der Naehe der Zombie-Map ist
-- (spart Leistung fuer Spieler in der Lobby)
local function watching(): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - Layout.Origin).Magnitude <= Config.VFX.MaxViewDistance
end

--------------------------------------------------------------------------
-- Zombies
--------------------------------------------------------------------------

local zombieVisuals: { [number]: PetVFX.ZombieVisual } = {}

local function zombieRoot(id: number): BasePart?
	local model = zombieFolder:FindFirstChild("Z" .. id)
	return model and model:FindFirstChild("Root") :: BasePart?
end

local function onZombieAdded(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.spawn(function()
		local id = model:GetAttribute("ZombieId")
		if typeof(id) ~= "number" then
			return
		end
		local visual = PetVFX.Zombie(model)
		if not model.Parent then
			return
		end
		zombieVisuals[id] = visual
		if watching() then
			PetVFX.ZombieAppear(model:GetPivot().Position)
			SFX.Play("ZombieSpawn", model:GetPivot().Position)
		end
		model:GetAttributeChangedSignal("Slowed"):Connect(function()
			visual.SetSlowed(model:GetAttribute("Slowed") == true)
		end)
		model:GetAttributeChangedSignal("Burning"):Connect(function()
			visual.SetBurning(model:GetAttribute("Burning") == true)
		end)
		-- Zustand uebernehmen, falls der Zombie schon verlangsamt/brennend ist
		if model:GetAttribute("Slowed") == true then
			visual.SetSlowed(true)
		end
		if model:GetAttribute("Burning") == true then
			visual.SetBurning(true)
		end
	end)
end

zombieFolder.ChildAdded:Connect(onZombieAdded)
zombieFolder.ChildRemoved:Connect(function(model)
	local id = model:GetAttribute("ZombieId")
	if typeof(id) == "number" then
		zombieVisuals[id] = nil
	end
end)
for _, model in zombieFolder:GetChildren() do
	onZombieAdded(model)
end

--------------------------------------------------------------------------
-- Pets (Schweben, zum Ziel drehen, Rueckstoss beim Angriff)
--------------------------------------------------------------------------

type PetEntry = {
	Model: Model,
	BasePosition: Vector3,
	BaseRotation: CFrame,
	BaseYaw: number,
	Yaw: number,
	TargetYaw: number,
	Lunge: number,
	LungeDir: Vector3,
	Seed: number,
	Aura: PetVFX.AuraHandle,
}

local pets: { [string]: PetEntry } = {}

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function addNameTag(model: Model)
	local anchor = model:FindFirstChild("AuraAnchor") :: BasePart?
	if not anchor then
		return
	end
	local rarity = model:GetAttribute("Rarity") or "Common"
	local element = model:GetAttribute("Element") or "Normal"
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(7, 0, 1.8, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, anchor.Size.Y / 2 + 1.6, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = anchor
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.6)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Config.Rarities[rarity].Color
	name.TextStrokeTransparency = 0.1
	name.Text = ("%s %s"):format(ELEMENT_ICON[element] or "", tostring(model:GetAttribute("PetName")))
	name.Parent = gui
	local owner = Instance.new("TextLabel")
	owner.Position = UDim2.fromScale(0, 0.6)
	owner.Size = UDim2.fromScale(1, 0.4)
	owner.BackgroundTransparency = 1
	owner.Font = Enum.Font.GothamBold
	owner.TextScaled = true
	owner.TextColor3 = Color3.fromRGB(230, 230, 230)
	owner.TextStrokeTransparency = 0.3
	owner.Text = ("%s · %s"):format(rarity, tostring(model:GetAttribute("OwnerName")))
	owner.Parent = gui
end

local function onPetAdded(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local slotId = model:GetAttribute("SlotId")
	local padPosition = slotId and slotPositions[slotId]
	if not padPosition then
		return
	end
	local pivot = model:GetPivot()
	-- Der Server laesst das Pet zur Wegmitte schauen
	local yaw = yawOf(Vector3.new(0, 0, Layout.Origin.Z - padPosition.Z))
	local entry: PetEntry = {
		Model = model,
		BasePosition = pivot.Position,
		BaseRotation = pivot.Rotation,
		BaseYaw = yaw,
		Yaw = yaw,
		TargetYaw = yaw,
		Lunge = 0,
		LungeDir = Vector3.zero,
		Seed = math.random() * 10,
		Aura = PetVFX.Aura(model, padPosition),
	}
	pets[slotId] = entry
	addNameTag(model)
	if watching() then
		PetVFX.Spawn(model, padPosition)
		SFX.Play("PetPlaced", padPosition)
	end
end

petFolder.ChildAdded:Connect(onPetAdded)
petFolder.ChildRemoved:Connect(function(model)
	local slotId = model:GetAttribute("SlotId")
	local entry = slotId and pets[slotId]
	if entry and entry.Model == model then
		entry.Aura.Destroy()
		pets[slotId] = nil
	end
end)
for _, model in petFolder:GetChildren() do
	onPetAdded(model)
end

--------------------------------------------------------------------------
-- Kamera-Wackeln, wenn die Huette getroffen wird
--------------------------------------------------------------------------

local shake = 0
RunService:BindToRenderStep("ZombieDefenseShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake <= 0.01 then
		return
	end
	local camera = workspace.CurrentCamera
	local s = shake
	camera.CFrame *= CFrame.Angles((math.random() - 0.5) * s * 0.04, (math.random() - 0.5) * s * 0.04, 0)
	shake = math.max(shake - dt * 4, 0)
end)

--------------------------------------------------------------------------
-- Animation jedes Frame
--------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for _, visual in zombieVisuals do
		visual.Animate(t)
	end
	for _, entry in pets do
		if not entry.Model.Parent then
			continue
		end
		-- Sanft zum Ziel drehen
		local diff = (entry.TargetYaw - entry.Yaw + math.pi) % (2 * math.pi) - math.pi
		entry.Yaw += diff * math.min(dt * 10, 1)
		entry.Lunge = math.max(entry.Lunge - dt * 6, 0)
		local bob = math.sin(t * 2.2 + entry.Seed) * 0.35
		local pos = entry.BasePosition + Vector3.new(0, bob, 0) + entry.LungeDir * (entry.Lunge * 1.2)
		entry.Model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, entry.Yaw - entry.BaseYaw, 0) * entry.BaseRotation)
		entry.Aura.Update(t)
	end
end)

--------------------------------------------------------------------------
-- Effekte vom Server
--------------------------------------------------------------------------

Remotes.Attack.OnClientEvent:Connect(function(data)
	if not watching() then
		return
	end
	local entry = pets[data.SlotId]
	if entry then
		local dir = Vector3.new(data.To.X - entry.BasePosition.X, 0, data.To.Z - entry.BasePosition.Z)
		if dir.Magnitude > 0.1 then
			entry.TargetYaw = yawOf(dir)
			entry.LungeDir = dir.Unit
			entry.Lunge = 1
		end
	end
	local targetId = data.TargetId
	PetVFX.Attack(data, function()
		local root = zombieRoot(targetId)
		return if root then root.Position else nil
	end)
	SFX.Play("Shoot" .. tostring(data.Element), data.From)
	task.delay(data.Travel, function()
		SFX.Play(if data.Crit then "Crit" else "Hit", data.To)
	end)
end)

Remotes.Damage.OnClientEvent:Connect(function(id, amount, element, isCrit)
	if not watching() then
		return
	end
	local visual = zombieVisuals[id]
	if visual then
		visual.Flash()
	end
	local root = zombieRoot(id)
	if root then
		PetVFX.DamageNumber(root.Position + Vector3.new(0, 2, 0), amount, element, isCrit)
	end
end)

Remotes.ZombieDied.OnClientEvent:Connect(function(id, position, typeName)
	local visual = zombieVisuals[id]
	if visual then
		visual.Die()
	end
	if watching() then
		SFX.Play(if typeName == "Boss" then "BossDeath" else "ZombieDeath", position)
	end
end)

Remotes.CoinsEarned.OnClientEvent:Connect(function(amount, position)
	PetVFX.CoinPop(position, amount)
	SFX.Play("Coin")
end)

Remotes.HutHit.OnClientEvent:Connect(function(position, damage)
	if not watching() then
		return
	end
	PetVFX.HutHit(position, damage)
	SFX.Play("HutHit", position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - position).Magnitude < 120 then
		shake = math.min(shake + damage / 15, 3)
	end
end)

--------------------------------------------------------------------------
-- Anzeige (HUD)
--------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ZombieDefenseHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 8)
panel.Size = UDim2.fromOffset(320, 108)
panel.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
panel.BackgroundTransparency = 0.15
panel.Visible = false
panel.Parent = gui
corner(panel, 14)
stroke(panel, Color3.fromRGB(110, 230, 90), 2)

local waveLabel = label(panel, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 30), Text = "🧟 Welle 0" })
local statusLabel = label(panel, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 20), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(210, 230, 210), Text = "" })

local hutBack = Instance.new("Frame")
hutBack.Position = UDim2.fromOffset(12, 62)
hutBack.Size = UDim2.new(1, -24, 0, 16)
hutBack.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
hutBack.Parent = panel
corner(hutBack, 8)
local hutFill = Instance.new("Frame")
hutFill.Size = UDim2.fromScale(1, 1)
hutFill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
hutFill.Parent = hutBack
corner(hutFill, 8)
local hutText = label(hutBack, { Size = UDim2.fromScale(1, 1), ZIndex = 2, Font = Enum.Font.GothamBold, Text = "🏠" })
local coinsLabel = label(panel, { Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 18), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 215, 60), Text = "" })

-- Eigene Coins dieser Runde und aktueller Belohnungs-Anteil
local function refreshCoins()
	coinsLabel.Text = ("💰 Diese Runde: %d   ·   Belohnung: %d %%"):format(
		player:GetAttribute("ZD_RunCoins") or 0,
		player:GetAttribute("ZD_RewardPercent") or math.floor(Config.Economy.EarlyGameMultiplier * 100 + 0.5)
	)
end
player:GetAttributeChangedSignal("ZD_RunCoins"):Connect(refreshCoins)
player:GetAttributeChangedSignal("ZD_RewardPercent"):Connect(refreshCoins)
refreshCoins()

local function refreshHud()
	local state = Shared:GetAttribute("State")
	local wave = Shared:GetAttribute("Wave") or 0
	waveLabel.Text = if wave > 0 then ("🧟 Welle %d"):format(wave) else "🧟 Zombie-Modus"
	if state == "Intermission" then
		statusLabel.Text = ("Nächste Welle in %ds – klicke auf einen Platz am Rand!"):format(Shared:GetAttribute("Countdown") or 0)
	elseif state == "Wave" then
		statusLabel.Text = ("Zombies übrig: %d"):format(Shared:GetAttribute("ZombiesLeft") or 0)
	elseif state == "GameOver" then
		statusLabel.Text = "Die Hütte ist zerstört …"
	else
		statusLabel.Text = "Warte auf Spieler …"
	end
	local hp = Shared:GetAttribute("HutHealth") or 0
	local max = Shared:GetAttribute("HutMaxHealth") or 1
	local ratio = math.clamp(hp / max, 0, 1)
	TweenService:Create(hutFill, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = Color3.fromRGB(230, 60, 50):Lerp(Color3.fromRGB(90, 220, 90), ratio),
	}):Play()
	hutText.Text = ("🏠 Hütte %d / %d"):format(math.ceil(hp), max)
end

for _, attr in { "State", "Wave", "Countdown", "ZombiesLeft", "HutHealth", "HutMaxHealth" } do
	Shared:GetAttributeChangedSignal(attr):Connect(refreshHud)
end
refreshHud()

-- HUD nur in der Zombie-Map zeigen
task.spawn(function()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		panel.Visible = root ~= nil and Layout.IsInside(root.Position)
		task.wait(0.5)
	end
end)

-- Banner fuer Meldungen
local BANNER_COLORS = {
	Info = Color3.fromRGB(255, 255, 255),
	Wave = Color3.fromRGB(140, 255, 110),
	Boss = Color3.fromRGB(210, 120, 255),
	Reward = Color3.fromRGB(255, 215, 60),
	Error = Color3.fromRGB(255, 100, 80),
	GameOver = Color3.fromRGB(255, 100, 80),
}
local BANNER_SOUNDS = { Wave = "WaveStart", Boss = "BossIncoming", Reward = "WaveCleared", GameOver = "GameOver" }
local bannerToken = 0
local banner = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.28),
	Size = UDim2.fromScale(0.6, 0.08),
	TextStrokeTransparency = 0,
	TextTransparency = 1,
	Text = "",
})
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner

Remotes.Message.OnClientEvent:Connect(function(text: string, kind: string)
	bannerToken += 1
	local token = bannerToken
	local sound = BANNER_SOUNDS[kind]
	if sound then
		SFX.Play(sound)
	end
	banner.Text = text
	banner.TextColor3 = BANNER_COLORS[kind] or BANNER_COLORS.Info
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0
	bannerScale.Scale = 0.4
	TweenService:Create(bannerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(if kind == "Error" then 2 elseif kind == "GameOver" then 5 else 2.5, function()
		if token == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

--------------------------------------------------------------------------
-- Pet-Auswahl beim Klick auf einen Platz
--------------------------------------------------------------------------

local picker = Instance.new("Frame")
picker.AnchorPoint = Vector2.new(0.5, 0.5)
picker.Position = UDim2.fromScale(0.5, 0.55)
picker.Size = UDim2.fromScale(0.9, 0.7)
picker.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
picker.Visible = false
picker.Parent = gui
corner(picker, 16)
stroke(picker, Color3.fromRGB(120, 220, 255), 2)
local pickerSizeLimit = Instance.new("UISizeConstraint")
pickerSizeLimit.MaxSize = Vector2.new(380, 420)
pickerSizeLimit.Parent = picker

local pickerTitle = label(picker, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -70, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "Pet wählen" })
local pickerSub = label(picker, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 18), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(190, 200, 210), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 10)
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Font = Enum.Font.FredokaOne
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Text = "X"
closeButton.Parent = picker
corner(closeButton, 10)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 66)
list.Size = UDim2.new(1, -24, 1, -78)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = picker
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

closeButton.Activated:Connect(function()
	SFX.Play("Click")
	picker.Visible = false
end)

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeButton(text: string, color: Color3, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -8, 0, 46)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.LayoutOrder = order
	b.AutoButtonColor = true
	b.Parent = list
	corner(b, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = b
	return b
end

Remotes.OpenPicker.OnClientEvent:Connect(function(slotId: string, options, meta)
	SFX.Play("Click")
	clearList()
	picker.Visible = true
	pickerSub.Text = ("Platziert: %d / %d  ·  Nur am Rand erlaubt"):format(meta.Placed, meta.Max)

	if meta.OwnSlot then
		pickerTitle.Text = ("Dein Pet: %s"):format(tostring(meta.PlacedPet))
		local remove = makeButton("🗑️ Pet entfernen", Color3.fromRGB(190, 60, 60), 0)
		remove.Activated:Connect(function()
			SFX.Play("Click")
			Remotes.RemovePet:FireServer(slotId)
			picker.Visible = false
		end)
		return
	end

	pickerTitle.Text = "Pet wählen"
	if #options == 0 then
		makeButton("Du hast noch keine Pets", Color3.fromRGB(70, 70, 80), 1)
		return
	end
	for i, opt in options do
		local rarityColor = Config.Rarities[opt.Rarity] and Config.Rarities[opt.Rarity].Color or Color3.new(1, 1, 1)
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -8, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
		row.AutoButtonColor = opt.Available > 0
		row.Text = ""
		row.LayoutOrder = i
		row.Parent = list
		corner(row, 12)
		stroke(row, rarityColor, 2)
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 8, 1, 0)
		stripe.BackgroundColor3 = rarityColor
		stripe.Parent = row
		corner(stripe, 4)
		label(row, {
			Position = UDim2.fromOffset(18, 6),
			Size = UDim2.new(1, -110, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rarityColor,
			Text = ("%s %s"):format(ELEMENT_ICON[opt.Element] or "", opt.Name),
		})
		label(row, {
			Position = UDim2.fromOffset(18, 36),
			Size = UDim2.new(1, -110, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(200, 205, 215),
			Text = ("%s · %s · ⚔️ %d · 🎯 %d"):format(opt.Rarity, ELEMENT_NAME[opt.Element] or opt.Element, opt.Damage, opt.Range),
		})
		label(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(80, 30),
			TextColor3 = if opt.Available > 0 then Color3.fromRGB(140, 255, 120) else Color3.fromRGB(150, 150, 150),
			Text = if opt.Available > 0 then ("x%d frei"):format(opt.Available) else "benutzt",
		})
		if opt.Available <= 0 then
			row.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
		else
			row.Activated:Connect(function()
				SFX.Play("Click")
				Remotes.PlacePet:FireServer(slotId, opt.Name)
				picker.Visible = false
			end)
		end
	end
end)
