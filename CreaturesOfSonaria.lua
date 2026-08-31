--[[
    Script: Natrix FRONTEND
]]

-- Services.
local playersService    = game:GetService("Players")
local runService        = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local lighting          = game:GetService("Lighting")
local userInputService  = game:GetService("UserInputService")

local localPlayer = playersService.LocalPlayer

-- Load and patch UI library.
local librarySource = game:HttpGet("https://raw.githubusercontent.com/ntxcrim69/NatrixLibrary/refs/heads/main/NatrixLibrary.lua")

local success, result = pcall(function()
	return loadstring(librarySource)()
end)
local Library = success and result or loadstring(game:HttpGet("https://raw.githubusercontent.com/ntxcrim69/NatrixLibrary/refs/heads/main/NatrixLibrary.lua"))()

local Window = Library:CreateWindow({
	Name = "Natrix Pro",
	KeySystem = true,
	KeySettings = {
		Keys = {"123", "KEY_ADMIN_2026"},
		Discord = "https://discord.gg/T4gcwqxQCz"
	}
})

-- Tabs.
local VisualsTab   = Window:CreateTab("Visuals")
local TeleportsTab = Window:CreateTab("Teleports")
local AutoTab      = Window:CreateTab("Auto")
local CombatTab    = Window:CreateTab("Combat")

-- Constants.
local SAFE_ZONE_AIR_POS   = Vector3.new(-1654, 285, -1012)
local SAFE_ZONE_WATER_POS = Vector3.new(-1654, 55, -1012)

local LAND_TELEPORTS = {
	{"Jungle",            Vector3.new(2488, 269, -982)},
	{"Mountains",         Vector3.new(-1629, 424, -918)},
	{"Mesa",              Vector3.new(-2324, 239, 223)},
	{"Central Rockfaces", Vector3.new(558, 279, -594)},
	{"Swamp Hollow",      Vector3.new(1136, 207, -2425)},
	{"Desert",            Vector3.new(-1437, 301, 1151)},
	{"Volcano Island",    Vector3.new(2307, 216, 615)},
	{"Flower Cove",       Vector3.new(47, 218, 1446)},
	{"Tundra",            Vector3.new(-1364, 377, -2328)},
	{"Redwoods",          Vector3.new(302, 220, -1296)},
	{"Pride Rocks",       Vector3.new(1827, 181, -316)},
}

local WATER_TELEPORTS = {
	{"Algae Sandbar",    Vector3.new(1133, 92, -1552)},
	{"Coral Reef",       Vector3.new(1109, 93, 1193)},
	{"Seaweed Depths",   Vector3.new(-33, 137, 1261)},
	{"Grassy Shoal",     Vector3.new(-703, 162, 2407)},
	{"Forgotten Shores", Vector3.new(-543, 236, 2949)},
	{"Deep Sea",         Vector3.new(1001, -512, 636)},
}

local ESP_CONFIG = {
	Explorer = {kw = "explorer", txt = "Explorer Token", clr = Color3.fromRGB(100, 255, 100)},
	Galaxy   = {kw = "galaxy",   txt = "Galaxy Token",   clr = Color3.fromRGB(255, 100, 255)},
	Mecha    = {kw = "mecha",    txt = "Mecha Token",    clr = Color3.fromRGB(100, 100, 255)},
	Monster  = {kw = "monster",  txt = "Monster Token",  clr = Color3.fromRGB(255, 50, 50)},
	Sweet    = {kw = "sweet",    txt = "Sweet Token",    clr = Color3.fromRGB(255, 200, 50)},
	Egg      = {kw = "egg",      txt = "Abandoned Egg",  clr = Color3.fromRGB(255, 255, 100)},
}

local DIET_FOOD_TABLE = {
	Carnivore = {"Carnivore Carcass", "Omnivore Carcass", "NPC Carcass", "Carcass", "Ribs", "Sea Ribs", "Plant Carcass"},
	Herbivore = {"Grass", "Berries", "Algae", "Seaweed Pods", "Sea Grapes", "Plant Carcass", "Fruit"},
	Omnivore  = {"Carnivore Carcass", "Omnivore Carcass", "NPC Carcass", "Carcass", "Ribs", "Sea Ribs", "Grass", "Berries", "Algae", "Seaweed Pods", "Sea Grapes", "Plant Carcass", "Fruit"},
}

