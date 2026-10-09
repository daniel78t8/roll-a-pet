-- Sounds fuer den Zombie-Modus (laeuft nur auf dem Client).
-- Die Sound-IDs stehen in Config.Sounds.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)

local S = Config.Sounds
local SFX = {}

local folder = Instance.new("Folder")
folder.Name = "ZombieDefenseSFX"
folder.Parent = SoundService

local templates: { [string]: Sound } = {}
local failed: { [string]: boolean } = {}
local lastPlayed: { [string]: number } = {}
local playing: { [string]: number } = {}

for name, def in S.List do
	if def.Id and def.Id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = def.Id
		sound.Volume = def.Volume or 0.5
		sound.Parent = folder
		templates[name] = sound
	end
end

-- Sounds vorladen; was nicht laedt, wird spaeter einfach uebersprungen
task.spawn(function()
	local list = {}
	for _, sound in templates do
		table.insert(list, sound)
	end
	pcall(function()
		ContentProvider:PreloadAsync(list, function(assetId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				for name, sound in templates do
					if sound.SoundId == assetId then
						failed[name] = true
					end
				end
			end
		end)
	end)
end)

-- Spielt einen Sound. Mit position = 3D-Sound an dieser Stelle, sonst 2D.
function SFX.Play(name: string, position: Vector3?, pitch: number?)
	if not S.Enabled then
		return
	end
	local def = S.List[name]
	local template = templates[name]
	if not def or not template or failed[name] then
		return
	end

	-- Nicht zu oft und nicht zu viele gleichzeitig (sonst wird es zu laut)
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < (def.MinGap or 0.05) then
		return
	end
	if (playing[name] or 0) >= (def.MaxConcurrent or 6) then
		return
	end
	lastPlayed[name] = now
	playing[name] = (playing[name] or 0) + 1

	local sound = template:Clone()
	local variation = def.PitchVariation or 0.08
	sound.PlaybackSpeed = (def.Pitch or 1) * (pitch or 1) * (1 + (math.random() * 2 - 1) * variation)
	sound.Volume = (def.Volume or 0.5) * S.MasterVolume

	local holder: Instance = sound
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = def.MaxDistance or 160
		sound.Parent = attachment
		holder = attachment
	else
		sound.Parent = folder
	end

	local done = false
	local function cleanup()
		if done then
			return
		end
		done = true
		playing[name] = math.max((playing[name] or 1) - 1, 0)
		holder:Destroy()
	end
	sound.Ended:Once(cleanup)
	-- Sicherheitsnetz, falls Ended nie kommt
	task.delay(6, cleanup)
	sound:Play()
end

return SFX
