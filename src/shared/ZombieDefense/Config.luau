-- Zombie-Modus: alle Einstellungen an einer Stelle.
-- Werte hier aendern, um Geld, Wellen, Pets und Effekte anzupassen.

local Config = {}

--------------------------------------------------------------------------
-- Map (Aufbau wie in der Skizze: Zombies links -> Mitte mit Pet-Plaetzen
-- oben und unten am Rand -> Huette rechts)
--------------------------------------------------------------------------
Config.Map = {
	-- Weit weg von der Lobby, damit nichts ueberlappt
	Origin = Vector3.new(0, 0, 600),

	LaneLength = 100, -- Zombie-Weg links
	LaneWidth = 28,
	CenterWidth = 40, -- Mittelteil mit den Pet-Plaetzen
	CenterDepth = 80,
	PathHalfWidth = 14, -- ab hier beginnt der "Rand" mit den Plaetzen
	HutAreaLength = 44,
	HutAreaWidth = 26,

	SlotsPerSide = 3, -- 3 Plaetze oben + 3 unten (wie gezeichnet)
	SlotDistanceFromPath = 11, -- wie weit die Plaetze von der Wegmitte weg sind (zusaetzlich zu PathHalfWidth)

	-- Portal in der Lobby, das in den Zombie-Modus teleportiert
	CreateLobbyPortal = true,
	LobbyPortalPosition = Vector3.new(0, 0, 40),
}

--------------------------------------------------------------------------
-- Geld: am Anfang bewusst wenig, spaeter langsam mehr
--------------------------------------------------------------------------
Config.Economy = {
	CurrencyName = "Coins", -- Name des Werts in leaderstats
	CreateLeaderstatsIfMissing = true,
	StartingCoins = 0, -- nur falls der Wert neu angelegt wird

	-- Grundbelohnung pro Zombie-Typ (vor dem Multiplikator)
	KillReward = {
		Zombie = 1,
		Runner = 1,
		Brute = 3,
		Boss = 15,
	},

	-- Bis Welle 50 gibt es nur wenig Geld, damit neue Spieler nicht schnell
	-- reich werden. Welle 1 = 10 %, Welle 25 = ca. 32 %, Welle 40 = ca. 67 %,
	-- ab Welle 50 = 100 %. Die Kurve steigt erst langsam und am Ende schneller.
	-- Bruchteile werden gesammelt (0,1 Coins pro Kill -> jeder 10. Kill gibt 1 Coin).
	EarlyGameMultiplier = 0.1,
	EarlyGameRampWaves = 50,
	EarlyGameCurve = 2, -- 1 = gleichmaessig, hoeher = laenger wenig Geld
	GrowthPerWaveAfterRamp = 0.05, -- nach Welle 50 +5 % pro Welle
	MaxMultiplier = 3,

	WaveBonusBase = 1, -- Bonus fuer jede ueberstandene Welle
	WaveBonusPerWave = 1,

	-- Fairness:
	-- * Die Belohnung richtet sich nach den Wellen, die DU in dieser Runde
	--   geschafft hast. Wer bei Welle 45 dazukommt, startet trotzdem bei 10 %.
	-- * Kill-Coins werden nach Schaden aufgeteilt (kein "Last Hit"-Klauen).
	-- * Den Wellen-Bonus bekommt nur, wessen Pets in der Welle Schaden gemacht haben.
	-- Wer die Zombie-Map ohne platzierte Pets verlaesst, verliert seinen Fortschritt.
}

--------------------------------------------------------------------------
-- Wellen und Zombies
--------------------------------------------------------------------------
Config.Waves = {
	FirstIntermission = 20, -- Zeit zum Platzieren vor Welle 1
	Intermission = 10,
	GameOverPause = 8,

	BaseCount = 4,
	CountPerWave = 2,
	MaxCount = 45,

	SpawnInterval = 1.4,
	MinSpawnInterval = 0.45,
	SpawnIntervalDecay = 0.06, -- pro Welle schneller

	-- Leben = Basis * (1 + Linear * (Welle-1) + Quadratisch * (Welle-1)^2)
	-- Getestet per Simulation: 2 Common ~Welle 6, 3 Legendary ~Welle 33,
	-- 3 Mythic ~Welle 55, 6 Mythic (2 Spieler) ~Welle 90.
	HealthGrowthPerWave = 0.06,
	HealthGrowthQuadratic = 0.001,
	BossEvery = 5, -- jede 5. Welle kommt ein Boss
}