-- State.
local isUnderwaterMode  = false
local airPlatform       = nil
local waterPlatform     = nil
local autoReturnEnabled = false

local activeEspCategories = {}
local currentEspElements  = {}
local lastEspScan         = 0

local espShroomsEnabled = false
local shroomHighlights  = {}
local lastShroomUpdate  = 0

local hiddenLightingElements = {}
local fogConnection          = nil

local autoEatEnabled  = false
local hungerThreshold = 50
local isEating        = false
local lastEatScan     = 0

local autoDrinkEnabled = false
local thirstThreshold  = 50
local isDrinking       = false
local lastDrinkScan    = 0

local autoTokenEnabled  = false
local isCollectingToken = false
local lastTokenScan     = 0

local fastEatEnabled   = false
local fastDrinkEnabled = false
local lastFastEat      = 0
local lastFastDrink    = 0

local autoShroomEnabled  = false
local isCollectingShroom = false
local lastShroomScan     = 0

local hitboxEnabled     = false
local hitboxSize        = 10
local originalSizes     = {}
local hitboxHighlights  = {}
local hitboxConnections = {}

-- Infinite stamina state.
local infiniteStaminaEnabled = false
local uisNamecallHook        = nil
local hookedStaminaFuncs     = {}
local staminaFireServerHook  = nil

-- ============================================================
-- UTILITY
-- ============================================================

local function createPlatform(position, color)
	local part = Instance.new("Part")
	part.Size         = Vector3.new(40, 1, 40)
	part.Position     = position - Vector3.new(0, 4, 0)
	part.Anchored     = true
	part.Transparency = 0.5
	part.Color        = color
	part.CanCollide   = true
	part.Parent       = workspace
	return part
end

local function teleportTo(position)
	local character = localPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then rootPart.CFrame = CFrame.new(position) end
end

local function movePlayerTo(targetPos)
	local character = localPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	local isLowAltitude = targetPos.Y < 60
	if humanoid then humanoid.AutoRotate = false end

	if isLowAltitude then
		rootPart.CFrame = CFrame.new(targetPos + Vector3.new(30, -10, 0))
		task.wait(0.3)
		rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
	else
		rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 55, 0))
		task.wait(0.1)
		local startY, endY, startTime = targetPos.Y + 55, targetPos.Y + 3, tick()
		while tick() - startTime < 2 do
			if rootPart.Parent then
				rootPart.CFrame = CFrame.new(targetPos.X, startY + (endY - startY) * ((tick() - startTime) / 2), targetPos.Z)
			end
			task.wait(0.03)
		end
		rootPart.CFrame = CFrame.new(targetPos.X, endY, targetPos.Z)
	end

	task.wait(0.5)
	if humanoid then humanoid.AutoRotate = true end
end

local function returnToSafeZone()
	if not autoReturnEnabled then return end
	local character = localPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local targetPos        = isUnderwaterMode and SAFE_ZONE_WATER_POS or SAFE_ZONE_AIR_POS
	local existingPlatform = isUnderwaterMode and waterPlatform or airPlatform

	if not existingPlatform then
		local color    = isUnderwaterMode and Color3.fromRGB(0, 255, 128) or Color3.fromRGB(0, 191, 255)
		local platform = createPlatform(targetPos, color)
		if isUnderwaterMode then waterPlatform = platform else airPlatform = platform end
	end

	rootPart.CFrame = CFrame.new(targetPos)
end

-- ============================================================
-- STAT READING
-- ============================================================

