-- Pets auf den Rand-Plaetzen: platzieren, entfernen, angreifen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.ZombieDefense.Config)
local Layout = require(ReplicatedStorage.ZombieDefense.Layout)
local PetData = require(ReplicatedStorage.ZombieDefense.PetData)
local Economy = require(script.Parent.Economy)
local PetInventory = require(script.Parent.PetInventory)
local ZombieService = require(script.Parent.ZombieService)

type Placed = {
	SlotId: string,
	Owner: Player,
	Info: PetData.PetInfo,
	Model: Model,
	Position: Vector3,
	Cooldown: number,
}

local PetService = {}

local placed: { [string]: Placed } = {}
local slotParts: { [string]: BasePart } = {}
local petFolder: Folder
local remotes: any -- Ordner mit RemoteEvents
local lastAction: { [Player]: number } = {}

local function message(player: Player, text: string, kind: string?)
	remotes.Message:FireClient(player, text, kind or "Info")
end

local function countPlaced(player: Player, petName: string?): number
	local n = 0
	for _, p in placed do
		if p.Owner == player and (petName == nil or p.Info.Name == petName) then
			n += 1
		end
	end
	return n
end

-- Einfaches Platzhalter-Pet, falls es kein Model mit dem Namen gibt
local function buildPlaceholder(info: PetData.PetInfo): Model
	local model = Instance.new("Model")
	local color = if info.Element == "Normal" then Config.Rarities[info.Rarity].Color else Config.Elements[info.Element].Color
	local function add(shape: Enum.PartType, size: Vector3, offset: CFrame, c: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = offset
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local body = add(Enum.PartType.Ball, Vector3.new(3, 3, 3), CFrame.new(), color)
	body.Name = "Body"
	add(Enum.PartType.Ball, Vector3.new(1.9, 1.9, 1.9), CFrame.new(0, -0.35, -0.75), color:Lerp(Color3.new(1, 1, 1), 0.5))
	for _, x in { -0.55, 0.55 } do
		add(Enum.PartType.Ball, Vector3.new(0.6, 0.7, 0.6), CFrame.new(x, 0.35, -1.25), Color3.fromRGB(25, 25, 30))
		add(Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), CFrame.new(x + 0.1, 0.5, -1.52), Color3.new(1, 1, 1), Enum.Material.Neon)
		add(Enum.PartType.Block, Vector3.new(0.6, 0.9, 0.35), CFrame.new(x * 1.3, 1.55, 0) * CFrame.Angles(0, 0, -x * 0.5), color)
		add(Enum.PartType.Ball, Vector3.new(0.8, 0.6, 1), CFrame.new(x * 1.2, -1.3, -0.3), color:Lerp(Color3.new(), 0.15))
	end
	add(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 1.3), CFrame.new(0, -0.3, 1.5), color)
	model.PrimaryPart = body
	return model
end

local function makePetModel(info: PetData.PetInfo, template: Model?): Model
	local model = if template then template:Clone() else buildPlaceholder(info)
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Humanoid") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false -- Klicks gehen durch auf den Platz darunter
		end
	end
	local _, size = model:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim > 0 then
		model:ScaleTo(model:GetScale() * Config.Inventory.PetSize / maxDim)
	end
	return model
end

local function setSlotState(slotId: string, p: Placed?)
	local pad = slotParts[slotId]
	pad:SetAttribute("Occupied", p ~= nil)
	pad:SetAttribute("OwnerUserId", if p then p.Owner.UserId else nil)
	local plus = pad:FindFirstChild("PlusGui") :: BillboardGui?
	if plus then
		plus.Enabled = p == nil
	end
	local ring = pad:FindFirstChild("Ring") :: BasePart?
	if ring then
		ring.Color = if p then Config.Rarities[p.Info.Rarity].Color else ring:GetAttribute("BaseColor") :: Color3
	end
end

local function place(player: Player, slotId: string, petName: string)
	local pad = slotParts[slotId]
	if not pad or placed[slotId] then
		message(player, "Dieser Platz ist schon belegt.", "Error")
		return
	end
	if countPlaced(player) >= Config.PetPlacement.MaxPetsPerPlayer then
		message(player, ("Du kannst maximal %d Pets platzieren."):format(Config.PetPlacement.MaxPetsPerPlayer), "Error")
		return
	end

	local owned = 0
	for _, name in PetInventory.GetPets(player) do
		if name == petName then
			owned += 1
		end
	end
	if owned == 0 or countPlaced(player, petName) >= owned then
		message(player, "Dieses Pet hast du nicht (mehr) frei.", "Error")
		return
	end
	if not Economy.TrySpend(player, Config.PetPlacement.PlacementCost) then
		message(player, "Nicht genug Coins.", "Error")
		return
	end

	local template = PetInventory.FindTemplate(petName)
	local info = PetData.Get(petName, template)
	local model = makePetModel(info, template)

	-- Ueber dem Platz schweben lassen, Blick zum Weg
	local slotPos = pad.Position
	local _, size = model:GetBoundingBox()
	local center = slotPos + Vector3.new(0, 0.4 + size.Y / 2 + 1.2, 0)
	local facing = Vector3.new(slotPos.X, center.Y, Layout.Origin.Z) -- Wegmitte
	local bboxCF = model:GetBoundingBox()
	local pivotToCenter = model:GetPivot():ToObjectSpace(bboxCF)
	model:PivotTo(CFrame.lookAt(center, facing) * pivotToCenter:Inverse())

	model.Name = "Pet_" .. slotId
	model:SetAttribute("SlotId", slotId)
	model:SetAttribute("PetName", petName)
	model:SetAttribute("Rarity", info.Rarity)
	model:SetAttribute("Element", info.Element)
	model:SetAttribute("Range", info.Range)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model.Parent = petFolder

	local p: Placed = {
		SlotId = slotId,
		Owner = player,
		Info = info,
		Model = model,
		Position = center,
		Cooldown = 0.5,
	}
	placed[slotId] = p
	setSlotState(slotId, p)
