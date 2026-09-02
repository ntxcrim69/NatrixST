local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ntxcrim69/NatrixLibrary/refs/heads/main/NatrixLibrary.lua"))()

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local lightingService = game:GetService("Lighting")
local debrisService = game:GetService("Debris")
local vim = game:GetService("VirtualInputManager")

local localPlayer = playersService.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humRP = character:WaitForChild("HumanoidRootPart")
local entities = workspace:WaitForChild("Entities")

-- Constants.
local HITBOX_LEGIT_SIZE = 14
local HITBOX_RAGE_SIZE = 22

-- Window.
local Window = Library:CreateWindow({
	Name = "Potassium | Merged",
	KeySystem = false,
})

local CombatTab = Window:CreateTab("Combat")
local VisualsTab = Window:CreateTab("Visuals")
local MiscTab = Window:CreateTab("Misc")

-- ── Shared state ──────────────────────────────────────────────────────────
local stateOutline = false
local stateNames = false
local stateHealth = false
local hitboxMode = "Off"
local lichenFarmActive = false
local autoKillActive = false
local aimAssistActive = false
local aimAssistCD = false
local teleportActive = false
local antiRagdollActive = false
local antiKnockbackActive = false
local antiKnockbackConn = nil

-- ── ESP helpers ───────────────────────────────────────────────────────────
local function getESPBox(ePlayer)
	local enemyChar = ePlayer.Character
	if not enemyChar then return nil end
	local root = enemyChar:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local box = root:FindFirstChild("ESP_UI")
	if not box then
		box = Instance.new("BillboardGui")
		box.Name = "ESP_UI"
		box.Size = UDim2.new(4, 0, 2, 0)
		box.StudsOffset = Vector3.new(0, 4, 0)
		box.AlwaysOnTop = true
		box.Parent = root

		local nl = Instance.new("TextLabel")
		nl.Name = "PlayerName"
		nl.Size = UDim2.new(1, 0, 0.5, 0)
		nl.BackgroundTransparency = 1
		nl.TextColor3 = Color3.new(1, 1, 1)
		nl.TextStrokeTransparency = 0
		nl.TextTransparency = 1
		nl.Parent = box

		local hl = Instance.new("TextLabel")
		hl.Name = "HealthDisplay"
		hl.Position = UDim2.new(0, 0, 0.5, 0)
		hl.Size = UDim2.new(1, 0, 0.5, 0)
		hl.BackgroundTransparency = 1
		hl.TextColor3 = Color3.new(0, 1, 0)
		hl.TextStrokeTransparency = 0
		hl.TextTransparency = 1
		hl.Parent = box
	end
	return box
end

local function getHighlight(ePlayer)
	local enemyChar = ePlayer.Character
	if not enemyChar then return nil end
	local high = enemyChar:FindFirstChild("ESP_Highlight")
	if not high then
		high = Instance.new("Highlight")
		high.Name = "ESP_Highlight"
		high.FillTransparency = 1
		high.OutlineTransparency = 1
		high.Adornee = enemyChar
		high.Parent = enemyChar
	end
	return high
end

local function updateESP()
	for _, ep in playersService:GetPlayers() do
		if ep == localPlayer then continue end
		if stateOutline then
			local high = getHighlight(ep)
			if high then
				high.OutlineTransparency = 0
				high.FillTransparency = 0.5
			end
		end
		if stateNames or stateHealth then
			local box = getESPBox(ep)
			if box then
				local nl = box:FindFirstChild("PlayerName")
				local hl = box:FindFirstChild("HealthDisplay")
				if nl then
					nl.Text = ep.Name
					nl.TextTransparency = stateNames and 0 or 1
				end
				if hl then
					local hum = ep.Character and ep.Character:FindFirstChild("Humanoid")
					hl.Text = hum and math.floor(hum.Health) .. " HP" or "0 HP"
					hl.TextTransparency = stateHealth and 0 or 1
				end
			end
		end
	end
end

-- ── Hitbox extender ───────────────────────────────────────────────────────
local function applyHitboxMode(mode)
	hitboxMode = mode
	if mode ~= "Off" then return end
	for _, enemyChar in entities:GetChildren() do
		if enemyChar == character then continue end
		local head = enemyChar:FindFirstChild("Head")
		if head then
			head.Size = Vector3.new(2, 1, 1)
			head.Transparency = 0
		end
	end
end

-- ── Aim assist ────────────────────────────────────────────────────────────
local aimHitboxSize = Vector3.new(10, 7, 25)
local aimHitboxOffset = 7.5
local aimVelocity = 32.5
local aimDuration = 0.2
local aimLerp = 0.2