local function getStatPercentage(statName)
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return 0 end
	local hudGui = playerGui:FindFirstChild("HUDGui") or playerGui:FindFirstChild("MainGui") or playerGui:FindFirstChildOfClass("ScreenGui")
	if not hudGui then return 0 end

	for _, btn in ipairs(hudGui:GetDescendants()) do
		if (btn:IsA("ImageButton") or btn:IsA("Frame") or btn:IsA("TextButton"))
			and (btn.Name == statName or btn.Name:lower():find(statName:lower())) then
			local hoverLabel = btn:FindFirstChild("HoverLabel") or btn:FindFirstChildWhichIsA("TextLabel")
			if hoverLabel and hoverLabel:IsA("TextLabel") then
				local val = tonumber(hoverLabel.Text:match("%((%d+)%%%)")) or tonumber(hoverLabel.Text:match("(%d+)"))
				if val then return val end
			end
		end
	end
	return 0
end

local function getDietType()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return "Carnivore" end
	local hudGui = playerGui:FindFirstChild("HUDGui") or playerGui:FindFirstChildOfClass("ScreenGui")
	if hudGui then
		for _, lbl in ipairs(hudGui:GetDescendants()) do
			if lbl:IsA("TextLabel") and (lbl.Name == "HoverLabel" or lbl.Name:lower():find("diet")) then
				local text = lbl.Text:lower()
				if text:find("carnivore") then return "Carnivore" end
				if text:find("herbivore") then return "Herbivore" end
				if text:find("omnivore") then return "Omnivore" end
			end
		end
	end
	return "Carnivore"
end

-- ============================================================
-- FOOD / DRINK HELPERS
-- ============================================================

local function isFoodValid(foodObj)
	if not foodObj or not foodObj.Parent then return false end
	for _, desc in ipairs(foodObj:GetDescendants()) do
		if desc:IsA("BillboardGui") then
			local label = desc:FindFirstChildWhichIsA("TextLabel")
			if label and label.Text == "0" then return false end
		end
	end
	return true
end

local function getObjectPosition(obj)
	if obj:IsA("BasePart") then return obj.Position end
	if obj:IsA("Model") then
		local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
		if primary then return primary.Position end
	end
	return nil
end

local function findNearestFood(dietType)
	local character = localPlayer.Character
	if not character then return nil end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local validFoods = DIET_FOOD_TABLE[dietType]
	if not validFoods then return nil end

	local interactions = workspace:FindFirstChild("Interactions")
	if not interactions then return nil end
	local foodFolder = interactions:FindFirstChild("Food")
	if not foodFolder then return nil end

	local closestFood, minDistance = nil, 99999

	for _, obj in ipairs(foodFolder:GetChildren()) do
		for _, foodName in ipairs(validFoods) do
			if obj.Name == foodName and isFoodValid(obj) then
				local pos = getObjectPosition(obj)
				if pos then
					local dist = (rootPart.Position - pos).Magnitude
					if dist < minDistance then
						minDistance = dist
						closestFood = obj
					end
				end
				break
			end
		end
	end
	return closestFood
end

local function findNearestLake()
	local character = localPlayer.Character
	if not character then return nil end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local interactions = workspace:FindFirstChild("Interactions")
	if not interactions then return nil end
	local lakesFolder = interactions:FindFirstChild("Lakes")
	if not lakesFolder then return nil end

	local closestLake, minDistance = nil, 99999

	for _, lake in ipairs(lakesFolder:GetChildren()) do
		local part = lake:FindFirstChildWhichIsA("BasePart") or (lake:IsA("Model") and lake.PrimaryPart)
		if part then
			local dist = (rootPart.Position - part.Position).Magnitude
			if dist < minDistance then
				minDistance = dist
				closestLake = lake
			end
		end
	end
	return closestLake
end

-- ============================================================
-- ESP
-- ============================================================

local function getEspCategory(object)
	local nameLower = object.Name:lower()
	for category, info in pairs(ESP_CONFIG) do
		if activeEspCategories[category] and nameLower:find(info.kw) then
			return category
		end
	end
	return nil
end

