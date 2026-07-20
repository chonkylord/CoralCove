--!strict
-- Swim Shop UI (client). Builds a toggle button, a points badge, and a shop
-- window listing every stroke style with its stats, cost, and a Buy/Equip
-- button. Nothing here is authoritative: buying invokes RequestPurchase and
-- equipping fires EquipStyle; the server validates and updates the player's
-- Points / Unlocked_* / EquippedStyle values, which this UI simply reflects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwimConfig = require(ReplicatedStorage:WaitForChild("SwimConfig"))

local RaceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local RequestPurchase = RaceEvents:WaitForChild("RequestPurchase") :: RemoteFunction
local EquipStyleEvent = RaceEvents:WaitForChild("EquipStyle") :: RemoteEvent
local PointsAwardedEvent = RaceEvents:WaitForChild("PointsAwarded") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- palette (matches the breath-bar blue in the existing HUD)
local BG = Color3.fromRGB(22, 26, 36)
local PANEL = Color3.fromRGB(32, 38, 52)
local ACCENT = Color3.fromRGB(70, 170, 240)
local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(76, 184, 96)
local GREY = Color3.fromRGB(70, 78, 96)
local TEXT = Color3.fromRGB(240, 244, 252)
local SUBTEXT = Color3.fromRGB(170, 180, 200)

local function make(className: string, props: { [string]: any }, children: { Instance }?): Instance
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	return inst
end

local function corner(radius: number): Instance
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

-- economy readers (all server-set, replicated to us) ------------------------
local function getPoints(): number
	return tonumber(player:GetAttribute("Points")) or 0
end
local function isUnlocked(key: string): boolean
	local style = SwimConfig.styles[key]
	if style and style.default then
		return true
	end
	return player:GetAttribute("Unlocked_" .. key) == true
end
local function equippedKey(): string
	local eq = player:GetAttribute("EquippedStyle")
	if type(eq) == "string" and SwimConfig.styles[eq] then
		return eq
	end
	return "Freestyle"
end

-- root gui -------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "ShopGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
}) :: ScreenGui
gui.Parent = playerGui

-- points badge (top-right) ---------------------------------------------------
local pointsBadge = make("TextLabel", {
	Name = "PointsBadge",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(150, 40),
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.15,
	Font = Enum.Font.GothamBold,
	TextColor3 = GOLD,
	TextScaled = true,
	Text = "🪙 0 pts",
}, {
	corner(10),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}),
}) :: TextLabel
pointsBadge.Parent = gui

-- points-awarded toast (under the badge) -------------------------------------
local toast = make("TextLabel", {
	Name = "Toast",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 62),
	Size = UDim2.fromOffset(220, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextColor3 = GREEN,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextTransparency = 1,
	Text = "",
}) :: TextLabel
toast.Parent = gui

-- toggle button (bottom-right) ----------------------------------------------
local toggle = make("TextButton", {
	Name = "ShopToggle",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(128, 46),
	BackgroundColor3 = ACCENT,
	Font = Enum.Font.GothamBold,
	TextColor3 = TEXT,
	TextScaled = true,
	Text = "🛒 Shop",
	AutoButtonColor = true,
}, {
	corner(12),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 9),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
}) :: TextButton
toggle.Parent = gui

-- shop window ----------------------------------------------------------------
local window = make("Frame", {
	Name = "ShopWindow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(540, 470),
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.03,
	Visible = false,
}, {
	corner(16),
	make("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.4 }),
	make("UISizeConstraint", { MaxSize = Vector2.new(560, 620), MinSize = Vector2.new(320, 300) }),
}) :: Frame
window.Parent = gui

local title = make("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.new(1, -140, 0, 30),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextColor3 = TEXT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "🏊 Swim Shop",
}) :: TextLabel
title.Parent = window

local subtitle = make("TextLabel", {
	Name = "Subtitle",
	Position = UDim2.fromOffset(20, 46),
	Size = UDim2.new(1, -140, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextColor3 = SUBTEXT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Race to earn points — beat your last time for more!",
}) :: TextLabel
subtitle.Parent = window

local windowPoints = make("TextLabel", {
	Name = "WindowPoints",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -58, 0, 16),
	Size = UDim2.fromOffset(0, 30),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 22,
	Text = "🪙 0",
}) :: TextLabel
windowPoints.Parent = window

local closeBtn = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = PANEL,
	Font = Enum.Font.GothamBold,
	TextColor3 = TEXT,
	TextScaled = true,
	Text = "✕",
}, { corner(10) }) :: TextButton
closeBtn.Parent = window

