--[[
		___      _______                _     
	   / _ |____/ ___/ /  ___ ____ ___ (_)__ 
	  / __ /___/ /__/ _ \/ _ `(_-<(_-</ (_-<
	 /_/ |_|   \___/_//_/\_,_/___/___/_/___/
 						SecondLogic @ Inspare
]]

script.Parent:WaitForChild("Speedo")
script.Parent:WaitForChild("Tach")
script.Parent:WaitForChild("ln")
script.Parent:WaitForChild("Gear")
script.Parent:WaitForChild("Speed")


local car = script.Parent.Parent.Car.Value
car.DriveSeat.HeadsUpDisplay = false

local _Tune = require(car["A-Chassis Tune"])

local _pRPM = _Tune.PeakRPM
local _lRPM = _Tune.Redline

local revEnd = math.ceil(_lRPM/1000)

local Drive={}
if _Tune.Config == "FWD" or _Tune.Config == "AWD" then
	if car.Wheels:FindFirstChild("FL")~= nil then
		table.insert(Drive,car.Wheels.FL)
	end
	if car.Wheels:FindFirstChild("FR")~= nil then
		table.insert(Drive,car.Wheels.FR)
	end
	if car.Wheels:FindFirstChild("F")~= nil then
		table.insert(Drive,car.Wheels.F)
	end
end
if _Tune.Config == "RWD" or _Tune.Config == "AWD" then
	if car.Wheels:FindFirstChild("RL")~= nil then
		table.insert(Drive,car.Wheels.RL)
	end
	if car.Wheels:FindFirstChild("RR")~= nil then
		table.insert(Drive,car.Wheels.RR)
	end
	if car.Wheels:FindFirstChild("R")~= nil then
		table.insert(Drive,car.Wheels.R)
	end
end

local wDia = 0
for i,v in pairs(Drive) do
	if v.Size.x>wDia then wDia = v.Size.x end
end
Drive = nil
local maxSpeed = math.ceil(wDia*math.pi*_lRPM/60/_Tune.Ratios[#_Tune.Ratios]/_Tune.FinalDrive)
local spInc = math.max(math.ceil(maxSpeed/200)*20,20)


for i=0,revEnd*2 do
	local ln = script.Parent.ln:clone()
	ln.Parent = script.Parent.Tach
	ln.Rotation = 45 + i * 225 / (revEnd*2)
	ln.Num.Text = i/2
	ln.Num.Rotation = -ln.Rotation
	if i*500>=math.floor(_pRPM/500)*500 then
		ln.Frame.BackgroundColor3 = Color3.new(1,0,0)
		if i<revEnd*2 then
			ln2 = ln:clone()
			ln2.Parent = script.Parent.Tach
			ln2.Rotation = 45 + (i+.5) * 225 / (revEnd*2)
			ln2.Num:Destroy()
			ln2.Visible=true
		end
	end
	if i%2==0 then
		ln.Frame.Size = UDim2.new(0,3,0,10)
		ln.Frame.Position = UDim2.new(0,-1,0,100)
		ln.Num.Visible = true
	else
		ln.Num:Destroy()
	end
	ln.Visible=true
end

for i=1,90 do
	local ln = script.Parent.ln:clone()
	ln.Parent = script.Parent.Speedo
	ln.Rotation = 45 + 225*(i/90)
	if i%2==0 then
		ln.Frame.Size = UDim2.new(0,2,0,10)
		ln.Frame.Position = UDim2.new(0,-1,0,100)
	else
		ln.Frame.Size = UDim2.new(0,3,0,5)
	end
	ln.Num:Destroy()
	ln.Visible=true
end
for i=0,maxSpeed,spInc do
	local ln = script.Parent.ln:clone()
	ln.Parent = script.Parent.Speedo
	ln.Rotation = 45 + 225*(i/maxSpeed)
	ln.Num.Text = i
	ln.Num.Rotation = -ln.Rotation
	ln.Frame:Destroy()
	ln.Num.Visible=true
	ln.Visible=true
end

if 	script.Parent.Parent.IsOn.Value then
	script.Parent:TweenPosition(UDim2.new(0, 0, 0, 0),Enum.EasingDirection.InOut,Enum.EasingStyle.Quad,1,true)
end

script.Parent.Parent.IsOn.Changed:connect(function()
	if script.Parent.Parent.IsOn.Value then
		script.Parent:TweenPosition(UDim2.new(0, 0, 0, 0),Enum.EasingDirection.InOut,Enum.EasingStyle.Quad,1,true)
	end
end)

script.Parent.Parent.Values.RPM.Changed:connect(function()
	script.Parent.Tach.Needle.Rotation = 45 + 225 * math.min(1,script.Parent.Parent.Values.RPM.Value / (revEnd*1000))
end)

script.Parent.Parent.Values.Gear.Changed:connect(function()
	local gearText = script.Parent.Parent.Values.Gear.Value
	if gearText == 0 then gearText = "N"
	elseif gearText == -1 then gearText = "R"
	end
	script.Parent.Gear.Text = gearText
end)

script.Parent.Parent.Values.TCS.Changed:connect(function()
	if script.Parent.Parent.Values.TCS.Value then
		script.Parent.TCS.TextColor3 = Color3.new(1,170/255,0)
		script.Parent.TCS.TextStrokeColor3 = Color3.new(1,170/255,0)
		if script.Parent.Parent.Values.TCSActive.Value then
			wait()
			script.Parent.TCS.Visible = not script.Parent.TCS.Visible
		else
			wait()
			script.Parent.TCS.Visible = false
		end
	else
		script.Parent.TCS.Visible = true
		script.Parent.TCS.TextColor3 = Color3.new(1,0,0)
		script.Parent.TCS.TextStrokeColor3 = Color3.new(1,0,0)
	end
end)

script.Parent.Parent.Values.TCSActive.Changed:connect(function()
	if script.Parent.Parent.Values.TCSActive.Value and script.Parent.Parent.Values.TCS.Value then
		wait()
		script.Parent.TCS.Visible = not script.Parent.TCS.Visible
	elseif not script.Parent.Parent.Values.TCS.Value then
		wait()
		script.Parent.TCS.Visible = true
	else
		wait()
		script.Parent.TCS.Visible = false
	end
end)

script.Parent.TCS.Changed:connect(function()
	if script.Parent.Parent.Values.TCSActive.Value and script.Parent.Parent.Values.TCS.Value then
		wait()
		script.Parent.TCS.Visible = not script.Parent.TCS.Visible
	elseif not script.Parent.Parent.Values.TCS.Value then
		wait()
		script.Parent.TCS.Visible = true
	end
end)

script.Parent.Parent.Values.PBrake.Changed:connect(function()
	script.Parent.PBrake.Visible = script.Parent.Parent.Values.PBrake.Value
end)

script.Parent.Parent.Values.TransmissionMode.Changed:connect(function()
	if script.Parent.Parent.Values.TransmissionMode.Value == "Auto" then
		script.Parent.TMode.Text = "A/T"
		script.Parent.TMode.BackgroundColor3 = Color3.new(1,170/255,0)
	elseif script.Parent.Parent.Values.TransmissionMode.Value == "Semi" then
		script.Parent.TMode.Text = "S/T"
		script.Parent.TMode.BackgroundColor3 = Color3.new(0, 170/255, 127/255) 
	else
		script.Parent.TMode.Text = "M/T"
		script.Parent.TMode.BackgroundColor3 = Color3.new(1,85/255,.5)
	end
end)

script.Parent.Parent.Values.Velocity.Changed:connect(function(property)
	script.Parent.Speedo.Needle.Rotation =45 + 225 * math.min(1,script.Parent.Parent.Values.Velocity.Value.Magnitude/maxSpeed)
	script.Parent.Speed.Text = math.floor(script.Parent.Parent.Values.Velocity.Value.Magnitude) .. " SPS"
end)