Config.ZombieTypes = {
	Zombie = {
		Health = 20,
		Speed = 5,
		HutDamage = 8,
		Scale = 1,
		FromWave = 1,
		Weight = 10,
		Skin = Color3.fromRGB(110, 160, 90),
		Shirt = Color3.fromRGB(70, 90, 140),
		Pants = Color3.fromRGB(60, 50, 40),
		Eyes = Color3.fromRGB(255, 60, 40),
	},
	Runner = {
		Health = 12,
		Speed = 9.5,
		HutDamage = 5,
		Scale = 0.85,
		FromWave = 3,
		Weight = 4,
		Skin = Color3.fromRGB(150, 175, 95),
		Shirt = Color3.fromRGB(170, 70, 50),
		Pants = Color3.fromRGB(45, 45, 60),
		Eyes = Color3.fromRGB(255, 170, 0),
	},
	Brute = {
		Health = 90,
		Speed = 3.2,
		HutDamage = 20,
		Scale = 1.45,
		FromWave = 6,
		Weight = 2,
		Skin = Color3.fromRGB(80, 120, 75),
		Shirt = Color3.fromRGB(60, 60, 60),
		Pants = Color3.fromRGB(80, 60, 35),
		Eyes = Color3.fromRGB(255, 30, 30),
	},
	Boss = {
		Health = 450,
		Speed = 2.4,
		HutDamage = 80,
		Scale = 2.3,
		IsBoss = true,
		Skin = Color3.fromRGB(95, 70, 120),
		Shirt = Color3.fromRGB(40, 20, 30),
		Pants = Color3.fromRGB(30, 20, 25),
		Eyes = Color3.fromRGB(180, 255, 60),
	},
}

Config.Hut = {
	MaxHealth = 250,
	RegenPerWave = 30,
}

--------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------
Config.PetPlacement = {
	MaxPetsPerPlayer = 3,
	PlacementCost = 0, -- Coins pro Platzierung (0 = gratis)
}

Config.Rarities = {
	-- Damage pro Treffer, Range in Studs, Cooldown in Sekunden
	Common = { Order = 1, Damage = 4, Range = 30, Cooldown = 1.0, Color = Color3.fromRGB(210, 210, 210) },
	Uncommon = { Order = 2, Damage = 6, Range = 31, Cooldown = 0.95, Color = Color3.fromRGB(90, 220, 110) },
	Rare = { Order = 3, Damage = 9, Range = 33, Cooldown = 0.9, Color = Color3.fromRGB(70, 160, 255) },
	Epic = { Order = 4, Damage = 14, Range = 36, Cooldown = 0.8, Color = Color3.fromRGB(180, 90, 255) },
	Legendary = { Order = 5, Damage = 22, Range = 40, Cooldown = 0.7, Color = Color3.fromRGB(255, 190, 40) },
	Mythic = { Order = 6, Damage = 35, Range = 45, Cooldown = 0.6, Color = Color3.fromRGB(255, 80, 160) },
}

-- Elemente bestimmen Effekt UND Zusatzwirkung
Config.Elements = {
	Normal = { Color = Color3.fromRGB(255, 240, 170) }, -- normaler Treffer
	Fire = { Color = Color3.fromRGB(255, 120, 30), BurnDuration = 3, BurnFraction = 0.2 }, -- brennt nach
	Ice = { Color = Color3.fromRGB(130, 220, 255), SlowDuration = 2, SlowFactor = 0.55 }, -- verlangsamt
	Lightning = { Color = Color3.fromRGB(255, 250, 130), ChainCount = 2, ChainRange = 12, ChainFraction = 0.6 }, -- springt weiter
	Magic = { Color = Color3.fromRGB(200, 110, 255), SplashRadius = 7, SplashFraction = 0.5 }, -- Flaechenschaden
}

Config.CritChance = 0.1
Config.CritMultiplier = 2