local function addEsp(object, category)
	if object:FindFirstChild("NatrixESP") then return end
	local info = ESP_CONFIG[category]

	local billboard = Instance.new("BillboardGui")
	billboard.Name          = "NatrixESP"
	billboard.Size          = UDim2.new(0, 200, 0, 50)
	billboard.AlwaysOnTop   = true
	billboard.ExtentsOffset = Vector3.new(0, 3, 0)
	billboard.Parent        = object

	local textLabel = Instance.new("TextLabel")
	textLabel.Size                   = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text                   = info.txt
	textLabel.TextColor3             = info.clr
	textLabel.TextSize               = 14
	textLabel.Font                   = Enum.Font.SourceSansBold
	textLabel.Parent                 = billboard

	currentEspElements[object] = category
end

local function removeEsp(object)
	local esp = object:FindFirstChild("NatrixESP")
	if esp then esp:Destroy() end
	currentEspElements[object] = nil
end

local function clearAllEsp()
	for object in pairs(currentEspElements) do
		removeEsp(object)
	end
end

local function isTargetObject(object)
	local nameLower = object.Name:lower()
	if nameLower:find("token") or nameLower:find("egg") or nameLower:find("capsule") or nameLower:find("spawner") then
		if object:IsA("MeshPart") and object.MeshId ~= "" then return true end
		if object:IsA("Model") and object:FindFirstChildWhichIsA("MeshPart") then return true end
	end
	return false
end

local function setEspCategoryState(category, enabled)
	activeEspCategories[category] = enabled
	if not enabled then
		for obj, cat in pairs(currentEspElements) do
			if cat == category then removeEsp(obj) end
		end
	end
end

local function updateEsp()
	if tick() - lastEspScan < 5 then return end
	lastEspScan = tick()

	local anyActive = false
	for _, active in pairs(activeEspCategories) do
		if active then anyActive = true break end
	end
	if not anyActive then clearAllEsp() return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if not isTargetObject(obj) then continue end
		local category = getEspCategory(obj)
		if category then
			if not currentEspElements[obj] then addEsp(obj, category) end
		else
			if currentEspElements[obj] then removeEsp(obj) end
		end
	end
end

-- ============================================================
-- SHROOM ESP
-- ============================================================

local function clearShroomHighlights()
	for _, highlight in ipairs(shroomHighlights) do
		if highlight and highlight.Parent then highlight:Destroy() end
	end
	table.clear(shroomHighlights)
end

local function getShroomColor(model)
	local rarity = model:GetAttribute("Rarity")
	if rarity == "Gold" then return Color3.fromRGB(255, 215, 0) end
	if rarity == "Silver" then return Color3.fromRGB(192, 192, 192) end
	return Color3.fromRGB(255, 50, 50)
end

local function updateShroomEsp()
	clearShroomHighlights()
	local interactions = workspace:FindFirstChild("Interactions")
	if not interactions then return end
	local shroomPiles = interactions:FindFirstChild("ShoomPiles")
	if not shroomPiles then return end
	for _, model in ipairs(shroomPiles:GetChildren()) do
		if not (model:IsA("Model") and model.Parent) then continue end
		local color = getShroomColor(model)
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local highlight = Instance.new("Highlight")
				highlight.Parent           = descendant
				highlight.FillColor        = color
				highlight.OutlineColor     = color
				highlight.FillTransparency = 0.5
				table.insert(shroomHighlights, highlight)
			end
		end
	end
end

-- ============================================================
-- HITBOX EXTENDER
-- ============================================================

local function addHitboxHighlight(character)
	if hitboxHighlights[character] then return end
	local highlight = Instance.new("Highlight")
	highlight.Name                = "NatrixHitboxHL"
	highlight.FillColor           = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor        = Color3.fromRGB(255, 100, 100)
	highlight.FillTransparency    = 0.6
	highlight.OutlineTransparency = 0
	highlight.Parent              = character
	hitboxHighlights[character]   = highlight
end

local function removeHitboxHighlight(character)
	if hitboxHighlights[character] then
		hitboxHighlights[character]:Destroy()
		hitboxHighlights[character] = nil
	end
end

local function applyHitboxToCharacter(character)
	if not hitboxEnabled then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if not originalSizes[part] then
				originalSizes[part] = {size = part.Size, ltm = part.LocalTransparencyModifier}
			end
			part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
			part.LocalTransparencyModifier = 1
		end
	end
	addHitboxHighlight(character)
