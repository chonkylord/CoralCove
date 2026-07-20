-- Barista NPC Movement Script
-- Makes baristas walk between waypoints inside the coffee shop

local Workspace = game:GetService("Workspace")

-- Waypoint sets for each barista, spread across the lower floor interior
-- Floor: Y=14.9, Interior X: -64 to 20, Z: -148 to -73
-- Using Y=15 (close to floor, MoveTo uses X/Z for ground navigation)

local baristaWaypoints = {
    ["Barista1"] = {
        Vector3.new(-20, 15, -130),
        Vector3.new(-10, 15, -120),
        Vector3.new(-25, 15, -105),
        Vector3.new(-30, 15, -125),
    },
    ["Barista2"] = {
        Vector3.new(-10, 15, -140),
        Vector3.new(-20, 15, -135),
        Vector3.new(0, 15, -130),
        Vector3.new(-15, 15, -145),
    },
    ["Barista3"] = {
        Vector3.new(5, 15, -125),
        Vector3.new(10, 15, -110),
        Vector3.new(0, 15, -120),
        Vector3.new(-5, 15, -135),
    },
    ["Barista4"] = {
        Vector3.new(15, 15, -110),
        Vector3.new(10, 15, -125),
        Vector3.new(-5, 15, -115),
        Vector3.new(5, 15, -140),
    },
}

local function setupBarista(baristaName, waypoints)
    local barista = Workspace:FindFirstChild(baristaName)
    if not barista then
        warn("[BaristaMovement] Could not find " .. baristaName)
        return
    end

    local humanoid = barista:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("[BaristaMovement] " .. baristaName .. " has no Humanoid")
        return
    end

    -- Ensure the barista is alive and can move
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 8
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local currentIndex = 1

    local function moveToNext()
        -- If the barista sat down on a seat, make it stand up first
        if humanoid:GetState() == Enum.HumanoidStateType.Seated then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            task.wait(0.5)
        end
        local target = waypoints[currentIndex]
        humanoid:MoveTo(target)
        currentIndex = currentIndex % #waypoints + 1
    end

    -- Anti-sit: periodically check if the barista is stuck sitting and stand up
    task.spawn(function()
        while barista.Parent do
            if humanoid:GetState() == Enum.HumanoidStateType.Seated then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                task.wait(0.5)
                moveToNext()
            end
            task.wait(1)
        end
    end)

    -- Start moving to first waypoint
    moveToNext()

    -- When the barista reaches a waypoint (or times out), move to the next one
    humanoid.MoveToFinished:Connect(function(reached)
        if reached then
            -- Small pause at each waypoint for a natural feel
            task.wait(math.random(1, 4))
        else
            -- If timed out (didn't reach), wait a bit and try next
            task.wait(0.5)
        end
        moveToNext()
    end)
end

-- Set up all baristas
for name, waypoints in pairs(baristaWaypoints) do
    setupBarista(name, waypoints)
end

-- Also handle baristas added later during gameplay
Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") and baristaWaypoints[child.Name] then
        -- Wait for the model to fully load
        task.wait(1)
        setupBarista(child.Name, baristaWaypoints[child.Name])
    end
end)
