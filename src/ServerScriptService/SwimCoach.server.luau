--!strict
-- Coach Marina gives each arriving player a short, in-world introduction. She
-- starts beside the dock landing, walks the validated shore path to a starting
-- block, and speaks only through a speech bubble above her head.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Pool = Workspace:WaitForChild("OlympicPool")
local CoachTemplate = Workspace:WaitForChild("People"):WaitForChild("dragongirl49821") :: Model
local coachesFolder = Workspace:FindFirstChild("SwimCoaches")
if not coachesFolder then
	coachesFolder = Instance.new("Folder")
	coachesFolder.Name = "SwimCoaches"
	coachesFolder.Parent = Workspace
end

local coachedPlayers: { [number]: Model } = {}
local idleTracks: { [Model]: AnimationTrack } = {}

local existingFinishSignal = ServerScriptService:FindFirstChild("CoachRaceFinished")
local CoachRaceFinished: BindableEvent
if existingFinishSignal and existingFinishSignal:IsA("BindableEvent") then
	CoachRaceFinished = existingFinishSignal
else
	CoachRaceFinished = Instance.new("BindableEvent")
	CoachRaceFinished.Name = "CoachRaceFinished"
	CoachRaceFinished.Parent = ServerScriptService
end

local function characterRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function closestStartBlock(fromPosition: Vector3): BasePart?
	local closest: BasePart? = nil
	local bestDistance = math.huge
	for _, child in Pool:GetChildren() do
		if
			child:IsA("BasePart")
			and typeof(child:GetAttribute("Lane")) == "number"
			and child:GetAttribute("Kind") == nil
		then
			local distance = (child.Position - fromPosition).Magnitude
			if distance < bestDistance then
				closest = child
				bestDistance = distance
			end
		end
	end
	return closest
end

local function groundPosition(nearPosition: Vector3, ignore: Instance): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore, coachesFolder :: Instance }
	local result = Workspace:Raycast(nearPosition + Vector3.new(0, 24, 0), Vector3.new(0, -80, 0), params)
	if result then
		return result.Position + Vector3.new(0, 3, 0)
	end
	return nearPosition + Vector3.new(0, 3, 0)
end

local function weldDecoration(
	parent: Model,
	attachTo: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	offset: CFrame
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = attachTo.CFrame * offset
	part.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addSpeechBubble(head: BasePart): BillboardGui
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "SpeechBubble"
	bubble.Size = UDim2.fromOffset(300, 94)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
	bubble.AlwaysOnTop = true
	bubble.MaxDistance = 70
	bubble.Enabled = false
	bubble.Parent = head

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -12)
	body.BackgroundColor3 = Color3.fromRGB(248, 252, 255)
	body.BorderSizePixel = 0
	body.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = body
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(42, 158, 219)
	stroke.Thickness = 2
	stroke.Parent = body

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Position = UDim2.fromOffset(14, 10)
	text.Size = UDim2.new(1, -28, 1, -20)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.fromRGB(22, 52, 79)
	text.TextSize = 15
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.Parent = body

	local tail = Instance.new("TextLabel")
	tail.Size = UDim2.fromOffset(28, 24)
	tail.Position = UDim2.new(0.5, -14, 1, -21)
	tail.BackgroundTransparency = 1
	tail.Font = Enum.Font.GothamBlack
	tail.Text = "▼"
	tail.TextColor3 = Color3.fromRGB(248, 252, 255)
	tail.TextSize = 26
	tail.ZIndex = 0
	tail.Parent = bubble
	return bubble
end

