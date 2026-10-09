-- Liefert Seltenheit, Element und Kampfwerte fuer ein Pet.

local Config = require(script.Parent.Config)

export type PetInfo = {
	Name: string,
	Rarity: string,
	Element: string,
	Damage: number,
	Range: number,
	Cooldown: number,
}

local PetData = {}

function PetData.Get(petName: string, template: Instance?): PetInfo
	local entry = Config.Pets[petName] or Config.DefaultPet
	local rarity = entry.Rarity
	local element = entry.Element

	-- Attribute am Pet-Model haben Vorrang
	if template then
		local r = template:GetAttribute("Rarity")
		local e = template:GetAttribute("Element")
		if typeof(r) == "string" and Config.Rarities[r] then
			rarity = r
		end
		if typeof(e) == "string" and Config.Elements[e] then
			element = e
		end
	end

	if not Config.Rarities[rarity] then
		rarity = "Common"
	end
	if not Config.Elements[element] then
		element = "Normal"
	end

	local stats = Config.Rarities[rarity]
	return {
		Name = petName,
		Rarity = rarity,
		Element = element,
		Damage = stats.Damage,
		Range = stats.Range,
		Cooldown = stats.Cooldown,
	}
end

function PetData.RarityOrder(rarity: string): number
	local r = Config.Rarities[rarity]
	return if r then r.Order else 0
end

return PetData