end

local function restoreHitboxForCharacter(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if originalSizes[part] then
				part.Size = originalSizes[part].size
				part.LocalTransparencyModifier = originalSizes[part].ltm
				originalSizes[part] = nil
			end
		end
	end
	removeHitboxHighlight(character)
end

local function disconnectHitboxConnections()
	for _, conn in ipairs(hitboxConnections) do
		conn:Disconnect()
	end
	table.clear(hitboxConnections)
end

local function enableHitbox()
	disconnectHitboxConnections()
	table.clear(originalSizes)

	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			applyHitboxToCharacter(player.Character)
		end
	end

	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= localPlayer then
			local conn = player.CharacterAdded:Connect(function(character)
				task.wait(1)
				applyHitboxToCharacter(character)
			end)
			table.insert(hitboxConnections, conn)
		end
	end

	local joinConn = playersService.PlayerAdded:Connect(function(player)
		if player == localPlayer then return end
		local conn = player.CharacterAdded:Connect(function(character)
			task.wait(1)
			applyHitboxToCharacter(character)
		end)
		table.insert(hitboxConnections, conn)
	end)
	table.insert(hitboxConnections, joinConn)
end

local function disableHitbox()
	disconnectHitboxConnections()
	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			restoreHitboxForCharacter(player.Character)
		end
	end
	table.clear(originalSizes)
end

-- ============================================================
-- INFINITE STAMINA
-- ============================================================

local function isStaminaDrainCandidate(fn)
	if iscclosure(fn) or isexecutorclosure(fn) then return false end
	local ok, consts = pcall(debug.getconstants, fn)
	if not ok or type(consts) ~= "table" then return false end
	local staminaHits, sprintHits = 0, 0
	for _, c in pairs(consts) do
		if type(c) == "string" then
			local lower = c:lower()
			if lower:find("stamina") or lower:find("stam") then staminaHits += 1 end
			if lower:find("sprint") or lower:find("running") then sprintHits += 1 end
		end
	end
	return staminaHits >= 1 and sprintHits >= 1
end

local function hookStaminaDrainFunctions()
	local candidates = getgc(false)
	for _, fn in ipairs(candidates) do
		if type(fn) ~= "function" then continue end
		if hookedStaminaFuncs[fn] then continue end
		if not isStaminaDrainCandidate(fn) then continue end

		local ok, original = pcall(hookfunction, fn, newcclosure(function(...)
			if infiniteStaminaEnabled then return end
			return original(...)
		end))

		if ok then
			hookedStaminaFuncs[fn] = original
		end
	end
end

local function installUisHook()
	if uisNamecallHook then return end
	uisNamecallHook = hookmetamethod(userInputService, "__namecall", newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if infiniteStaminaEnabled and method == "IsKeyDown" then
			local key = select(1, ...)
			if key == Enum.KeyCode.LeftShift then
				return false
			end
		end
		return uisNamecallHook(self, ...)
	end))
end

local function installFireServerHook()
	if staminaFireServerHook then return end
	staminaFireServerHook = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if infiniteStaminaEnabled and (method == "FireServer" or method == "InvokeServer") then
			if typeof(self) == "Instance" then
				local nameLower = self.Name:lower()
				if nameLower:find("sprint") or nameLower:find("stamina") or nameLower:find("stam") or nameLower:find("run") then
					return
				end
			end
		end
		return staminaFireServerHook(self, ...)
	end))
end

local function enableInfiniteStamina()
	installUisHook()
	installFireServerHook()
	hookStaminaDrainFunctions()
end

-- ============================================================
-- AUTO MUSHROOM
-- ============================================================

-- Checks if a shroom model is actually still collectible.
-- Depleted shrooms stay in the workspace but get flagged via attribute or BillboardGui.
local function isShroomValid(model)
	if not model or not model.Parent then return false end
	-- Check common depletion attributes the game sets to 0.
	local amount = model:GetAttribute("Amount") or model:GetAttribute("Quantity") or model:GetAttribute("Uses")
	if amount ~= nil and amount <= 0 then return false end
	-- Check BillboardGui quantity label (same pattern as isFoodValid).
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BillboardGui") then
			local label = desc:FindFirstChildWhichIsA("TextLabel")
			if label and (tonumber(label.Text) or 1) == 0 then return false end
		end
	end
	-- Must still have physical parts.
	return model:FindFirstChildWhichIsA("BasePart") ~= nil