local Hitbox = {}
function Hitbox.Create(size, basePart, offset, lifeTime)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = (basePart or humRP).CFrame * (offset or CFrame.new())
	part.Anchored = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(212, 39, 255)
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = 0.6
	part.Parent = workspace
	debrisService:AddItem(part, lifeTime or 0.1)
	return part
end

function Hitbox.OnTouched(hitboxPart, cb)
	local debounce = {}
	hitboxPart.Touched:Connect(function(hit)
		local ec = hit:FindFirstAncestorOfClass("Model")
		if not ec then return end
		local eh = ec:FindFirstChildOfClass("Humanoid")
		if not eh or ec == character then return end
		if debounce[eh] then return end
		debounce[eh] = true
		cb(ec, eh, hit)
		task.delay(0.2, function() debounce[eh] = nil end)
	end)
end

local function doAimAssist()
	if not aimAssistActive or aimAssistCD or humanoid.Health <= 0 then return end
	aimAssistCD = true
	local hb = Hitbox.Create(aimHitboxSize, humRP, CFrame.new(0, 0, -aimHitboxOffset), 0.05)
	Hitbox.OnTouched(hb, function(ec, eh)
		local ehr = ec:FindFirstChild("HumanoidRootPart")
		if not ehr or eh.Health <= 0 then return end
		local att = Instance.new("Attachment", humRP)
		local lv = Instance.new("LinearVelocity", humRP)
		lv.Attachment0 = att
		lv.MaxForce = math.huge
		local conn
		conn = runService.Heartbeat:Connect(function()
			if not ehr or not ehr.Parent then conn:Disconnect() return end
			local dir = ehr.Position - humRP.Position
			local dist = dir.Magnitude
			if dist > 0 then
				lv.VectorVelocity = lv.VectorVelocity:Lerp(dir.Unit * math.clamp(dist * 6, 10, aimVelocity), aimLerp)
			end
		end)
		task.delay(aimDuration, function()
			conn:Disconnect()
			lv:Destroy()
			att:Destroy()
		end)
	end)
	task.delay(0.4, function() aimAssistCD = false end)
end

-- ── Auto Kill ─────────────────────────────────────────────────────────────
local function getBestTarget()
	local best, bestScore = nil, math.huge
	for _, target in entities:GetChildren() do
		if not target:IsA("Model") or target == character then continue end
		local hum = target:FindFirstChild("Humanoid")
		local hrp = target:FindFirstChild("HumanoidRootPart")
		if not (hum and hrp and hum.Health > 0) then continue end
		if hrp.Position.Y < -1 or hrp.Position.Y > 150 then continue end
		local dist = (humRP.Position - hrp.Position).Magnitude
		if dist > 300 then continue end
		local score = hum.Health * 5 + dist
		if score < bestScore then
			bestScore = score
			best = hrp
		end
	end
	return best
end

task.spawn(function()
	while task.wait(0.15) do
		if not autoKillActive or humanoid.Health <= 0 then continue end
		if humRP.Position.Y >= 150 then
			humRP.CFrame = CFrame.new(0, 758.75, 29.5)
			task.wait(1)
			continue
		end
		local targetHRP = getBestTarget()
		if not targetHRP then continue end
		local hum = targetHRP.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			humRP.CFrame = targetHRP.CFrame * CFrame.new(0, -1, 5)
			vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end
	end
end)

-- ── Lichen Farm ───────────────────────────────────────────────────────────
task.spawn(function()
	while task.wait(0.2) do
		if not lichenFarmActive or humanoid.Health <= 0 then continue end
		if humRP.Position.Y >= 150 then
			humRP.CFrame = CFrame.new(0, 754.75, 29.5)
			task.wait(1)
			continue
		end
		local frute = entities:FindFirstChild("Frute")
		if not frute then continue end
		local fruteHRP = frute:FindFirstChild("HumanoidRootPart")
		if not fruteHRP then continue end
		humRP.CFrame = CFrame.new(fruteHRP.Position - Vector3.new(0, 0, 5)) * CFrame.Angles(0, 180, 0)
		vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	end
end)

-- ── Anti-Ragdoll loop ─────────────────────────────────────────────────────
task.spawn(function()
	while task.wait(0.05) do
		if not antiRagdollActive then continue end
		humanoid:SetAttribute("Ragdoll", false)
	end
end)

-- ── Anti-Knockback ────────────────────────────────────────────────────────
local function setupAntiKnockback()
	if antiKnockbackConn then
		antiKnockbackConn:Disconnect()
		antiKnockbackConn = nil
	end
	local rootAttachment = humRP:FindFirstChild("RootAttachment")
	if not rootAttachment then return end
	antiKnockbackConn = rootAttachment.ChildAdded:Connect(function(child)
		if not antiKnockbackActive then return end
		if child.Name == "KnockbackForce" or child:IsA("LinearVelocity") or child:IsA("VectorForce") then
			child:Destroy()
		end
	end)
end

