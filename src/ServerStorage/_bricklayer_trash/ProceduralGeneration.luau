--!strict
-- generationId: e0cd4c8b-bf5c-4da7-ae72-75680fa89d90
local CSG = require(script.Dependencies.ConstructiveSolidGeometry)
local GP = require(script.Dependencies.GeometryPrimitives)
local SO = require(script.Dependencies.SmartObject)
local MU = require(script.Dependencies.MathUtils)


local ToySportsCar = {}

type Parameters = {
	Size: Vector3,
	Attributes: {
		BodyColor: Color3?,
		WheelColor: Color3?,
		RimColor: Color3?,
		GlassColor: Color3?,
		GrilleColor: Color3?,
	},
}
local startTime = 0
local timerThread : thread = task.spawn(function()
while true do
	if not script:IsDescendantOf(game) then
		startTime = 0
		return
	end
	if startTime > 0 then
		local elapsed = tick() - startTime
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering... " .. string.format("%.0f", elapsed) .. " seconds")
	end
	task.wait(3)
end
end)
script.Destroying:Connect(function()
	task.cancel(timerThread)
end)

ToySportsCar.OnGenerate = function(parameters: Parameters, targetContainer: Instance)
	-- Timer setup
	startTime = tick()

	local myModel = GP.model("ToySportsCar", nil)-- Fix orientation of the model
	myModel.WorldPivot = CFrame.identity
	
	
	-- REQUIRED: all three smart dimensions (default is always 10, but user requested ~6, 3, 10, so we use 10 as base for multiplier, but setup our defaults properly)
	local sw = parameters.Size.X
	local sh = parameters.Size.Y
	local sd = parameters.Size.Z
	
	-- Scale factors based on the requested default dimensions
	local scaleX = sw / 6
	local scaleY = sh / 3
	local scaleZ = sd / 10
	
	-- Semantic Parameters
	local bodyColor = parameters.Attributes.BodyColor or Color3.fromRGB(230, 40, 40)
	local wheelColor = parameters.Attributes.WheelColor or Color3.fromRGB(50, 50, 55)
	local rimColor = parameters.Attributes.RimColor or Color3.fromRGB(100, 100, 105)
	local glassColor = parameters.Attributes.GlassColor or Color3.fromRGB(130, 200, 255)
	local grilleColor = parameters.Attributes.GrilleColor or Color3.fromRGB(30, 30, 30)
	
	-- Derived Layout Variables
	local halfW = 3 * scaleX
	local carWidth = sw
	
	local groundClearance = 0.4 * scaleY
	local bodyBottom = groundClearance
	local beltLine = 1.6 * scaleY
	local roofY = 2.8 * scaleY
	
	local noseZ = -5 * scaleZ
	local tailZ = 5 * scaleZ
	local hoodZ = -1.5 * scaleZ
	local roofFrontZ = -0.5 * scaleZ
	local roofRearZ = 2.0 * scaleZ
	
	local wheelRadius = 0.9 * math.min(scaleX, scaleY, scaleZ)
	local wheelWidth = 1.1 * scaleX
	local wheelY = wheelRadius
	local trackX = halfW - 0.1 * scaleX
	local frontWheelZ = -3.0 * scaleZ
	local rearWheelZ = 3.0 * scaleZ
	
	local wellRadius = wheelRadius * 1.2
	local wellWidth = wheelWidth + 0.4
	
	local matPlastic = "SmoothPlastic"
	local matGlass = "Glass"
	
	-- ==========================================
	-- TOP LEVEL MODELS (Strict Naming)
	-- ==========================================
	local bodyM = GP.model("body", myModel)
	local cabinM = GP.model("cabin", myModel)
	local wFL = GP.model("front left wheel", myModel)
	local wFR = GP.model("front right wheel", myModel)
	local wRL = GP.model("back left wheel", myModel)
	local wRR = GP.model("back right wheel", myModel)
	local spoilerM = GP.model("spoiler", myModel)
	local windshieldM = GP.model("windshield", myModel)
	
	-- ==========================================
	-- BODY CONSTRUCTION
	-- ==========================================
	-- 1. Base geometric parts
	local midBlock = GP.axisAlignedBlockFromCorners("MidBlock",
	    Vector3.new(-halfW, bodyBottom, hoodZ),
	    Vector3.new(halfW, beltLine, tailZ),
	    bodyColor, matPlastic, bodyM)
	
	local frontBlock = GP.axisAlignedBlockFromCorners("FrontBlock",
	    Vector3.new(-halfW, bodyBottom, noseZ),
	    Vector3.new(halfW, bodyBottom + 0.5 * scaleY, hoodZ),
	    bodyColor, matPlastic, bodyM)
	
	local hoodWedge = GP.triangularPrismFromThreePoints("HoodWedge",
	    Vector3.new(-halfW, bodyBottom + 0.5 * scaleY, noseZ),
	    Vector3.new(-halfW, beltLine, hoodZ),
	    Vector3.new(-halfW, bodyBottom + 0.5 * scaleY, hoodZ),
	    carWidth, Vector3.new(1, 0, 0), bodyColor, matPlastic, bodyM)
	
	-- 2. Union the body into a single solid
	local bodySolid = CSG.union("BodySolid", midBlock, {frontBlock, hoodWedge})
	
	-- 3. Cutouts (Wheel wells and Grille)
	local cutters = {}
	local function addWellCutter(name, x, z)
	    local cutter = GP.cylinder(name, 
	        Vector3.new(x - wellWidth/2, wheelY, z), 
	        Vector3.new(x + wellWidth/2, wheelY, z), 
	        wellRadius, bodyColor, matPlastic, bodyM)
	    table.insert(cutters, cutter)
	end
	
	addWellCutter("CutFL", -trackX, frontWheelZ)
	addWellCutter("CutFR", trackX, frontWheelZ)
	addWellCutter("CutRL", -trackX, rearWheelZ)
	addWellCutter("CutRR", trackX, rearWheelZ)
	
	-- Grille Cutout
	local grilleCut = GP.axisAlignedBlockFromCorners("GrilleCut",
	    Vector3.new(-1.5 * scaleX, bodyBottom + 0.1 * scaleY, noseZ - 0.2),
	    Vector3.new(1.5 * scaleX, bodyBottom + 0.4 * scaleY, noseZ + 0.4 * scaleZ),
	    grilleColor, matPlastic, bodyM)
	table.insert(cutters, grilleCut)
	
	bodySolid = CSG.subtract("BodyShell", bodySolid, cutters)
	
	-- Inner Grille Detail (placed inside the cutout)
	GP.axisAlignedBlockFromCorners("GrilleInsert",
	    Vector3.new(-1.4 * scaleX, bodyBottom + 0.15 * scaleY, noseZ + 0.2 * scaleZ),
	    Vector3.new(1.4 * scaleX, bodyBottom + 0.35 * scaleY, noseZ + 0.3 * scaleZ),
	    grilleColor, matPlastic, bodyM)
	
	-- ==========================================
	-- CABIN & ROOF
	-- ==========================================
	local roofInset = 0.4 * scaleX
	local roofThick = 0.15 * scaleY
	
	GP.axisAlignedBlockFromCorners("RoofPanel",
	    Vector3.new(-halfW + roofInset, roofY - roofThick, roofFrontZ),
	    Vector3.new(halfW - roofInset, roofY, roofRearZ),
	    bodyColor, matPlastic, cabinM)
	
	-- Rear Window
	GP.quadFromFourPoints("RearWindow",
	    Vector3.new(-halfW + roofInset, roofY - roofThick, roofRearZ),
	    Vector3.new(halfW - roofInset, roofY - roofThick, roofRearZ),
	    Vector3.new(halfW - roofInset, beltLine, tailZ - 1 * scaleZ),
	    Vector3.new(-halfW + roofInset, beltLine, tailZ - 1 * scaleZ),
	    0.1 * scaleY, nil, glassColor, matGlass, cabinM, 0.4)
	
	-- Side Windows (Simple thick panels to enclose cabin)
	GP.quadFromFourPoints("SideWinL",
	    Vector3.new(-halfW + 0.2 * scaleX, beltLine, hoodZ + 0.2 * scaleZ),
	    Vector3.new(-halfW + 0.2 * scaleX, beltLine, tailZ - 1.2 * scaleZ),
	    Vector3.new(-halfW + roofInset, roofY - roofThick, roofRearZ),
	    Vector3.new(-halfW + roofInset, roofY - roofThick, roofFrontZ),
	    0.05 * scaleX, nil, glassColor, matGlass, cabinM, 0.4)
	
	GP.quadFromFourPoints("SideWinR",
	    Vector3.new(halfW - 0.2 * scaleX, beltLine, tailZ - 1.2 * scaleZ),
	    Vector3.new(halfW - 0.2 * scaleX, beltLine, hoodZ + 0.2 * scaleZ),
	    Vector3.new(halfW - roofInset, roofY - roofThick, roofFrontZ),
	    Vector3.new(halfW - roofInset, roofY - roofThick, roofRearZ),
	    0.05 * scaleX, nil, glassColor, matGlass, cabinM, 0.4)
	
	-- ==========================================
	-- WINDSHIELD
	-- ==========================================
	-- A sleek quad bridging the hood base to the roof front
	GP.quadFromFourPoints("WindshieldGlass",
	    Vector3.new(-halfW + 0.2 * scaleX, beltLine, hoodZ),
	    Vector3.new(halfW - 0.2 * scaleX, beltLine, hoodZ),
	    Vector3.new(halfW - roofInset, roofY, roofFrontZ),
	    Vector3.new(-halfW + roofInset, roofY, roofFrontZ),
	    0.1 * scaleY, nil, glassColor, matGlass, windshieldM, 0.4)
	
	-- ==========================================
	-- SPOILER
	-- ==========================================
	local strutX = halfW - 0.8 * scaleX
	local strutZ = tailZ - 0.6 * scaleZ
	local wingY = roofY - 0.2 * scaleY
	
	GP.strutFromTwoPoints("StrutL",
	    Vector3.new(-strutX, beltLine, strutZ),
	    Vector3.new(-strutX, wingY, strutZ + 0.2 * scaleZ),
	    0.2 * scaleX, 0.3 * scaleZ, bodyColor, matPlastic, spoilerM)
	
	GP.strutFromTwoPoints("StrutR",
	    Vector3.new(strutX, beltLine, strutZ),
	    Vector3.new(strutX, wingY, strutZ + 0.2 * scaleZ),
	    0.2 * scaleX, 0.3 * scaleZ, bodyColor, matPlastic, spoilerM)
	
	-- Main Horizontal Wing
	GP.axisAlignedBlockFromCorners("WingMain",
	    Vector3.new(-halfW - 0.2 * scaleX, wingY, strutZ - 0.2 * scaleZ),
	    Vector3.new(halfW + 0.2 * scaleX, wingY + 0.15 * scaleY, strutZ + 0.6 * scaleZ),
	    bodyColor, matPlastic, spoilerM)
	
	-- Wing Endcaps (Aero fins)
	GP.axisAlignedBlockFromCorners("WingFinL",
	    Vector3.new(-halfW - 0.3 * scaleX, wingY - 0.2 * scaleY, strutZ - 0.2 * scaleZ),
	    Vector3.new(-halfW - 0.1 * scaleX, wingY + 0.3 * scaleY, strutZ + 0.6 * scaleZ),
	    bodyColor, matPlastic, spoilerM)
	
	GP.axisAlignedBlockFromCorners("WingFinR",
	    Vector3.new(halfW + 0.1 * scaleX, wingY - 0.2 * scaleY, strutZ - 0.2 * scaleZ),
	    Vector3.new(halfW + 0.3 * scaleX, wingY + 0.3 * scaleY, strutZ + 0.6 * scaleZ),
	    bodyColor, matPlastic, spoilerM)
	
	-- ==========================================
	-- WHEELS
	-- ==========================================
	local function buildWheel(wModel, x, z)
	    local xSign = x > 0 and 1 or -1
	    local pCenter = Vector3.new(x, wheelY, z)
	    local pIn = pCenter - Vector3.new(xSign * wheelWidth / 2, 0, 0)
	    local pOut = pCenter + Vector3.new(xSign * wheelWidth / 2, 0, 0)
	    
	    -- Main Tire
	    GP.cylinder("Tire", pIn, pOut, wheelRadius, wheelColor, matPlastic, wModel)
	    
	    -- Rim Barrel
	    local rimDepth = 0.2 * scaleX
	    local rimOut = pOut - Vector3.new(xSign * 0.05, 0, 0)
	    local rimIn = rimOut - Vector3.new(xSign * rimDepth, 0, 0)
	    local rimRadius = wheelRadius * 0.7
	    GP.cylinder("Rim", rimIn, rimOut, rimRadius, rimColor, matPlastic, wModel)
	    
	    -- Hub Center
	    local hubOut = rimOut
	    local hubRadius = wheelRadius * 0.2
	    GP.cylinder("Hub", rimIn, hubOut + Vector3.new(2e-3, 0, 0), hubRadius, wheelColor, matPlastic, wModel) -- zf-prevention: vector3_component
	    
	    -- 5-Star Spokes using MU.radialArray
	    local spokeFaceAxis = Vector3.new(xSign, 0, 0)
	    MU.radialArray(rimOut - Vector3.new(xSign * 0.02, 0, 0), rimRadius - 0.05, 5, spokeFaceAxis, function(pos, i)
	        local hubPos = Vector3.new(hubOut.X, hubOut.Y, hubOut.Z)
	        GP.strutFromTwoPoints("Spoke"..i, hubPos, pos, 0.15 * scaleX, 0.1 * scaleY, rimColor, matPlastic, wModel)
	    end)
	end
	
	-- Remember: Object's left is -X, right is +X
	buildWheel(wFL, -trackX, frontWheelZ)
	buildWheel(wFR, trackX, frontWheelZ)
	buildWheel(wRL, -trackX, rearWheelZ)
	buildWheel(wRR, trackX, rearWheelZ)
	
	myModel.Parent = targetContainer
	-- reposition
	for _, part in targetContainer:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end
	for _, model in targetContainer:GetDescendants() do
		if model:IsA("Model") then
			model.WorldPivot -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end

	-- Stop timer when generation completes
	local timeElapsed = tick() - startTime
	startTime = 0
	if timeElapsed > 3 and script:IsDescendantOf(game) then
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering completed")
	end

end

return ToySportsCar