end

local function getShroomPosition(model)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if primary then return primary.Position end
	return nil
end

local function findNearestShroom()
	local character = localPlayer.Character
	if not character then return nil end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local interactions = workspace:FindFirstChild("Interactions")
	if not interactions then return nil end
	local shroomPiles = interactions:FindFirstChild("ShoomPiles")
	if not shroomPiles then return nil end

	local closestShroom, minDistance = nil, 99999

	for _, model in ipairs(shroomPiles:GetChildren()) do
		if not (model:IsA("Model") and isShroomValid(model)) then continue end
		local pos = getShroomPosition(model)
		if pos then
			local dist = (rootPart.Position - pos).Magnitude
			if dist < minDistance then
				minDistance = dist
				closestShroom = model
			end
		end
	end
	return closestShroom
end

local function processAutoShroom()
	if tick() - lastShroomScan < 5 then return end
	lastShroomScan = tick()
	if not autoShroomEnabled or isCollectingShroom then return end

	local shroom = findNearestShroom()
	if not isShroomValid(shroom) then return end

	local pos = getShroomPosition(shroom)
	if not pos then return end

	isCollectingShroom = true
	movePlayerTo(pos)
	task.wait(1.5)

	-- Re-validate after movement; shroom may have been collected or despawned.
	if not isShroomValid(shroom) then
		isCollectingShroom = false
		return
	end

	local remotes = replicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local shroomRemote = remotes:FindFirstChild("ShoomRemote")
			or remotes:FindFirstChild("MushroomRemote")
			or remotes:FindFirstChild("Shroom")
			or remotes:FindFirstChild("Mushroom")
		if shroomRemote then
			for _ = 1, 5 do
				if not isShroomValid(shroom) then break end
				shroomRemote:FireServer(shroom)
				task.wait(0.3)
			end
		else
			local primary = shroom.PrimaryPart or shroom:FindFirstChildWhichIsA("BasePart")
			if primary then
				local rootPart = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					rootPart.CFrame = CFrame.new(primary.Position + Vector3.new(0, 2, 0))
					task.wait(1)
				end
			end
		end
	end

	returnToSafeZone()
	task.wait(3)
	isCollectingShroom = false
end

-- ============================================================
-- AUTO LOOPS
-- ============================================================

local function processAutoEat()
	if tick() - lastEatScan < 5 then return end
	lastEatScan = tick()
	if not autoEatEnabled or isEating then return end
	if getStatPercentage("Hunger") >= hungerThreshold then return end

	isEating = true
	local food = findNearestFood(getDietType())
	if food then
		local pos = getObjectPosition(food)
		if pos then
			movePlayerTo(pos)
			task.wait(1.5)
			for _ = 1, 10 do
				if getStatPercentage("Hunger") >= 100 or not isFoodValid(food) then break end
				local remotes = replicatedStorage:FindFirstChild("Remotes")
				if remotes and remotes:FindFirstChild("Food") then
					remotes.Food:FireServer(food)
				end
				task.wait(0.3)
			end
			returnToSafeZone()
		end
	end
	task.wait(3)
	isEating = false
end

local function processAutoDrink()
	if tick() - lastDrinkScan < 5 then return end
	lastDrinkScan = tick()
	if not autoDrinkEnabled or isDrinking then return end
	if getStatPercentage("Thirst") >= thirstThreshold then return end

	isDrinking = true
	local lake = findNearestLake()
	if lake then
		local part = lake:FindFirstChildWhichIsA("BasePart") or (lake:IsA("Model") and lake.PrimaryPart)
		if part then
			movePlayerTo(part.Position)
			task.wait(1.5)
			for _ = 1, 10 do
				if getStatPercentage("Thirst") >= 100 then break end
				local remotes = replicatedStorage:FindFirstChild("Remotes")
				if remotes and remotes:FindFirstChild("DrinkRemote") then
					remotes.DrinkRemote:FireServer(lake)
				end
				task.wait(0.3)
			end
			returnToSafeZone()
		end
	end
	task.wait(3)
	isDrinking = false
