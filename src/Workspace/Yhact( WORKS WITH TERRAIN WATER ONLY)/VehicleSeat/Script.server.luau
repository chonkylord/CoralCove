-- Object variables
local Seat = script.Parent
local Thrust = Seat.Parent:WaitForChild("Thrust")
local MainPart = Seat.Parent:WaitForChild("Main")
local Force = Thrust:WaitForChild("Force")
local Tilt = Thrust:WaitForChild("Tilt")

-- Boat settings
local BoatSpeed = 6
local TurnSpeed = 0.9
local TiltPower = 4.5*(10^6)

function Examine(Number)
	if Number == 1 then
		return 1
	elseif Number == -1 then
		return 1
	else return Number end
end

while wait() do
-- Boat lookvector
local p1,p2,p3,xx,xy,xz,yx,yy,yz,zx,zy,zz = Thrust.CFrame:components()
local FTLV = Thrust.CFrame.lookVector
local DNLV = -Vector3.new(xy,yy,zy)
local RTLV = Vector3.new(xz,yz,zz)
local SeatMagnitude = Seat.Velocity.magnitude
local FinalTiltPower = (TiltPower*math.rad(SeatMagnitude))*Examine(Seat.Steer)

	-- ACCELERATING
	Force.Force = Seat.Throttle * (FTLV*MainPart:GetMass()*BoatSpeed)
	
	-- STEERING
	Tilt.MaxTorque = Vector3.new(FinalTiltPower,FinalTiltPower,FinalTiltPower)
	MainPart.RotVelocity = Seat.Steer * (Vector3.new(0,-1*TurnSpeed/6,0))
	Tilt.AngularVelocity = Seat.Steer*(RTLV)
	
end