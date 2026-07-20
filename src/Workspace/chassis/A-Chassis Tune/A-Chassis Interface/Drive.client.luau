--[[
		___      _______                _     
	   / _ |____/ ___/ /  ___ ____ ___ (_)__ 
	  / __ /___/ /__/ _ \/ _ `(_-<(_-</ (_-<
	 /_/ |_|   \___/_//_/\_,_/___/___/_/___/
 						SecondLogic @ Inspare


*I assume you know what you're doing if you're gonna change something here.* ]]--


script.Parent:WaitForChild("Car")
script.Parent:WaitForChild("IsOn")
script.Parent:WaitForChild("ControlsOpen")
script.Parent:WaitForChild("Values")

--Vars
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local UserInputService = game:GetService("UserInputService")
local cam = workspace.CurrentCamera

local car = script.Parent.Car.Value
local _Tune = require(car["A-Chassis Tune"])
local _IsOn = _Tune.AutoStart
if _Tune.AutoStart then script.Parent.IsOn.Value=true end

local _GSteerT=0
local _GSteerC=0
local _GThrot=0
local _GBrake=0

local _ClutchOn = true
local _ClPressing = false
local _RPM = 0
local _HP = 0
local _OutTorque = 0
local _CGear = 0
local _PGear = _CGear

local _TMode = _Tune.TransModes[1]

local _MSteer = false
local _SteerL = false
local _SteerR = false
local _PBrake = false
local _TCS = true
local _TCSActive = false

local FlipWait=tick()
local FlipDB=false

local _InControls = false

--Shutdown
car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" and child:IsA("Weld") then
		script.Parent:Destroy()
	end
end)

--Controls
local _CTRL = _Tune.Controls
local Controls = Instance.new("Folder",script.Parent)
Controls.Name = "Controls"
for i,v in pairs(_CTRL) do
	local a=Instance.new("StringValue",Controls)
	a.Name=i
	a.Value=v.Name
	a.Changed:connect(function()
		if i=="MouseThrottle" or i=="MouseBrake" then
			_CTRL[i]=Enum.UserInputType[a.Value]
		else
			_CTRL[i]=Enum.KeyCode[a.Value]
		end
	end)
end

local _PPH = _Tune.Peripherals
	for i,v in pairs(_PPH) do
	local a = Instance.new("IntValue",Controls)
	a.Name = i
	a.Value = v
	a.Changed:connect(function() 
		a.Value=math.min(100,math.max(0,a.Value))
		_PPH[i] = a.Value
	end)
end

function DealWithInput(input,IsRobloxFunction)
	if (UserInputService:GetFocusedTextBox()==nil) and not _InControls then --No texting while driving
		if _IsOn and  (input.KeyCode ==_CTRL["ContlrShiftDown"] or (_MSteer and input.KeyCode==_CTRL["MouseShiftDown"]) or ((not _MSteer) and input.KeyCode==_CTRL["ShiftDown"])) and (_TMode=="Semi" or (_TMode=="Manual" and (not _ClutchOn))) and input.UserInputState == Enum.UserInputState.Begin then
			if _CGear == 0 and (_TMode=="Auto" or not _ClPressing) then _ClutchOn = true end
			_CGear = math.max(_CGear-1,-1)
		elseif _IsOn and  (input.KeyCode ==_CTRL["ContlrShiftUp"] or (_MSteer and input.KeyCode==_CTRL["MouseShiftUp"]) or ((not _MSteer) and input.KeyCode==_CTRL["ShiftUp"])) and (_TMode=="Semi" or (_TMode=="Manual" and (not _ClutchOn))) and input.UserInputState == Enum.UserInputState.Begin then
			if _CGear == 0 and (_TMode=="Auto" or not _ClPressing) then _ClutchOn = true end
			_CGear = math.min(_CGear+1,#_Tune.Ratios-2)
		elseif _IsOn and  (input.KeyCode ==_CTRL["ContlrClutch"] or (_MSteer and input.KeyCode==_CTRL["MouseClutch"]) or ((not _MSteer) and input.KeyCode==_CTRL["Clutch"])) and _TMode=="Manual" then
			if input.UserInputState == Enum.UserInputState.Begin then
				_ClutchOn = false
				_ClPressing = true
			elseif input.UserInputState == Enum.UserInputState.End then
				_ClutchOn = true
				_ClPressing = false
			end
		elseif _IsOn and  input.KeyCode ==_CTRL["ContlrPBrake"] or (_MSteer and input.KeyCode==_CTRL["MousePBrake"]) or ((not _MSteer) and input.KeyCode==_CTRL["PBrake"]) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_PBrake = not _PBrake
			elseif input.UserInputState == Enum.UserInputState.End then
				if car.DriveSeat.Velocity.Magnitude>5 then
					_PBrake = false
				end
			end
		elseif (input.KeyCode == _CTRL["ContlrToggleTMode"] or input.KeyCode==_CTRL["ToggleTransMode"]) and input.UserInputState == Enum.UserInputState.Begin then
			local n=1
			for i,v in pairs(_Tune.TransModes) do
				if v==_TMode then n=i break end
			end
			n=n+1
			if n>#_Tune.TransModes then n=1 end
			_TMode = _Tune.TransModes[n]
		elseif _IsOn and ((not _MSteer) and (input.KeyCode==_CTRL["Throttle"] or input.KeyCode == _CTRL["Throttle2"])) or (input.UserInputType == _CTRL["MouseThrottle"] and _MSteer) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_GThrot = 1
			else
				_GThrot = _Tune.IdleThrottle
			end
		elseif ((not _MSteer) and (input.KeyCode==_CTRL["Brake"] or input.KeyCode == _CTRL["Brake2"])) or (input.UserInputType == _CTRL["MouseBrake"] and _MSteer) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_GBrake = 1
			else
				_GBrake = 0
			end
		elseif (not _MSteer) and (input.KeyCode==_CTRL["SteerLeft"] or input.KeyCode == _CTRL["SteerLeft2"]) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_GSteerT = -1
				_SteerL = true
			else
				if _SteerR then
					_GSteerT = 1
				else
					_GSteerT = 0
				end
				_SteerL = false
			end
		elseif (not _MSteer) and (input.KeyCode==_CTRL["SteerRight"] or input.KeyCode == _CTRL["SteerRight2"]) then
			if input.UserInputState == Enum.UserInputState.Begin then
				_GSteerT = 1
				_SteerR = true
			else
				if _SteerL then
					_GSteerT = -1
				else
					_GSteerT = 0
				end
				_SteerR = false
			end
		elseif input.KeyCode ==_CTRL["ToggleMouseDrive"] then
			if input.UserInputState == Enum.UserInputState.End then
				_MSteer = not _MSteer
				_GThrot = _Tune.IdleThrottle
				_GBrake = 0
				_GSteerT = 0
				_ClutchOn = true
			end
		elseif  _IsOn and input.KeyCode == _CTRL["ToggleTCS"] or input.KeyCode == _CTRL["ContlrToggleTCS"] then
			if input.UserInputState == Enum.UserInputState.End then
				_TCS = not _TCS
			end
		end
		if input.UserInputType.Name:find("Gamepad") then
			if input.KeyCode == _CTRL["ContlrSteer"] then
				
				if input.Position.X>= 0 then
					local cDZone = math.min(.99,_Tune.Peripherals.ControlRDZone/100)
					if math.abs(input.Position.X)>cDZone then
						_GSteerT = (input.Position.X-cDZone)/(1-cDZone)
					else
						_GSteerT = 0
					end
				else
					local cDZone = math.min(.99,_Tune.Peripherals.ControlLDZone/100)
					if math.abs(input.Position.X)>cDZone then
						_GSteerT = (input.Position.X+cDZone)/(1-cDZone)
					else
						_GSteerT = 0
					end
				end
			elseif _IsOn and input.KeyCode == _CTRL["ContlrThrottle"] then
				_GThrot = math.max(_Tune.IdleThrottle,input.Position.Z)
			elseif input.KeyCode == _CTRL["ContlrBrake"] then
				_GBrake = input.Position.Z
			end
		end
	else
		_GThrot = _Tune.IdleThrottle
		_GSteerT = 0
		_GBrake = 0
		if _CGear~=0 then _ClutchOn = true end
	end
end
UserInputService.InputBegan:connect(DealWithInput)
UserInputService.InputChanged:connect(DealWithInput)
UserInputService.InputEnded:connect(DealWithInput)

---Drivetrain Initialize
local wDia = 0
local Drive={}
if _Tune.Config == "FWD" or _Tune.Config == "AWD" then
	for i,v in pairs(car.Wheels:GetChildren()) do
		if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then
			table.insert(Drive,v)
		end
	end
end
if _Tune.Config == "RWD" or _Tune.Config == "AWD" then
	for i,v in pairs(car.Wheels:GetChildren()) do
		if v.Name=="RL" or v.Name=="RR" or v.Name=="R" then
			table.insert(Drive,v)
		end
	end
end
for i,v in pairs(Drive) do
	if v.Size.x>wDia then wDia = v.Size.x end
end

for i,v in pairs(car.Wheels:GetChildren()) do
	if math.abs(v["#AV"].maxTorque.Magnitude-_Tune.PBrakeForce)<1 then
		_PBrake=true
	end
end

---Camera
game:GetService("RunService").RenderStepped:connect(function()
	if _MSteer then
		cam.CameraType = Enum.CameraType.Scriptable
		local pspeed = math.min(1,car.DriveSeat.Velocity.Magnitude/500)
		local cc = car.DriveSeat.Position+Vector3.new(0,8+(pspeed*2),0)-(car.DriveSeat.CFrame.lookVector*17)+(car.DriveSeat.Velocity.Unit*-7*pspeed)
		cam.CoordinateFrame = CFrame.new(cc,car.DriveSeat.Position)
	elseif cam.CameraType ~= Enum.CameraType.Custom then
		cam.CameraType = Enum.CameraType.Custom
	end
end)

---Steering
function Steering()
	if _MSteer then
		local msWidth = math.max(1,mouse.ViewSizeX*_Tune.Peripherals.MSteerWidth/200)
		local mdZone = _Tune.Peripherals.MSteerDZone/100
		local mST = ((mouse.X-mouse.ViewSizeX/2)/msWidth)
		if math.abs(mST)<=mdZone then
			_GSteerT = 0
		else
			_GSteerT = (math.max(math.min((math.abs(mST)-mdZone),(1-mdZone)),0)/(1-mdZone))^_Tune.MSteerExp * (mST / math.abs(mST))
		end
	end
	if _GSteerC < _GSteerT then
		_GSteerC = math.min(_GSteerT,_GSteerC+_Tune.SteerSpeed)
	else
		_GSteerC = math.max(_GSteerT,_GSteerC-_Tune.SteerSpeed)
	end
	local sDecay = (1-math.min(car.DriveSeat.Velocity.Magnitude/_Tune.SteerDecay,1-_Tune.MinSteer))
	for i,v in pairs(car.Wheels:GetChildren()) do
		if v.Name=="F" then
			v.Arm.Steer.cframe=car.Wheels.F.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*_Tune.SteerInner*sDecay),0)
		elseif v.Name=="FL" then
			if _GSteerC>= 0 then
				v.Arm.Steer.cframe=car.Wheels.FL.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*_Tune.SteerOuter*sDecay),0)
			else
				v.Arm.Steer.cframe=car.Wheels.FL.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*_Tune.SteerInner*sDecay),0)
			end
		elseif v.Name=="FR" then
			if _GSteerC>= 0 then
				v.Arm.Steer.cframe=car.Wheels.FR.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*_Tune.SteerInner*sDecay),0)
			else
				v.Arm.Steer.cframe=car.Wheels.FR.Base.CFrame*CFrame.Angles(0,-math.rad(_GSteerC*_Tune.SteerOuter*sDecay),0)
			end
		end
	end
end

--Engine
function Engine()
	--Neutral Gear
	if _CGear==0 then _ClutchOn = false end

	--Car is off
	local revMin = _Tune.IdleRPM
	if not _IsOn then 
		revMin = 0 
		_CGear = 0
		_ClutchOn = false
		_GThrot = _Tune.IdleThrottle
	end
	
	--Determine RPM
	local maxSpin=0
	for i,v in pairs(Drive) do
		if v.RotVelocity.Magnitude>maxSpin then maxSpin = v.RotVelocity.Magnitude end
	end
	if _ClutchOn then
		local aRPM = math.max(math.min(maxSpin*_Tune.Ratios[_CGear+2]*_Tune.FinalDrive*30/math.pi,_Tune.Redline+100),revMin)
		local clutchP = math.min(math.abs(aRPM-_RPM)/_Tune.ClutchTol,.9)
		_RPM = (  (_RPM*2*clutchP)  +  (aRPM*2*(1-clutchP))  )/2
		_HP = (_Tune.Horsepower/2) * math.sin((math.pi/((1+(math.min(10,_Tune.IdleOffset)/100))*_Tune.PeakRPM)) * (_RPM - (((2-(1+(math.min(10,_Tune.IdleOffset)/100)))* _Tune.PeakRPM)/2))) + (_Tune.Horsepower/2)
		_OutTorque = _HP * 5250 / _RPM * _Tune.Ratios[_CGear+2] * _Tune.FinalDrive
	else
		if _GThrot-_Tune.IdleThrottle>0 then
			_RPM = math.min(_RPM+_Tune.RevAccel*_GThrot,_Tune.Redline+100)
		else
			_RPM = math.max(_RPM-_Tune.RevDecay,revMin)
		end
		_OutTorque = 0
	end
	
	--Rev Limiter
	local spLimit = 0
	if _RPM>_Tune.Redline then 
		if _CGear<#_Tune.Ratios-2 then
			_RPM = _RPM-_Tune.RevBounce
			spLimit = 0
		else
			_RPM = _RPM-_Tune.RevBounce*.5
		end
	else
		spLimit = (_Tune.Redline+100)*math.pi/(30*_Tune.Ratios[_CGear+2]*_Tune.FinalDrive)
	end
	
	--Automatic Transmission
	if _TMode == "Auto" and _IsOn then
		_ClutchOn = true
		if _CGear == 0 then _CGear = 1 end
		if _CGear >= 1 then
			if _CGear==1 and _GBrake > 0  and car.DriveSeat.Velocity.Magnitude < 20 then
				_CGear = -1
			else
				if _Tune.AutoShiftMode == "RPM" then
					if _RPM>(_Tune.PeakRPM+_Tune.AutoUpThresh) then
						_CGear=math.min(_CGear+1,#_Tune.Ratios-2) 
					elseif math.max(math.min(maxSpin*_Tune.Ratios[_CGear+1]*_Tune.FinalDrive*30/math.pi,_Tune.Redline+100),_Tune.IdleRPM)<(_Tune.PeakRPM-_Tune.AutoDownThresh) then
						_CGear=math.max(_CGear-1,1)
					end
				else
					if car.DriveSeat.Velocity.Magnitude > math.ceil(wDia*math.pi*(_Tune.PeakRPM+_Tune.AutoUpThresh)/60/_Tune.Ratios[_CGear+2]/_Tune.FinalDrive) then
						_CGear=math.min(_CGear+1,#_Tune.Ratios-2)
					elseif car.DriveSeat.Velocity.Magnitude < math.ceil(wDia*math.pi*(_Tune.PeakRPM-_Tune.AutoDownThresh)/60/_Tune.Ratios[_CGear+1]/_Tune.FinalDrive) then
						_CGear=math.max(_CGear-1,1)
					end
				end
			end
		else
			if _GThrot-_Tune.IdleThrottle > 0 and car.DriveSeat.Velocity.Magnitude < 20 then
				_CGear = 1
			end
		end
	end 
	
	--Differential Stuff
	local fwspeed=0
	local fwcount=0
	local rwspeed=0
	local rwcount=0
	
	for i,v in pairs(car.Wheels:GetChildren()) do
		if v.Name=="FL" or v.Name=="FR" or v.Name == "F" then
			fwspeed=fwspeed+v.RotVelocity.Magnitude
			fwcount=fwcount+1
		elseif v.Name=="RL" or v.Name=="RR" or v.Name == "R" then
			rwspeed=rwspeed+v.RotVelocity.Magnitude
			rwcount=rwcount+1
		end
	end
	fwspeed=fwspeed/fwcount
	rwspeed=rwspeed/rwcount	
	local cwspeed=(fwspeed+rwspeed)/2
	
	--Apply Forces
	for i,v in pairs(car.Wheels:GetChildren()) do
		local Ref=v.Axle.CFrame.lookVector
		local aRef=1
		local diffMult=1
		if v.Name=="FL" or v.Name=="RL" then aRef=-1 end
		
		--Torque Compensation
		if _Tune.Config ~= "AWD" then _OutTorque = _OutTorque*1.3 end
		
		--Differential
		if v.Name=="FL" or v.Name=="FR" then
			diffMult=math.max(0,math.min(1,1+((((v.RotVelocity.Magnitude-fwspeed)/fwspeed)/(math.max(_Tune.FDiffSlipThres,1)/100))*((_Tune.FDiffLockThres-50)/50))))
			if _Tune.Config == "AWD" then
				diffMult=math.max(0,math.min(1,diffMult*(1+((((fwspeed-cwspeed)/cwspeed)/(math.max(_Tune.CDiffSlipThres,1)/100))*((_Tune.CDiffLockThres-50)/50)))))
			end
		elseif v.Name=="RL" or v.Name=="RR" then
			diffMult=math.max(0,math.min(1,1+((((v.RotVelocity.Magnitude-rwspeed)/rwspeed)/(math.max(_Tune.RDiffSlipThres,1)/100))*((_Tune.RDiffLockThres-50)/50))))
			if _Tune.Config == "AWD" then
				diffMult=math.max(0,math.min(1,diffMult*(1+((((rwspeed-cwspeed)/cwspeed)/(math.max(_Tune.CDiffSlipThres,1)/100))*((_Tune.CDiffLockThres-50)/50)))))
			end
		end
		
		--Output
		if _PBrake and ((_Tune.Config ~= "FWD" and (((v.Name=="FL" or v.Name=="FR") and car.DriveSeat.Velocity.Magnitude<20) or ((v.Name=="RR" or v.Name=="RL") and car.DriveSeat.Velocity.Magnitude>=20))) or (_Tune.Config == "FWD" and (v.Name=="RR" or v.Name=="RL"))) then
			v["#AV"].maxTorque=Vector3.new(math.abs(Ref.x),math.abs(Ref.y),math.abs(Ref.z))*_Tune.PBrakeForce
			v["#AV"].angularvelocity=Vector3.new()
		else
			if ((_TMode == "Manual" or _TMode == "Semi") and _GBrake==0) or (_TMode == "Auto" and ((_CGear>-1 and _GBrake==0 ) or (_CGear==-1 and _GThrot-_Tune.IdleThrottle==0 )))then
				local driven = false
				for _,a in pairs(Drive) do if a==v then driven = true end end
				if driven then
					local on=1
					if not script.Parent.IsOn.Value then on=0 end
					local throt = _GThrot
					if _TMode == "Auto" and _CGear==-1 then throt = _GBrake end
					local tqTCS = 1
					if _TCS then
						tqTCS = 1-(math.min(math.max(0,math.abs(v.RotVelocity.Magnitude*(v.Size.x/2) - v.Velocity.Magnitude)-_Tune.TCSThreshold)/_Tune.TCSGradient,1)*(1-_Tune.TCSLimit))
					end
					if tqTCS < 1 then
						_TCSActive = true
					else
						_TCSActive = false
					end
					local dir = 1
					if _CGear==-1 then dir = -1 end
					v["#AV"].maxTorque=Vector3.new(math.abs(Ref.x),math.abs(Ref.y),math.abs(Ref.z))*_OutTorque*(1+(v.RotVelocity.Magnitude/60)^1.15)*throt*tqTCS*diffMult*on
					v["#AV"].angularvelocity=Ref*aRef*spLimit*dir
				else
					v["#AV"].maxTorque=Vector3.new()
					v["#AV"].angularvelocity=Vector3.new()
				end
			else
				local brake = _GBrake
				if _TMode == "Auto" and _CGear==-1 then brake = _GThrot end
				v["#AV"].maxTorque=Vector3.new(math.abs(Ref.x),math.abs(Ref.y),math.abs(Ref.z))*_Tune.BrakeForce*brake
				v["#AV"].angularvelocity=Vector3.new()
			end
		end
	end
end


---Flip
function Flip()
	if (car.DriveSeat.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector.y > .1 or FlipDB then
		FlipWait=tick()
	else
		if tick()-FlipWait>=3 then
			FlipDB=true
			local gyro = car.DriveSeat.Flip
			gyro.maxTorque = Vector3.new(10000,0,10000)
			gyro.P=3000
			gyro.D=500
			wait(1)
			gyro.maxTorque = Vector3.new(0,0,0)
			gyro.P=0
			gyro.D=0
			FlipDB=false
		end
	end
end

--Run
local ver=require(car["A-Chassis Tune"].README)
print("//INSPARE: AC6 Loaded - Build "..ver)

while wait() do 
	Steering()
	Engine()
	if _Tune.AutoFlip then Flip() end
	
	_IsOn = script.Parent.IsOn.Value
	_InControls = script.Parent.ControlsOpen.Value
	script.Parent.Values.Gear.Value = _CGear
	script.Parent.Values.RPM.Value = _RPM
	script.Parent.Values.Horsepower.Value = _HP
	script.Parent.Values.Torque.Value = _HP * 5250 / _RPM
	script.Parent.Values.TransmissionMode.Value = _TMode
	script.Parent.Values.Throttle.Value = _GThrot
	script.Parent.Values.Brake.Value = _GBrake
	script.Parent.Values.SteerC.Value = _GSteerC*(1-math.min(car.DriveSeat.Velocity.Magnitude/_Tune.SteerDecay,1-_Tune.MinSteer))
	script.Parent.Values.SteerT.Value = _GSteerT
	script.Parent.Values.PBrake.Value = _PBrake
	script.Parent.Values.TCS.Value = _TCS
	script.Parent.Values.TCSActive.Value = _TCSActive
	script.Parent.Values.Velocity.Value = car.DriveSeat.Velocity
	
	if _PGear~=_CGear then
		_PGear=_CGear
		car.DriveSeat.MaxSpeed = car.DriveSeat.Velocity.Magnitude*(_Tune.Redline/_RPM)
	end
end

