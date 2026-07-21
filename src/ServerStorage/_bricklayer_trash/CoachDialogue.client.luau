--!strict
-- Local presentation for Coach Marina. The server decides when and what the
-- coach says; this script only renders a compact, animated conversation card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local coachDialogue = raceEvents:WaitForChild("CoachDialogue") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "CoachDialogueGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "CoachCard"
card.AnchorPoint = Vector2.new(0.5, 1)
card.Position = UDim2.new(0.5, 0, 1, -26)
card.Size = UDim2.new(0.62, 0, 0, 118)
card.BackgroundColor3 = Color3.fromRGB(13, 28, 44)
card.BackgroundTransparency = 0.04
card.BorderSizePixel = 0
card.Visible = false
card.Parent = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 108)
sizeConstraint.MaxSize = Vector2.new(650, 128)
sizeConstraint.Parent = card

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = card

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 190, 255)
stroke.Thickness = 2
stroke.Transparency = 0.16
stroke.Parent = card

local scale = Instance.new("UIScale")
scale.Scale = 0.92
scale.Parent = card

local portrait = Instance.new("Frame")
portrait.Name = "Portrait"
portrait.Position = UDim2.fromOffset(16, 17)
portrait.Size = UDim2.fromOffset(78, 78)
portrait.BackgroundColor3 = Color3.fromRGB(30, 134, 194)
portrait.BorderSizePixel = 0
portrait.Parent = card

local portraitCorner = Instance.new("UICorner")
portraitCorner.CornerRadius = UDim.new(1, 0)
portraitCorner.Parent = portrait

local portraitText = Instance.new("TextLabel")
portraitText.Size = UDim2.fromScale(1, 1)
portraitText.BackgroundTransparency = 1
portraitText.Font = Enum.Font.GothamBlack
portraitText.Text = "CM"
portraitText.TextColor3 = Color3.fromRGB(238, 250, 255)
portraitText.TextSize = 28
portraitText.Parent = portrait

local nameLabel = Instance.new("TextLabel")
nameLabel.Position = UDim2.fromOffset(110, 16)
nameLabel.Size = UDim2.new(1, -126, 0, 24)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.Text = "COACH MARINA"
nameLabel.TextColor3 = Color3.fromRGB(104, 207, 255)
nameLabel.TextSize = 16
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Parent = card

local messageLabel = Instance.new("TextLabel")
messageLabel.Position = UDim2.fromOffset(110, 42)
messageLabel.Size = UDim2.new(1, -130, 0, 60)
messageLabel.BackgroundTransparency = 1
messageLabel.Font = Enum.Font.GothamMedium
messageLabel.TextColor3 = Color3.fromRGB(244, 248, 255)
messageLabel.TextSize = 17
messageLabel.TextWrapped = true
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.TextYAlignment = Enum.TextYAlignment.Top
messageLabel.Parent = card

local messageToken = 0
coachDialogue.OnClientEvent:Connect(function(payload: { [string]: any })
	messageToken += 1
	local token = messageToken
	nameLabel.Text = tostring(payload.speaker or "COACH MARINA")
	messageLabel.Text = tostring(payload.text or "Follow me to the pool!")
	card.Visible = true
	scale.Scale = 0.92
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local duration = tonumber(payload.duration) or 5
	task.delay(duration, function()
		if messageToken == token then
			card.Visible = false
		end
	end)
end)