local list = make("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(14, 76),
	Size = UDim2.new(1, -28, 1, -90),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = ACCENT,
}, {
	make("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
	make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }),
}) :: ScrollingFrame
list.Parent = window

-- one card per style ---------------------------------------------------------
type Card = { frame: Frame, button: TextButton }
local cards: { [string]: Card } = {}
local refreshCard: (key: string) -> () -- forward decl (assigned below)

local function buildCard(key: string, order: number): Card
	local style = SwimConfig.styles[key]

	local frame = make("Frame", {
		Name = key,
		Size = UDim2.new(1, -6, 0, 104),
		BackgroundColor3 = PANEL,
		LayoutOrder = order,
	}, {
		corner(12),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	}) :: Frame

	make("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -150, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = TEXT,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = style.name,
	}).Parent =
		frame

	make("TextLabel", {
		Name = "Desc",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, -150, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = SUBTEXT,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = style.desc,
	}).Parent =
		frame

	make("TextLabel", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, -150, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = ACCENT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format(
			"⚡ Speed %d    💨 Air %d/s    ⏱ Ramp %.1fs",
			style.topSpeed,
			style.drain,
			style.startup
		),
	}).Parent =
		frame

	local button = make("TextButton", {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(128, 40),
		BackgroundColor3 = GREEN,
		Font = Enum.Font.GothamBold,
		TextColor3 = TEXT,
		TextSize = 16,
		Text = "Buy",
	}, { corner(10) }) :: TextButton
	button.Parent = frame

	button.Activated:Connect(function()
		if not isUnlocked(key) then
			task.spawn(function()
				local ok, result = pcall(function()
					return RequestPurchase:InvokeServer(key)
				end)
				if ok and type(result) == "table" and result.ok then
					EquipStyleEvent:FireServer(key) -- auto-equip what you just bought
				elseif ok and type(result) == "table" then
					-- show why (e.g. "Not enough points"), then restore the button
					button.Text = tostring(result.reason)
					task.delay(1.3, function()
						refreshCard(key)
					end)
				end
			end)
		elseif equippedKey() ~= key then
			EquipStyleEvent:FireServer(key)
		end
	end)

	return { frame = frame, button = button }
end

for i, key in SwimConfig.order do
	local card = buildCard(key, i)
	cards[key] = card
	card.frame.Parent = list
end

-- refresh -------------------------------------------------------------------
function refreshCard(key: string)
	local card = cards[key]
	if not card then
		return
	end
	local style = SwimConfig.styles[key]
	local btn = card.button
	if not isUnlocked(key) then
		local affordable = getPoints() >= style.cost
		btn.Text = string.format("Buy · %d", style.cost)
		btn.BackgroundColor3 = if affordable then GREEN else GREY
		btn.AutoButtonColor = affordable
	elseif equippedKey() == key then
		btn.Text = "✓ Equipped"
		btn.BackgroundColor3 = ACCENT
		btn.AutoButtonColor = false
	else
		btn.Text = "Equip"
		btn.BackgroundColor3 = Color3.fromRGB(58, 66, 84)
		btn.AutoButtonColor = true
	end
end

local function refreshAll()
	local pts = getPoints()
	pointsBadge.Text = string.format("🪙 %d pts", pts)
	windowPoints.Text = string.format("🪙 %d", pts)
	for key in cards do
		refreshCard(key)
	end
end
refreshAll()

-- toast for points earned after a race --------------------------------------
local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local myToken = toastToken
	toast.Text = text
	toast.TextTransparency = 0
	task.delay(2.6, function()
		if toastToken == myToken then
			toast.TextTransparency = 1
		end
	end)
end

-- window open/close ----------------------------------------------------------
local function setOpen(open: boolean)
	window.Visible = open
	if open then
		refreshAll()
	end
end
toggle.Activated:Connect(function()
	setOpen(not window.Visible)
end)
closeBtn.Activated:Connect(function()
	setOpen(false)
end)

-- react to server-driven economy changes ------------------------------------
player:GetAttributeChangedSignal("Points"):Connect(refreshAll)
player:GetAttributeChangedSignal("EquippedStyle"):Connect(refreshAll)
player.AttributeChanged:Connect(function(name: string)
	if string.sub(name, 1, 9) == "Unlocked_" then
		refreshAll()
	end
end)

PointsAwardedEvent.OnClientEvent:Connect(function(awarded: number, newTotal: number, faster: number, isBest: boolean)
	local msg = string.format("+%d pts!", awarded)
	if isBest then
		msg ..= " 🏅 New best!"
	end
	showToast(msg)
	refreshAll()
end)
