-- Berechnet alle Positionen der Zombie-Map aus Config.Map.
-- X-Achse: links (Zombies) -> rechts (Huette). Z-Achse: oben (-) / unten (+).

local Config = require(script.Parent.Config)

local M = Config.Map
local Layout = {}

Layout.Origin = M.Origin

Layout.CenterMinX = -M.CenterWidth / 2
Layout.CenterMaxX = M.CenterWidth / 2
Layout.LaneMinX = Layout.CenterMinX - M.LaneLength
Layout.HutAreaMinX = Layout.CenterMaxX
Layout.HutAreaMaxX = Layout.CenterMaxX + M.HutAreaLength

Layout.HutSize = Vector3.new(16, 10, 16)
Layout.HutCenterX = Layout.HutAreaMinX + 22
Layout.HutFrontX = Layout.HutCenterX - Layout.HutSize.X / 2

function Layout.World(x: number, y: number, z: number): Vector3
	return M.Origin + Vector3.new(x, y, z)
end

-- Weg der Zombies (Bodenhoehe)
Layout.ZombieStart = Layout.World(Layout.LaneMinX + 4, 0, 0)
Layout.ZombieEnd = Layout.World(Layout.HutFrontX - 1.5, 0, 0)
Layout.ZombieSpreadZ = 6 -- Zombies laufen leicht versetzt

Layout.PlayerSpawn = Layout.World(Layout.HutAreaMaxX - 6, 4, -7)
Layout.ReturnPortal = Layout.World(Layout.HutAreaMaxX - 6, 0, 7)

-- Pet-Plaetze: nur oben und unten am Rand des Mittelteils
Layout.Slots = {}
do
	local n = M.SlotsPerSide
	local slotZ = M.PathHalfWidth + M.SlotDistanceFromPath
	for _, side in { "Top", "Bottom" } do
		local sign = if side == "Top" then -1 else 1
		for i = 1, n do
			local x = Layout.CenterMinX + M.CenterWidth * (i - 0.5) / n
			table.insert(Layout.Slots, {
				Id = side .. i,
				Side = side,
				Position = Layout.World(x, 0, sign * slotZ),
				-- Blickrichtung zum Weg
				FacePosition = Layout.World(x, 0, 0),
			})
		end
	end
end

-- Bereich, in dem ein Spieler als "im Zombie-Modus" gilt
Layout.BoundsMin = Layout.World(Layout.LaneMinX - 10, -20, -M.CenterDepth / 2 - 10)
Layout.BoundsMax = Layout.World(Layout.HutAreaMaxX + 10, 80, M.CenterDepth / 2 + 10)

function Layout.IsInside(position: Vector3): boolean
	local a, b = Layout.BoundsMin, Layout.BoundsMax
	return position.X >= a.X
		and position.X <= b.X
		and position.Y >= a.Y
		and position.Y <= b.Y
		and position.Z >= a.Z
		and position.Z <= b.Z
end

return Layout
