local heat = 0
local pheat = heat
local car = script.Parent.Car.Value
local Drive = car.Wheels:GetChildren()
local _Tune = require(car["A-Chassis Tune"])

car.DriveSeat.ChildRemoved:connect(function(child)
	for i,a in pairs(Drive) do
		a.Parts.Heat.Transparency=1
		a.Parts.Heat.L.Range=0
	end
end)

while wait(.2) do
	for i,a in pairs(Drive) do
		if script.Parent.Values.Brake.Value>.3 and a.RotVelocity.Magnitude>100 then
			heat=math.min(1,heat+math.min(.075,.075*script.Parent.Values.Brake.Value*(a.RotVelocity.Magnitude/300)))
		else
			heat=math.max(0,heat-.025)
		end
		if pheat~=heat then
			a.Parts.Heat.Transparency=1-heat
			a.Parts.Heat.L.Range=heat*6
		end
	end
	pheat = heat
end