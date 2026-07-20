local car = script.Parent.Parent.Car.Value

local Mode=0
local SpoilerPerc
local BrakePerc
local APerc=0
local pAPerc=0
local pSPerc=SpoilerPerc
local pBPerc=BrakePerc
local SPup=false
local GBrake = script.Parent.Parent.Values.Brake
local dySpeed = 40

car.DriveSeat.ChildRemoved:connect(function(child)
	for i,v in pairs(car.Misc.Downforce:GetChildren()) do
		v.Force = Vector3.new()
	end
end)

function Downforce()
	local sp = script.Parent.Parent.Values.Velocity.Value.Magnitude
	if sp>=40 then
		dySpeed = 20
	elseif sp<=20 then
		dySpeed = 40
	end
	
	if sp>50 then
		SPup=true
	elseif sp<25 then
		SPup=false
	end
	
	if (SPup and Mode~=2) or Mode == 1 then
		if sp>80 and Mode == 0 and GBrake.Value <= .3 then
			SpoilerPerc=1
		else
			SpoilerPerc=1
		end
	else
		SpoilerPerc=0
	end
	
	if GBrake.Value >.3 and script.Parent.Parent.Values.Gear.Value~=-1 and SpoilerPerc>.6 then
		BrakePerc=1
	elseif sp>80 and Mode == 0 and SpoilerPerc>.6 then
		BrakePerc=0
	else
		BrakePerc=0
	end
	if car.Misc.Spoiler.A.A1.W.CurrentAngle/.4 >.5 then 
		APerc=.5*SpoilerPerc
	else
		APerc=0
	end
	
	if SpoilerPerc~=pSPerc or BrakePerc~=pBPerc or APerc~=pAPerc then
		car.Misc.Spoiler.A.A1.W.DesiredAngle=.15*SpoilerPerc
		car.Misc.Spoiler.A.A2.W.DesiredAngle=-.3*SpoilerPerc
		car.Misc.Spoiler.A.A3.W.DesiredAngle=.15*SpoilerPerc
		
		car.Misc.Spoiler.B.B1.W.DesiredAngle=APerc*(.15 +(.085*BrakePerc))
		car.Misc.Spoiler.B.B2.W.DesiredAngle=APerc*-(.3 +(.15*BrakePerc))
		car.Misc.Spoiler.B.B3.W.DesiredAngle=APerc*(.15 +(.075*BrakePerc))
		
		car.Misc.Spoiler.C.C1.W.DesiredAngle=APerc*(.14 -(.075*BrakePerc))
		car.Misc.Spoiler.C.C2.W.DesiredAngle=APerc*-(.3 -(.15*BrakePerc))
		car.Misc.Spoiler.C.C3.W.DesiredAngle=APerc*(.15 -(.075*BrakePerc))

		car.Misc.Spoiler.D.W.DesiredAngle=APerc*BrakePerc*math.rad(-55)
	end
	pSPerc=SpoilerPerc
	pBPerc=BrakePerc
	pAPerc=APerc
end

script.Parent.MouseButton1Click:connect(function()
	if Mode==2 then
		Mode=0
	else
		Mode=Mode+1
	end
	if Mode==0 then
		script.Parent.Text="Aero: Dynamic"
	elseif Mode==1 then
		script.Parent.Text="Aero: Always On"
	elseif Mode==2 then
		script.Parent.Text="Aero: Off"
	end
end)

script.Parent.Parent.Values.Velocity.Changed:connect(function()
	Downforce()
	local sp = script.Parent.Parent.Values.Velocity.Value.Magnitude
	local sPerc = car.Misc.Spoiler.A.A1.W.CurrentAngle/.4
	local bPerc = car.Misc.Spoiler.D.W.CurrentAngle/math.rad(-55)
	car.Misc.Downforce.Body.Force = Vector3.new(0, -sp*7, -sp*2)
	car.Misc.Downforce.Splitter.Force = Vector3.new(0, -sp*4, 0)
	car.Misc.Downforce.Diffuser.Force = Vector3.new(0, -sp*4, 0)
	car.Misc.Downforce.Spoiler.Force = Vector3.new(0, -sp*17*sPerc^2, -sp*(1.3+bPerc*2.7)*sPerc^2)
end)