end

local function processFastEat()
	if not fastEatEnabled then return end
	if tick() - lastFastEat < 0.1 then return end
	lastFastEat = tick()
	if getStatPercentage("Hunger") >= 100 then return end

	local food = findNearestFood(getDietType())
	if not food or not isFoodValid(food) then return end
	local remotes = replicatedStorage:FindFirstChild("Remotes")
	if remotes and remotes:FindFirstChild("Food") then
		remotes.Food:FireServer(food)
	end
end

local function processFastDrink()
	if not fastDrinkEnabled then return end
	if tick() - lastFastDrink < 0.1 then return end
	lastFastDrink = tick()
	if getStatPercentage("Thirst") >= 100 then return end

	local lake = findNearestLake()
	if not lake then return end
	local remotes = replicatedStorage:FindFirstChild("Remotes")
	if remotes and remotes:FindFirstChild("DrinkRemote") then
		remotes.DrinkRemote:FireServer(lake)
	end
end

local function getSpawnedToken()
	local interactions = workspace:FindFirstChild("Interactions")
	if not interactions then return nil end
	local spawnedTokens = interactions:FindFirstChild("SpawnedTokens")
	if not spawnedTokens then return nil end
	for _, token in ipairs(spawnedTokens:GetChildren()) do
		if token:IsA("MeshPart") and token.Parent then return token end
	end
	return nil
end

local function processAutoToken()
	if tick() - lastTokenScan < 10 then return end
	lastTokenScan = tick()
	if not autoTokenEnabled or isCollectingToken then return end

	local token = getSpawnedToken()
	if not (token and token.Parent) then return end

	isCollectingToken = true
	movePlayerTo(token.Position)
	task.wait(1.5)
	local remotes = replicatedStorage:FindFirstChild("Remotes")
	if remotes and remotes:FindFirstChild("GetSpawnedTokenRemote") then
		remotes.GetSpawnedTokenRemote:InvokeServer()
	end
	task.wait(1)
	if token and token.Parent then token:Destroy() end
	returnToSafeZone()
	task.wait(5)
	isCollectingToken = false
end

runService.Heartbeat:Connect(function()
	updateEsp()

	if espShroomsEnabled and tick() - lastShroomUpdate > 3 then
		lastShroomUpdate = tick()
		updateShroomEsp()
	end

	processAutoEat()
	processAutoDrink()
	processFastEat()
	processFastDrink()
	processAutoToken()
	processAutoShroom()
end)

-- ============================================================
-- VISUALS TAB
-- ============================================================

VisualsTab:CreateToggle("ESP Tokens", false, function(state)
	setEspCategoryState("Explorer", state)
	setEspCategoryState("Galaxy",   state)
	setEspCategoryState("Mecha",    state)
	setEspCategoryState("Monster",  state)
	setEspCategoryState("Sweet",    state)
end)

VisualsTab:CreateToggle("ESP Abandoned Eggs", false, function(state)
	setEspCategoryState("Egg", state)
end)

VisualsTab:CreateToggle("ESP Shrooms", false, function(state)
	espShroomsEnabled = state
	if not state then clearShroomHighlights() end
end)

VisualsTab:CreateToggle("No Fog", false, function(enabled)
	if enabled then
		lighting.FogStart = 0
		lighting.FogEnd   = 9e9
		for _, child in pairs(lighting:GetChildren()) do
			if child:IsA("Atmosphere") or child:IsA("Clouds") or child:IsA("Sky") or child:IsA("PostEffect") then
				if not hiddenLightingElements[child] then
					hiddenLightingElements[child] = child.Parent
				end
				child.Parent = nil
			end
		end
		fogConnection = lighting.ChildAdded:Connect(function(child)
			if child:IsA("Atmosphere") or child:IsA("Clouds") or child:IsA("Sky") then
				task.defer(function()
					if not hiddenLightingElements[child] then
						hiddenLightingElements[child] = child.Parent
					end
					child.Parent = nil
				end)
			end
		end)
	else
		if fogConnection then fogConnection:Disconnect() fogConnection = nil end
		for child, parent in pairs(hiddenLightingElements) do
			if child then child.Parent = parent end
		end
		table.clear(hiddenLightingElements)
	end
end)

