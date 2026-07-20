--BasedWeld2.0
local JS = game:GetService("JointsService")
function MakeWeld(x,y,type,s) 
	if type==nil then type="Weld" end
	local W=Instance.new(type,JS) 
	W.Part0=x W.Part1=y 
	W.C0=x.CFrame:inverse()*x.CFrame 
	W.C1=y.CFrame:inverse()*x.CFrame 
	if type=="Motor" and s~=nil then 
		W.MaxVelocity=s 
	end 
	return W	
end

function ModelWeld(a,b) 
	if a:IsA("BasePart") then 
		MakeWeld(b,a,"Weld") 
	elseif a:IsA("Model") then 
		for i,v in pairs(a:GetChildren()) do 
			ModelWeld(v,b) 
		end 
	end 
end

function UnAnchor(a) 
	if a:IsA("BasePart") then a.Anchored=false  end for i,v in pairs(a:GetChildren()) do UnAnchor(v) end 
end
--
script.Parent:WaitForChild("A-Chassis Interface")
script.Parent:WaitForChild("Plugins")
script.Parent:WaitForChild("README")

local car=script.Parent.Parent
local _Tune=require(script.Parent)

local Drive=car.Wheels:GetChildren()

function getParts(model,t,a)
	for i,v in pairs(model:GetChildren()) do
		if v:IsA("BasePart") then table.insert(t,{v,a.CFrame:toObjectSpace(v.CFrame)})
		elseif v:IsA("Model") then getParts(v,t,a)
		end
	end
end