local function addCoachStyle(model: Model)
	-- This is a scene-native beach avatar, not a free-model import. Preserve her
	-- clothing, hair, and sunglasses; only remove executable content from clones.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end

	local torso: BasePart? = nil
	local head: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Massless = true
			if descendant.Name == "HumanoidRootPart" then
				descendant.Transparency = 1
			elseif descendant.Name == "Head" then
				head = descendant
			elseif descendant.Name == "Torso" or descendant.Name == "UpperTorso" then
				torso = descendant
			end
		end
	end

	if head then
		local tag = Instance.new("BillboardGui")
		tag.Name = "CoachTag"
		tag.Size = UDim2.fromOffset(180, 32)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
		tag.AlwaysOnTop = true
		tag.MaxDistance = 80
		tag.Parent = head
		local tagText = Instance.new("TextLabel")
		tagText.Size = UDim2.fromScale(1, 1)
		tagText.BackgroundTransparency = 1
		tagText.Font = Enum.Font.GothamBold
		tagText.Text = "COACH MARINA  •  SURF COACH"
		tagText.TextColor3 = Color3.fromRGB(122, 219, 255)
		tagText.TextStrokeTransparency = 0.35
		tagText.TextSize = 16
		tagText.Parent = tag
		addSpeechBubble(head)
	end

	if torso then
		local board = weldDecoration(
			model,
			torso,
			"Surfboard",
			Vector3.new(0.28, 4.5, 1.5),
			Color3.fromRGB(244, 111, 61),
			CFrame.new(0, 0, 0.88) * CFrame.Angles(0, 0, math.rad(-8))
		)
		board.Material = Enum.Material.SmoothPlastic
		weldDecoration(
			model,
			torso,
			"BoardStripe",
			Vector3.new(0.31, 0.45, 1.56),
			Color3.fromRGB(250, 245, 215),
			CFrame.new(0, 0, 1.03)
		)
	end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(41, 175, 240)
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = Color3.fromRGB(179, 237, 255)
	highlight.OutlineTransparency = 0.15
	highlight.Parent = model
end

local function say(coach: Model, text: string, duration: number)
	local head = coach:FindFirstChild("Head")
	local bubble = head and head:FindFirstChild("SpeechBubble")
	if not bubble or not bubble:IsA("BillboardGui") then
		return
	end
	local body = bubble:FindFirstChild("Body")
	local label = body and body:FindFirstChild("Text")
	if not label or not label:IsA("TextLabel") then
		return
	end
	local previousToken = bubble:GetAttribute("MessageToken")
	local token = (if type(previousToken) == "number" then previousToken else 0) + 1
	bubble:SetAttribute("MessageToken", token)
	label.Text = text
	bubble.Enabled = true
	task.delay(duration, function()
		if bubble:GetAttribute("MessageToken") == token then
			bubble.Enabled = false
		end
	end)
end

local function loadLoop(humanoid: Humanoid, assetId: string): AnimationTrack?
	local foundAnimator = humanoid:FindFirstChildOfClass("Animator")
	local animator: Animator
	if foundAnimator and foundAnimator:IsA("Animator") then
		animator = foundAnimator
	else
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = assetId
	local ok, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and result then
		local track = result :: AnimationTrack
		track.Looped = true
		return track
	end
	animation:Destroy()
	return nil
end

local function animationForRig(humanoid: Humanoid, r6Id: string, r15Id: string): string
	return if humanoid.RigType == Enum.HumanoidRigType.R6 then r6Id else r15Id
end