setupAntiKnockback()

-- ── Heartbeat loop (ESP + hitbox) ─────────────────────────────────────────
runService.Heartbeat:Connect(function()
	updateESP()

	if hitboxMode == "Off" then return end
	local size = hitboxMode == "Legit" and HITBOX_LEGIT_SIZE or HITBOX_RAGE_SIZE
	for _, enemyChar in entities:GetChildren() do
		if enemyChar == character then continue end
		local head = enemyChar:FindFirstChild("Head")
		if not head then continue end
		head.Size = Vector3.new(size, size, size)
		head.Massless = true
		head.CanCollide = false
		head.CanTouch = true
		head.CanQuery = true
		head.Transparency = 0.8
		local mesh = head:FindFirstChildOfClass("SpecialMesh")
		if mesh then mesh:Destroy() end
	end
end)

-- ── Input ─────────────────────────────────────────────────────────────────
userInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		doAimAssist()
	end
	if input.KeyCode == Enum.KeyCode.T and teleportActive then
		local mouse = localPlayer:GetMouse()
		if mouse.Target then
			humRP.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
		end
	end
end)

-- ── COMBAT TAB ────────────────────────────────────────────────────────────
CombatTab:CreateDropdown("Hitbox Extender", {"Off", "Legit", "Rage"}, "Off", function(selected)
	applyHitboxMode(selected)
end)


CombatTab:CreateToggle("Auto Kill", false, function(state)
	autoKillActive = state
end)

CombatTab:CreateToggle("Aim Assist", false, function(state)
	aimAssistActive = state
end)

CombatTab:CreateSlider("Aim Velocity", 5, 100, 32, function(val)
	aimVelocity = val
end)

CombatTab:CreateSlider("Aim Hitbox Width", 1, 40, 10, function(val)
	aimHitboxSize = Vector3.new(val, aimHitboxSize.Y, aimHitboxSize.Z)
end)

CombatTab:CreateSlider("Aim Hitbox Depth", 1, 60, 25, function(val)
	aimHitboxSize = Vector3.new(aimHitboxSize.X, aimHitboxSize.Y, val)
end)

-- ── VISUALS TAB ───────────────────────────────────────────────────────────
VisualsTab:CreateToggle("ESP - Outline", false, function(state)
	stateOutline = state
	if not state then
		for _, ep in playersService:GetPlayers() do
			if ep == localPlayer then continue end
			local high = getHighlight(ep)
			if high then
				tweenService:Create(high, TweenInfo.new(0.3), {OutlineTransparency = 1, FillTransparency = 1}):Play()
			end
		end
	end
end)

VisualsTab:CreateToggle("ESP - Names", false, function(state)
	stateNames = state
	if not state then
		for _, ep in playersService:GetPlayers() do
			if ep == localPlayer then continue end
			local box = getESPBox(ep)
			if box then
				local nl = box:FindFirstChild("PlayerName")
				if nl then tweenService:Create(nl, TweenInfo.new(0.3), {TextTransparency = 1}):Play() end
			end
		end
	end
end)

VisualsTab:CreateToggle("ESP - Health", false, function(state)
	stateHealth = state
	if not state then
		for _, ep in playersService:GetPlayers() do
			if ep == localPlayer then continue end
			local box = getESPBox(ep)
			if box then
				local hl = box:FindFirstChild("HealthDisplay")
				if hl then tweenService:Create(hl, TweenInfo.new(0.3), {TextTransparency = 1}):Play() end
			end
		end
	end
end)

-- ── MISC TAB ──────────────────────────────────────────────────────────────
MiscTab:CreateToggle("Teleport [T]", false, function(state)
	teleportActive = state
end)

MiscTab:CreateToggle("Fullbright", false, function(state)
	if state then
		lightingService.Brightness = 2
		lightingService.ClockTime = 14
		lightingService.GlobalShadows = false
		lightingService.Ambient = Color3.fromRGB(255, 255, 255)
		lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
	else
		lightingService.Brightness = 1
		lightingService.GlobalShadows = true
		lightingService.Ambient = Color3.fromRGB(70, 70, 70)
		lightingService.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
	end
end)

MiscTab:CreateToggle("Lichen Farm", false, function(state)
	lichenFarmActive = state
	if state then
		autoKillActive = false
		antiKnockbackActive = true
	else
		antiKnockbackActive = false
	end
end)

MiscTab:CreateToggle("Anti-Ragdoll", false, function(state)
	antiRagdollActive = state
end)

MiscTab:CreateToggle("Anti-Knockback", false, function(state)
	antiKnockbackActive = state
end)

-- ── Character refresh on respawn ──────────────────────────────────────────
localPlayer.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	humRP = char:WaitForChild("HumanoidRootPart")
	task.wait(1)
	setupAntiKnockback()
end)