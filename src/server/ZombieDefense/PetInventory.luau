-- Verbindung zu deinem Pet-System.
-- Falls deine Pets anders gespeichert sind, nur GetPets() anpassen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.ZombieDefense.Config)

local PetInventory = {}

-- Gibt die Pet-Namen eines Spielers zurueck (doppelte Namen = mehrere Exemplare).
-- Standard: Ordner player.Pets; jedes Kind ist ein Pet. Der Name kommt aus
-- dem Attribut "PetName", einem StringValue-Wert oder dem Namen des Kindes.
function PetInventory.GetPets(player: Player): { string }
	local result = {}
	local folder = player:FindFirstChild(Config.Inventory.PlayerFolderName)
	if folder then
		for _, child in folder:GetChildren() do
			local name = child:GetAttribute("PetName")
			if typeof(name) ~= "string" then
				name = if child:IsA("StringValue") and child.Value ~= "" then child.Value else child.Name
			end
			table.insert(result, name)
		end
	end
	if #result == 0 then
		for _, name in Config.Inventory.StarterPets do
			table.insert(result, name)
		end
	end
	return result
end

-- Sucht ein Model fuer das Pet in ReplicatedStorage/ServerStorage
function PetInventory.FindTemplate(petName: string): Model?
	for _, container in { ReplicatedStorage, ServerStorage } do
		for _, folderName in Config.Inventory.ModelFolderNames do
			local folder = container:FindFirstChild(folderName)
			local model = folder and folder:FindFirstChild(petName)
			if model and model:IsA("Model") then
				return model
			end
		end
	end
	return nil
end

return PetInventory
