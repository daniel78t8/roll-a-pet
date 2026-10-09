-- Zombie-Modus: Hauptskript (Wellen, Huette, Belohnungen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ZombieDefense")
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)

local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local PetService = require(script.Parent.PetService)
local ZombieService = require(script.Parent.ZombieService)

-- Remotes anlegen
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "Attack", "Damage", "ZombieDied", "HutHit", "Message", "OpenPicker", "PlacePet", "RemovePet", "CoinsEarned" } do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
remotes.Parent = Shared

local refs = MapBuilder.Build()
ZombieService.Init(refs.Zombies, remotes)
PetService.Init(refs.Slots, refs.PlacedPets, remotes)

local wave = 0
local hutHealth = Config.Hut.MaxHealth
local spawnsLeft = 0

-- Fairness-Daten pro Spieler (gelten fuer die aktuelle Runde)
local progress: { [Player]: number } = {} -- selbst geschaffte Wellen
local runEarned: { [Player]: number } = {} -- in dieser Runde verdiente Coins
local contributed: { [Player]: boolean } = {} -- hat in dieser Welle Schaden gemacht
local lastActive = os.clock()

local function setState(state: string)
	Shared:SetAttribute("State", state)
end

local function setHut(value: number)
	hutHealth = math.clamp(value, 0, Config.Hut.MaxHealth)
	Shared:SetAttribute("HutHealth", hutHealth)
	Shared:SetAttribute("HutMaxHealth", Config.Hut.MaxHealth)
	local ratio = hutHealth / Config.Hut.MaxHealth
	refs.HutFill.Size = UDim2.fromScale(ratio, 1)
	refs.HutFill.BackgroundColor3 = Color3.fromRGB(230, 60, 50):Lerp(Color3.fromRGB(90, 220, 90), ratio)
	refs.HutText.Text = ("%d / %d"):format(math.ceil(hutHealth), Config.Hut.MaxHealth)
end

local function updateZombiesLeft()
	Shared:SetAttribute("ZombiesLeft", spawnsLeft + ZombieService.AliveCount())
end

-- Spieler gelten als aktiv, wenn sie in der Zombie-Map sind oder Pets platziert haben
local function activePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if PetService.HasPets(player) or (root and Layout.IsInside(root.Position)) then
			table.insert(list, player)
		end
	end
	return list
end

-- Erst nach 5 Sekunden ohne aktive Spieler aufgeben (z.B. beim Respawn)
local function abandoned(): boolean
	if #activePlayers() > 0 then
		lastActive = os.clock()
		return false
	end
	return os.clock() - lastActive > 5
end

local function broadcast(text: string, kind: string)
	for _, player in activePlayers() do
		remotes.Message:FireClient(player, text, kind)
	end
end

-- Welle, nach der sich die Belohnung des Spielers richtet: seine eigenen
-- geschafften Wellen + 1 (hoechstens die aktuelle Welle)
local function personalWave(player: Player): number
	return math.max(1, math.min(wave, (progress[player] or 0) + 1))
end

local function updatePlayerHud(player: Player)
	player:SetAttribute("ZD_RunCoins", runEarned[player] or 0)
	player:SetAttribute("ZD_RewardPercent", math.floor(Economy.Multiplier(personalWave(player)) * 100 + 0.5))
end

local function award(player: Player, amount: number): number
	local gained = Economy.Award(player, amount)
	if gained > 0 then
		runEarned[player] = (runEarned[player] or 0) + gained
		updatePlayerHud(player)
	end
	return gained
end

local function clearPlayer(player: Player)
	progress[player] = nil
	runEarned[player] = nil
	contributed[player] = nil
	if player.Parent then
		updatePlayerHud(player)
	end
end

ZombieService.OnDamage = function(player)
	contributed[player] = true
end

-- Coins werden nach Schaden aufgeteilt
ZombieService.OnKilled = function(zombie)
	updateZombiesLeft()
	local total = 0
	for _, dealt in zombie.DamageBy do
		total += dealt
	end
	if total <= 0 then
		return
	end
	for player, dealt in zombie.DamageBy do
		if player.Parent then
			local reward = Economy.KillReward(zombie.TypeName, personalWave(player)) * (dealt / total)
			local gained = award(player, reward)
			if gained > 0 then
				remotes.CoinsEarned:FireClient(player, gained, zombie.Root.Position)
			end
		end
	end
end

Players.PlayerRemoving:Connect(clearPlayer)

ZombieService.OnReachedHut = function(zombie)
	setHut(hutHealth - zombie.HutDamage)
	updateZombiesLeft()
end