local function addMentorPrompt(coach: Model, owner: Player)
	local root = characterRoot(coach)
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CoachTipPrompt"
	prompt.ActionText = "Ask for a tip"
	prompt.ObjectText = "Coach Marina"
	prompt.MaxActivationDistance = 11
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = root
	local tips = {
		"Breathe at the surface before the turn. A calm swimmer is a fast swimmer!",
		"Try to beat your own time first — every personal best earns better points.",
		"The Swim Shop has styles with different strengths. Pick one that fits your rhythm.",
		"Short, steady strokes beat panic. Keep your line and save your breath for the return!",
	}
	local tipIndex = 0
	prompt.Triggered:Connect(function(player: Player)
		if player ~= owner then
			return
		end
		tipIndex = (tipIndex % #tips) + 1
		say(coach, tips[tipIndex], 6)
	end)
end

local function createCoach(player: Player, nearRoot: BasePart): Model?
	CoachTemplate.Archivable = true
	local model = CoachTemplate:Clone()
	model.Name = "CoachMarina_" .. player.UserId
	model.Parent = coachesFolder
	addCoachStyle(model)

	local root = characterRoot(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		model:Destroy()
		return nil
	end
	local spawnOffset = nearRoot.CFrame.RightVector * 6
	root.CFrame = CFrame.new(groundPosition(nearRoot.Position + spawnOffset, nearRoot.Parent or model))
	humanoid.DisplayName = "Coach Marina"
	humanoid.WalkSpeed = 8.5
	humanoid.AutoRotate = true
	addMentorPrompt(model, player)
	local idleTrack = loadLoop(humanoid, animationForRig(humanoid, "rbxassetid://180435571", "rbxassetid://507766666"))
	if idleTrack then
		idleTrack:Play(0.25)
		idleTracks[model] = idleTrack
	end
	return model
end

local function moveCoachTo(model: Model, destination: Vector3): boolean
	local root = characterRoot(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return false
	end
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local pathOk = pcall(function()
		path:ComputeAsync(root.Position, destination)
	end)
	if not pathOk or path.Status ~= Enum.PathStatus.Success then
		return false
	end

	local walkTrack = loadLoop(humanoid, animationForRig(humanoid, "rbxassetid://180426354", "rbxassetid://507777826"))
	local idleTrack = idleTracks[model]
	if idleTrack and idleTrack.IsPlaying then
		idleTrack:Stop(0.25)
	end
	if walkTrack then
		walkTrack:Play(0.25)
	end
	for _, waypoint in path:GetWaypoints() do
		local done = false
		local reached = false
		local connection = humanoid.MoveToFinished:Connect(function(success: boolean)
			done = true
			reached = success
		end)
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
		local deadline = os.clock() + 5
		repeat
			task.wait()
		until done or os.clock() >= deadline
		connection:Disconnect()
		if not reached then
			if walkTrack then
				walkTrack:Stop(0.25)
			end
			if idleTrack then
				idleTrack:Play(0.25)
			end
			return false
		end
	end
	if walkTrack then
		walkTrack:Stop(0.25)
	end
	if idleTrack then
		idleTrack:Play(0.25)
	end
	return true
end

local function guidePlayer(player: Player)
	if coachedPlayers[player.UserId] then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local root = characterRoot(character)
	if not root then
		return
	end
	local targetBlock = closestStartBlock(root.Position)
	if not targetBlock then
		warn("[Coach] no race start blocks found")
		return
	end
	local coach = createCoach(player, root)
	if not coach then
		return
	end
	coachedPlayers[player.UserId] = coach
	task.wait(1.5)
	say(coach, "Hey, swimmer! I’m Coach Marina. Follow me to the starting blocks.", 5)
	task.wait(3.8)
	say(coach, "Stay close — I know the way.", 3)
	local arrived = moveCoachTo(coach, targetBlock.Position + Vector3.new(-4, 3, 0))
	if arrived then
		say(coach, "Step onto any starting block. At GO, swim to the far wall, turn, then race back to finish!", 7)
	else
		say(coach, "The route is busy — meet me at the nearest starting block by the pool!", 6)
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(guidePlayer, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(guidePlayer, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	local coach = coachedPlayers[player.UserId]
	if coach then
		idleTracks[coach] = nil
		coach:Destroy()
	end
	coachedPlayers[player.UserId] = nil
end)

CoachRaceFinished.Event:Connect(function(player: Player, _finishTime: number, isBest: boolean)
	local coach = coachedPlayers[player.UserId]
	if not coach then
		return
	end
	local coachRoot = characterRoot(coach)
	local prompt = coachRoot and coachRoot:FindFirstChild("CoachTipPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = true
	end
	if isBest then
		say(coach, "That was a new personal best! I knew you had it. Come back anytime for a training tip.", 7)
	else
		say(
			coach,
			"Nice finish! I’m staying by the pool — come ask me for a training tip before your next heat.",
			7
		)
	end
end)