VisualsTab:CreateButton("FPS Boost", "Apply", nil, function()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Texture") or descendant:IsA("Decal") then
			descendant:Destroy()
		end
	end
end)

-- ============================================================
-- TELEPORTS TAB
-- ============================================================

TeleportsTab:CreateButton("Safe Zone", "Teleport", Enum.KeyCode.L, function()
	if airPlatform then airPlatform:Destroy() airPlatform = nil end
	isUnderwaterMode = false
	airPlatform = createPlatform(SAFE_ZONE_AIR_POS, Color3.fromRGB(0, 191, 255))
	teleportTo(SAFE_ZONE_AIR_POS)
end)

TeleportsTab:CreateButton("Safe Zone (Underwater)", "Teleport", Enum.KeyCode.U, function()
	if waterPlatform then waterPlatform:Destroy() waterPlatform = nil end
	isUnderwaterMode = true
	waterPlatform = createPlatform(SAFE_ZONE_WATER_POS, Color3.fromRGB(0, 255, 128))
	teleportTo(SAFE_ZONE_WATER_POS)
end)

for _, tp in ipairs(LAND_TELEPORTS) do
	local name, pos = tp[1], tp[2]
	TeleportsTab:CreateButton(name, "Teleport", Enum.KeyCode.Unknown, function()
		teleportTo(pos)
	end)
end

for _, tp in ipairs(WATER_TELEPORTS) do
	local name, pos = tp[1], tp[2]
	TeleportsTab:CreateButton(name, "Teleport", Enum.KeyCode.Unknown, function()
		teleportTo(pos)
	end)
end

-- ============================================================
-- AUTO TAB
-- ============================================================

AutoTab:CreateToggle("Auto Eat", false, function(state)
	autoEatEnabled = state
end)

AutoTab:CreateSlider("Hunger Threshold", 1, 99, 50, function(val)
	hungerThreshold = val
end)

AutoTab:CreateToggle("Auto Drink", false, function(state)
	autoDrinkEnabled = state
end)

AutoTab:CreateSlider("Thirst Threshold", 1, 99, 50, function(val)
	thirstThreshold = val
end)

AutoTab:CreateToggle("Fast Eat", false, function(state)
	fastEatEnabled = state
end)

AutoTab:CreateToggle("Fast Drink", false, function(state)
	fastDrinkEnabled = state
end)

AutoTab:CreateToggle("Auto Token", false, function(state)
	autoTokenEnabled = state
end)

AutoTab:CreateToggle("Auto Mushroom", false, function(state)
	autoShroomEnabled = state
end)

AutoTab:CreateToggle("Auto Return to Safe Zone", false, function(state)
	autoReturnEnabled = state
end)

AutoTab:CreateToggle("Safe Zone Underwater Mode", false, function(state)
	isUnderwaterMode = state
end)

-- ============================================================
-- COMBAT TAB
-- ============================================================

CombatTab:CreateToggle("Hitbox Extender Coming Soon..", false, function(state)
	hitboxEnabled = state
	if state then
		enableHitbox()
	else
		disableHitbox()
	end
end)

CombatTab:CreateSlider("Hitbox Size", 1, 50, 10, function(val)
	hitboxSize = val
	if not hitboxEnabled then return end
	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			restoreHitboxForCharacter(player.Character)
		end
	end
	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			applyHitboxToCharacter(player.Character)
		end
	end
end)

CombatTab:CreateToggle("Infinite Stamina Coming Soon..", false, function(state)
	infiniteStaminaEnabled = state
	if state then
		enableInfiniteStamina()
	end
end)