-- Bekannte Pets. Unbekannte Pets bekommen DefaultPet.
-- Tipp: Ein Pet-Model kann auch die Attribute "Rarity" und "Element" haben,
-- die gehen dann vor.
Config.DefaultPet = { Rarity = "Common", Element = "Normal" }
Config.Pets = {
	Dog = { Rarity = "Common", Element = "Normal" },
	Cat = { Rarity = "Common", Element = "Normal" },
	Bunny = { Rarity = "Uncommon", Element = "Magic" },
	Bear = { Rarity = "Uncommon", Element = "Normal" },
	Fox = { Rarity = "Rare", Element = "Fire" },
	Penguin = { Rarity = "Rare", Element = "Ice" },
	Owl = { Rarity = "Epic", Element = "Lightning" },
	Unicorn = { Rarity = "Epic", Element = "Magic" },
	Dragon = { Rarity = "Legendary", Element = "Fire" },
	Yeti = { Rarity = "Legendary", Element = "Ice" },
	Phoenix = { Rarity = "Mythic", Element = "Fire" },
	["Storm Wolf"] = { Rarity = "Mythic", Element = "Lightning" },
}

-- Wo die eigenen Pets des Spielers liegen (siehe PetInventory.luau)
Config.Inventory = {
	PlayerFolderName = "Pets", -- player.Pets (Kinder = Pets)
	StarterPets = { "Dog", "Cat" }, -- falls der Spieler (noch) keine Pets hat
	ModelFolderNames = { "PetModels", "Pets" }, -- in ReplicatedStorage / ServerStorage
	PetSize = 4, -- Pet-Models werden auf diese Groesse skaliert
}

--------------------------------------------------------------------------
-- Effekte (Texturen sind in Roblox eingebaut, koennen durch eigene
-- rbxassetid:// IDs ersetzt werden)
--------------------------------------------------------------------------
Config.VFX = {
	Textures = {
		Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
		Fire = "rbxasset://textures/particles/fire_main.dds",
	},
	ProjectileSpeed = 70,
	ShowDamageNumbers = true,
	MaxActiveProjectiles = 60,
	MaxViewDistance = 300, -- weiter weg (z.B. in der Lobby) werden keine Effekte gezeigt
}

--------------------------------------------------------------------------
-- Sounds. Es sind eingebaute Roblox-Sounds eingetragen, damit es sofort
-- klingt. Fuer bessere Sounds: im Creator Store (Toolbox -> Audio) einen
-- Sound suchen, ID kopieren und z.B. Id = "rbxassetid://1234567" eintragen.
-- Sounds, die nicht laden, werden einfach uebersprungen.
--------------------------------------------------------------------------
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local OOF = "rbxasset://sounds/uuhhh.mp3"
local GROAN = "rbxasset://sounds/action_get_up.mp3"

Config.Sounds = {
	Enabled = true,
	MasterVolume = 1,
	List = {
		-- Pets schiessen (je Element)
		ShootNormal = { Id = SWOOSH, Volume = 0.35, Pitch = 1.5 },
		ShootFire = { Id = SWOOSH, Volume = 0.45, Pitch = 0.75 },
		ShootIce = { Id = SWOOSH, Volume = 0.35, Pitch = 2 },
		ShootLightning = { Id = PING, Volume = 0.4, Pitch = 0.5 },
		ShootMagic = { Id = PING, Volume = 0.3, Pitch = 1.6 },
		Hit = { Id = THUD, Volume = 0.4, Pitch = 1.6, MinGap = 0.04 },
		Crit = { Id = PING, Volume = 0.45, Pitch = 2.2 },
		-- Zombies
		ZombieSpawn = { Id = GROAN, Volume = 0.3, Pitch = 0.6, MinGap = 0.3 },
		ZombieDeath = { Id = OOF, Volume = 0.45, Pitch = 0.75, MinGap = 0.08 },
		BossDeath = { Id = OOF, Volume = 1, Pitch = 0.4, MinGap = 0 },
		HutHit = { Id = THUD, Volume = 0.9, Pitch = 0.5, MinGap = 0.1 },
		-- Spiel und Oberflaeche (2D, ohne Position)
		PetPlaced = { Id = PING, Volume = 0.5, Pitch = 1 },
		Coin = { Id = PING, Volume = 0.3, Pitch = 1.8, MinGap = 0.06 },
		WaveStart = { Id = SWOOSH, Volume = 0.6, Pitch = 0.5 },
		BossIncoming = { Id = OOF, Volume = 0.8, Pitch = 0.3 },
		WaveCleared = { Id = PING, Volume = 0.5, Pitch = 1.3 },
		GameOver = { Id = OOF, Volume = 0.8, Pitch = 0.55 },
		Click = { Id = PING, Volume = 0.25, Pitch = 2.5 },
	},
}

return Config