local function pickZombieType(w: number): string
	local total = 0
	local pool = {}
	for name, def in Config.ZombieTypes do
		if not def.IsBoss and w >= (def.FromWave or 1) then
			total += def.Weight or 1
			table.insert(pool, { name, def.Weight or 1 })
		end
	end
	local roll = math.random() * total
	for _, entry in pool do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return "Zombie"
end

-- Laeuft eine Welle; Ergebnis: "Cleared", "GameOver" oder "Abandoned"
local function runWave(w: number): string
	local W = Config.Waves
	local count = math.min(W.BaseCount + W.CountPerWave * (w - 1), W.MaxCount)
	local interval = math.max(W.SpawnInterval - W.SpawnIntervalDecay * (w - 1), W.MinSpawnInterval)
	local hasBoss = W.BossEvery > 0 and w % W.BossEvery == 0
	spawnsLeft = count + (if hasBoss then 1 else 0)
	updateZombiesLeft()

	local stop = false
	task.spawn(function()
		for _ = 1, count do
			if stop then
				return
			end
			ZombieService.Spawn(pickZombieType(w), w)
			spawnsLeft -= 1
			updateZombiesLeft()
			task.wait(interval)
		end
		if hasBoss and not stop then
			broadcast("👑 Ein BOSS kommt!", "Boss")
			task.wait(1.5)
			if not stop then
				ZombieService.Spawn("Boss", w)
				spawnsLeft -= 1
				updateZombiesLeft()
			end
		end
	end)

	while true do
		task.wait(0.25)
		if hutHealth <= 0 then
			stop = true
			return "GameOver"
		end
		if abandoned() then
			stop = true
			return "Abandoned"
		end
		if spawnsLeft <= 0 and ZombieService.AliveCount() == 0 then
			return "Cleared"
		end
	end
end

local function resetRound()
	ZombieService.ClearAll()
	spawnsLeft = 0
	wave = 0
	Shared:SetAttribute("Wave", 0)
	setHut(Config.Hut.MaxHealth)
	updateZombiesLeft()
	for _, player in Players:GetPlayers() do
		clearPlayer(player)
	end
end

-- Wer die Map ohne Pets verlaesst, verliert seinen Fortschritt (kein "Parken")
local function dropInactivePlayers()
	local active = {}
	for _, player in activePlayers() do
		active[player] = true
	end
	for player in progress do
		if not active[player] then
			clearPlayer(player)
		end
	end
end

resetRound()
setState("Waiting")

while true do
	if abandoned() or #activePlayers() == 0 then
		if wave > 0 and abandoned() then
			resetRound()
		end
		setState("Waiting")
		task.wait(1)
		continue
	end

	-- Pause zum Platzieren
	setState("Intermission")
	local pause = if wave == 0 then Config.Waves.FirstIntermission else Config.Waves.Intermission
	local isAbandoned = false
	for t = pause, 1, -1 do
		Shared:SetAttribute("Countdown", t)
		task.wait(1)
		if abandoned() then
			isAbandoned = true
			break
		end
	end
	if isAbandoned then
		continue
	end

	wave += 1
	Shared:SetAttribute("Wave", wave)
	setState("Wave")
	PetService.Revalidate()
	dropInactivePlayers()
	table.clear(contributed)
	for _, player in activePlayers() do
		updatePlayerHud(player)
	end
	broadcast(("🧟 Welle %d"):format(wave), "Wave")

	local result = runWave(wave)
	if result == "GameOver" then
		setState("GameOver")
		for _, player in activePlayers() do
			remotes.Message:FireClient(
				player,
				("💥 Die Hütte wurde zerstört! %d Wellen geschafft, %d Coins verdient."):format(wave - 1, runEarned[player] or 0),
				"GameOver"
			)
		end
		ZombieService.ClearAll()
		task.wait(Config.Waves.GameOverPause)
		resetRound()
	elseif result == "Cleared" then
		for _, player in activePlayers() do
			local text = ("✅ Welle %d geschafft!"):format(wave)
			if contributed[player] then
				-- Bonus nach eigenem Fortschritt, danach zaehlt die Welle fuer den Spieler
				local gained = award(player, Economy.WaveBonus(personalWave(player)))
				progress[player] = (progress[player] or 0) + 1
				updatePlayerHud(player)
				if gained > 0 then
					text ..= ("  +%d Coins"):format(gained)
				end
			else
				text ..= "  (Kein Bonus: deine Pets haben nicht mitgekämpft)"
			end
			remotes.Message:FireClient(player, text, "Reward")
		end
		setHut(hutHealth + Config.Hut.RegenPerWave)
	else
		resetRound()
	end
end