for _,v in pairs(Drive) do
	
	for _,a in pairs({"Top","Bottom","Left","Right","Front","Back"}) do
		v[a.."Surface"]=Enum.SurfaceType.SmoothNoOutlines
	end
	
	local WParts = {}
	
	local tPos = v.Position-car.DriveSeat.Position
	if v.Name=="FL" or v.Name=="RL" then
		v.CFrame = car.DriveSeat.CFrame*CFrame.Angles(math.rad(90),0,math.rad(90))
	else
		v.CFrame = car.DriveSeat.CFrame*CFrame.Angles(math.rad(90),0,math.rad(-90))
	end
	v.CFrame = v.CFrame+tPos
	
	if v:FindFirstChild("Parts")~=nil then
		getParts(v.Parts,WParts,v)
	end
	if v:FindFirstChild("Fixed")~=nil then
		getParts(v.Fixed,WParts,v)
	end
	
	if v.Name=="FL" or v.Name=="FR" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.FCamber),0,0)
		if v.Name=="FL" then
			v.CFrame = v.CFrame*CFrame.Angles(0,0,math.rad(_Tune.FToe))
		else
			v.CFrame = v.CFrame*CFrame.Angles(0,0,math.rad(-_Tune.FToe))
		end
	elseif v.Name=="RL" or v.Name=="RR" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.RCamber),0,0)
		if v.Name=="RL" then
			v.CFrame = v.CFrame*CFrame.Angles(0,0,math.rad(_Tune.RToe))
		else
			v.CFrame = v.CFrame*CFrame.Angles(0,0,math.rad(-_Tune.RToe))
		end
	end
	
	for _,a in pairs(WParts) do
		a[1].CFrame=v.CFrame:toWorldSpace(a[2])
	end
	
	if v.Name=="FL" then
		v.CFrame = v.CFrame*CFrame.Angles(0,math.rad(-_Tune.FCaster),0)
	elseif v.Name=="FR" or v.Name=="F" then
		v.CFrame = v.CFrame*CFrame.Angles(0,math.rad(_Tune.FCaster),0)
	elseif v.Name=="RL" then
		v.CFrame = v.CFrame*CFrame.Angles(0,math.rad(-_Tune.RCaster),0)
	elseif v.Name=="RR" or v.Name=="R" then
		v.CFrame = v.CFrame*CFrame.Angles(0,math.rad(_Tune.RCaster),0)
	end
	
	local arm=Instance.new("Part",v)
	arm.Name="Arm"
	arm.Anchored=true
	arm.CanCollide=false
	arm.FormFactor=Enum.FormFactor.Custom
	arm.Size=Vector3.new(1,1,1)
	arm.CFrame=(v.CFrame*CFrame.new(0,_Tune.StAxisOffset,0))*CFrame.Angles(-math.pi/2,-math.pi/2,0)
	arm.TopSurface=Enum.SurfaceType.Smooth
	arm.BottomSurface=Enum.SurfaceType.Smooth
	arm.Transparency=1
	
	local base=arm:Clone()
	base.Parent=v
	base.Name="Base"
	base.CFrame=base.CFrame*CFrame.new(0,1,0)
	base.BottomSurface=Enum.SurfaceType.Hinge
	
	local axle=arm:Clone()
	axle.Parent=v
	axle.Name="Axle"
	axle.CFrame=CFrame.new(v.Position-((v.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector*((v.Size.x/2)+(axle.Size.x/2))),v.Position)*CFrame.Angles(0,math.pi,0)
	axle.BackSurface=Enum.SurfaceType.Hinge
	
	if v.Name=="F" or v.Name=="R" then
		local axle2=arm:Clone()
		axle2.Parent=v
		axle2.Name="Axle"
		axle2.CFrame=CFrame.new(v.Position+((v.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector*((v.Size.x/2)+(axle2.Size.x/2))),v.Position)*CFrame.Angles(0,math.pi,0)
		axle2.BackSurface=Enum.SurfaceType.Hinge
		MakeWeld(arm,axle2)
	end
	
	MakeWeld(car.DriveSeat,base)
	if v.Parent.Name == "RL" or v.Parent.Name == "RR" or v.Name=="R" then
		MakeWeld(car.DriveSeat,arm)
	end
	
	MakeWeld(arm,axle)
	
	arm:MakeJoints()
	axle:MakeJoints()

	
	if v:FindFirstChild("Fixed")~=nil then
		ModelWeld(v.Fixed,axle)
	end
	
	if v:FindFirstChild("Parts")~=nil then
		ModelWeld(v.Parts,v)
	end
	
	if v:FindFirstChild("Steer") then
		v:FindFirstChild("Steer"):Destroy()
	end
	
	local gyro=Instance.new("BodyGyro",v)
	gyro.Name="Stabilizer"
	if v.Name=="FL" or v.Name=="FR"  or v.Name=="F" then
		gyro.D=_Tune.FGyroD
		gyro.MaxTorque=_Tune.FGyroMaxTorque
		gyro.P=_Tune.FGyroP
	else
		gyro.D=_Tune.RGyroD
		gyro.MaxTorque=_Tune.RGyroMaxTorque
		gyro.P=_Tune.RGyroP
	end
	
	if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then
		local steer=Instance.new("BodyGyro",arm)
		steer.Name="Steer"
		steer.P=_Tune.SteerP
		steer.D=_Tune.SteerD
		steer.MaxTorque=Vector3.new(0,_Tune.SteerMaxTorque,0)
		steer.cframe=base.CFrame
	else
		MakeWeld(base,axle,"Weld")
	end
	
	local AV=Instance.new("BodyAngularVelocity",v)
	AV.Name="#AV"
	AV.angularvelocity=Vector3.new(0,0,0)
	AV.maxTorque=Vector3.new(_Tune.PBrakeForce,0,_Tune.PBrakeForce)
	AV.P=1e9
end

for i,v in pairs(script:GetChildren()) do
	if v:IsA("ModuleScript") then
		require(v)
	end
end

wait()
ModelWeld(car.Body,car.DriveSeat)

local flipG = Instance.new("BodyGyro",car.DriveSeat)
flipG.Name = "Flip"
flipG.D = 0
flipG.MaxTorque = Vector3.new(0,0,0)
flipG.P = 0

wait()

UnAnchor(car)

script.Parent["A-Chassis Interface"].Car.Value=car
for i,v in pairs(script.Parent.Plugins:GetChildren()) do
	for _,a in pairs(v:GetChildren()) do
		if a:IsA("RemoteEvent") or a:IsA("RemoteFunction") then 
			a.Parent=car
			for _,b in pairs(a:GetChildren()) do
				if b:IsA("Script") then b.Disabled=false end
			end	
		end
	end
	v.Parent = script.Parent["A-Chassis Interface"]
end
script.Parent.Plugins:Destroy()

car.DriveSeat.ChildAdded:connect(function(child)
	if child.Name=="SeatWeld" and child:IsA("Weld") and game.Players:GetPlayerFromCharacter(child.Part1.Parent)~=nil then
		local p=game.Players:GetPlayerFromCharacter(child.Part1.Parent)
		car.DriveSeat:SetNetworkOwner(p)
		local g=script.Parent["A-Chassis Interface"]:Clone()
		g.Parent=p.PlayerGui
	end
end)
car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" and child:IsA("Weld") then
		for i,v in pairs(car.DriveSeat:GetChildren()) do
			if v:IsA("Sound") then v:Stop() end
		end
		if car.DriveSeat:FindFirstChild("Flip")~=nil then
			car.DriveSeat.Flip.MaxTorque = Vector3.new()
		end
		for i,v in pairs(car.Wheels:GetChildren()) do
			if v:FindFirstChild("#AV")~=nil then
				if v["#AV"].AngularVelocity.Magnitude>0 then
					v["#AV"].AngularVelocity = Vector3.new()
					v["#AV"].MaxTorque = Vector3.new()
				end
			end
		end
	end
end)

ver = require(script.Parent.README)