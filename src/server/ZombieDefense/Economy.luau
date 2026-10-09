-- Geld im Zombie-Modus. Am Anfang gibt es bewusst wenig, damit man nicht
-- sofort reich ist; mit jeder Welle steigt die Belohnung.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ZombieDefense.Config)

local E = Config.Economy
local Economy = {}

-- Gesammelte Bruchteile pro Spieler (z.B. 0,1 Coins pro Kill)
local fractions: { [Player]: number } = {}

-- Findet den Coins-Wert in leaderstats (oder legt ihn an).
-- Falls dein Spiel Coins woanders speichert, hier anpassen.
local function getCoinsValue(player: Player): ValueBase?
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		if not E.CreateLeaderstatsIfMissing then
			return nil
		end
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local value = leaderstats:FindFirstChild(E.CurrencyName)
	if not value then
		if not E.CreateLeaderstatsIfMissing then
			return nil
		end
		local created = Instance.new("IntValue")
		created.Name = E.CurrencyName
		created.Value = E.StartingCoins
		created.Parent = leaderstats
		value = created
	end

	if value:IsA("IntValue") or value:IsA("NumberValue") then
		return value
	end
	return nil
end

function Economy.GetCoins(player: Player): number
	local value = getCoinsValue(player) :: any
	return if value then value.Value else 0
end

-- Fuegt Coins hinzu (auch Bruchteile); gibt die tatsaechlich gutgeschriebenen ganzen Coins zurueck
function Economy.Award(player: Player, amount: number): number
	if amount <= 0 then
		return 0
	end
	local total = (fractions[player] or 0) + amount
	local whole = math.floor(total)
	fractions[player] = total - whole
	if whole > 0 then
		local value = getCoinsValue(player) :: any
		if value then
			value.Value += whole
		end
	end
	return whole
end

function Economy.TrySpend(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end
	local value = getCoinsValue(player) :: any
	if not value or value.Value < amount then
		return false
	end
	value.Value -= amount
	return true
end

-- Multiplikator je nach Welle: Welle 1 = EarlyGameMultiplier, ab RampWaves = 1, danach waechst er langsam
function Economy.Multiplier(wave: number): number
	local ramp = math.max(E.EarlyGameRampWaves, 2)
	if wave <= ramp then
		local t = ((wave - 1) / (ramp - 1)) ^ (E.EarlyGameCurve or 1)
		return E.EarlyGameMultiplier + (1 - E.EarlyGameMultiplier) * t
	end
	return math.min(1 + (wave - ramp) * E.GrowthPerWaveAfterRamp, E.MaxMultiplier)
end

function Economy.KillReward(zombieType: string, wave: number): number
	local base = E.KillReward[zombieType] or 1
	return base * Economy.Multiplier(wave)
end

function Economy.WaveBonus(wave: number): number
	return (E.WaveBonusBase + E.WaveBonusPerWave * wave) * Economy.Multiplier(wave)
end

Players.PlayerRemoving:Connect(function(player)
	fractions[player] = nil
end)

return Economy