end

local function remove(slotId: string)
	local p = placed[slotId]
	if not p then
		return
	end
	placed[slotId] = nil
	p.Model:Destroy()
	setSlotState(slotId, nil)
end

local function onSlotClicked(player: Player, slotId: string)
	local p = placed[slotId]
	if p and p.Owner ~= player then
		message(player, ("Dieser Platz gehört %s."):format(p.Owner.DisplayName), "Error")
		return
	end

	-- Eigene Pets zusammenfassen (Name -> Anzahl)
	local counts: { [string]: number } = {}
	for _, name in PetInventory.GetPets(player) do
		counts[name] = (counts[name] or 0) + 1
	end
	local options = {}
	for name, count in counts do
		local info = PetData.Get(name, PetInventory.FindTemplate(name))
		table.insert(options, {
			Name = name,
			Rarity = info.Rarity,
			Element = info.Element,
			Damage = info.Damage,
			Range = info.Range,
			Available = count - countPlaced(player, name),
		})
	end
	table.sort(options, function(a, b)
		local ra, rb = PetData.RarityOrder(a.Rarity), PetData.RarityOrder(b.Rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.Name < b.Name
	end)

	remotes.OpenPicker:FireClient(player, slotId, options, {
		OwnSlot = p ~= nil,
		PlacedPet = if p then p.Info.Name else nil,
		Placed = countPlaced(player),
		Max = Config.PetPlacement.MaxPetsPerPlayer,
	})
end

local function rateLimited(player: Player): boolean
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.25 then
		return true
	end
	lastAction[player] = now
	return false
end

-- Schuss abfeuern: Clients zeigen den Effekt, der Server macht den Schaden nach der Flugzeit
local function attack(p: Placed, target: ZombieService.Zombie)
	local info = p.Info
	local element = info.Element
	local el = Config.Elements[element]
	local isCrit = math.random() < Config.CritChance
	local damage = info.Damage * (if isCrit then Config.CritMultiplier else 1)

	local from = p.Position
	local to = target.Root.Position
	local travel = if element == "Lightning" then 0.06 else (to - from).Magnitude / Config.VFX.ProjectileSpeed

	-- Blitz springt auf weitere Zombies
	local chain: { ZombieService.Zombie } = {}
	local chainPositions: { Vector3 } = {}
	if element == "Lightning" then
		local near = ZombieService.InRange(to, el.ChainRange)
		table.sort(near, function(a, b)
			return (a.Root.Position - to).Magnitude < (b.Root.Position - to).Magnitude
		end)
		for _, z in near do
			if z ~= target and #chain < el.ChainCount then
				table.insert(chain, z)
				table.insert(chainPositions, z.Root.Position)
			end
		end
	end

	remotes.Attack:FireAllClients({
		SlotId = p.SlotId,
		Element = element,
		Rarity = info.Rarity,
		From = from,
		To = to,
		TargetId = target.Id,
		Travel = travel,
		Chain = chainPositions,
		Crit = isCrit,
	})

	local owner = p.Owner
	task.delay(travel, function()
		local impact = if target.Alive then target.Root.Position else to
		if target.Alive then
			local died = ZombieService.Damage(target, damage, owner, element, isCrit)
			if not died then
				if element == "Fire" then
					ZombieService.ApplyBurn(target, damage * el.BurnFraction, el.BurnDuration, owner)
				elseif element == "Ice" then
					ZombieService.ApplySlow(target, el.SlowFactor, el.SlowDuration)
				end
			end
		end
		if element == "Magic" then
			for _, z in ZombieService.InRange(impact, el.SplashRadius) do
				if z ~= target then
					ZombieService.Damage(z, damage * el.SplashFraction, owner, element, false)
				end
			end
		elseif element == "Lightning" then
			for _, z in chain do
				ZombieService.Damage(z, damage * el.ChainFraction, owner, element, false)
			end
		end
	end)
end

local function step(dt: number)
	for _, p in placed do
		p.Cooldown -= dt
		if p.Cooldown > 0 then
			continue
		end
		-- Ziel: der Zombie, der am naechsten an der Huette ist
		local best: ZombieService.Zombie? = nil
		for _, z in ZombieService.InRange(p.Position, p.Info.Range) do
			if not best or z.Progress > best.Progress then
				best = z
			end
		end
		if best then
			attack(p, best)
			p.Cooldown = p.Info.Cooldown
		else
			p.Cooldown = 0.1
		end
	end
end

function PetService.Init(slots: { [string]: BasePart }, folder: Folder, remoteFolder: any)
	slotParts = slots
	petFolder = folder
	remotes = remoteFolder

	for slotId, pad in slots do
		local click = pad:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MouseClick:Connect(function(player)
				onSlotClicked(player, slotId)
			end)
		end
	end

	remotes.PlacePet.OnServerEvent:Connect(function(player, slotId, petName)
		if typeof(slotId) ~= "string" or typeof(petName) ~= "string" or rateLimited(player) then
			return
		end
		place(player, slotId, petName)
	end)

	remotes.RemovePet.OnServerEvent:Connect(function(player, slotId)
		if typeof(slotId) ~= "string" or rateLimited(player) then
			return
		end
		local p = placed[slotId]
		if p and p.Owner == player then
			remove(slotId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		for slotId, p in placed do
			if p.Owner == player then
				remove(slotId)
			end
		end
	end)

	RunService.Heartbeat:Connect(step)
end

function PetService.HasPets(player: Player): boolean
	return countPlaced(player) > 0
end

return PetService
