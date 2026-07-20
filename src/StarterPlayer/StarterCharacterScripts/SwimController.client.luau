--!strict
-- Per-character swimming controller (local): manages breath, the chosen stroke
-- style, a momentum-based "startup" ramp, and the resulting swim speed, plus the
-- breath/style HUD. Character physics is client-owned in Roblox, so this lives
-- on the client; race results stay server-authoritative in RaceManager.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SwimConfig = require(ReplicatedStorage:WaitForChild("SwimConfig"))

local player = Players.LocalPlayer
local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local head = character:WaitForChild("Head") :: BasePart

local PlayerGui = player:WaitForChild("PlayerGui")
local hud = PlayerGui:WaitForChild("RaceHud")
local breathBG = hud:WaitForChild("BreathBarBG") :: Frame
local breathFill = breathBG:WaitForChild("BreathBarFill") :: Frame
local breathLabel = breathBG:WaitForChild("BreathLabel") :: TextLabel
local styleLabel = hud:WaitForChild("StyleLabel") :: TextLabel

local currentStyleKey = "Freestyle"
local momentum = 0 -- 0..1 how far into the startup ramp we are
local breath = SwimConfig.breathMax
local gasping = false

local function updateStyleLabel()
	local parts = {}
	for i, key in SwimConfig.order do
		local s = SwimConfig.styles[key]
		if key == currentStyleKey then
			table.insert(parts, string.format("[%d] > %s <", i, s.name))
		else
			table.insert(parts, string.format("[%d] %s", i, s.name))
		end
	end
	styleLabel.Text = table.concat(parts, "     ")
end
updateStyleLabel()

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local map = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
	local idx = map[input.KeyCode]
	if idx and SwimConfig.order[idx] then
		currentStyleKey = SwimConfig.order[idx]
		updateStyleLabel()
	end
end)

-- Sample the top of the head against terrain voxels: only reads Water once the
-- head is genuinely submerged, so surfacing (head above water) refills breath.
local function isHeadSubmerged(): boolean
	local samplePos = head.Position + Vector3.new(0, head.Size.Y * 0.5, 0)
	local region = Region3.new(samplePos - Vector3.new(2, 2, 2), samplePos + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ok, materials, occupancies = pcall(function()
		return Workspace.Terrain:ReadVoxels(region, 4)
	end)
	if not ok then
		return false
	end
	local size = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] == Enum.Material.Water and occupancies[x][y][z] > 0.4 then
					return true
				end
			end
		end
	end
	return false
end

local submerged = false
local sinceCheck = 0
local CHECK_INTERVAL = 0.15

RunService.RenderStepped:Connect(function(dt: number)
	local style = SwimConfig.styles[currentStyleKey]
	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming

	-- throttle the (relatively costly) voxel read
	sinceCheck += dt
	if sinceCheck >= CHECK_INTERVAL then
		sinceCheck = 0
		submerged = swimming and isHeadSubmerged()
	end

	-- breath drains submerged, refills at the surface / on land
	if submerged then
		breath = math.max(0, breath - style.drain * dt)
	else
		breath = math.min(SwimConfig.breathMax, breath + SwimConfig.refillRate * dt)
	end
	if breath <= 0 then
		gasping = true
	elseif breath >= SwimConfig.lowBreath then
		gasping = false
	end

	-- momentum ramp + resulting speed
	if swimming then
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		if moving and not gasping then
			momentum = math.min(1, momentum + dt / style.startup)
		else
			momentum = math.max(0, momentum - dt / SwimConfig.momentumDecay)
		end
		local speed = SwimConfig.baseSwimSpeed + momentum * (style.topSpeed - SwimConfig.baseSwimSpeed)
		if gasping then
			speed *= SwimConfig.gaspMultiplier
		end
		humanoid.WalkSpeed = speed
	else
		momentum = math.max(0, momentum - dt / SwimConfig.momentumDecay)
		humanoid.WalkSpeed = SwimConfig.landSpeed
	end

	-- HUD
	local frac = breath / SwimConfig.breathMax
	breathFill.Size = UDim2.fromScale(frac, 1)
	if gasping then
		breathFill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
		breathLabel.Text = "OUT OF BREATH — SURFACE!"
	else
		breathFill.BackgroundColor3 = if breath < 35 then Color3.fromRGB(240, 180, 60) else Color3.fromRGB(70, 170, 240)
		breathLabel.Text = string.format("Breath %d%%", math.floor(frac * 100 + 0.5))
	end
end)
