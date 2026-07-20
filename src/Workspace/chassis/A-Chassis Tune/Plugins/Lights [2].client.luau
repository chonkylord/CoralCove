script.Parent:WaitForChild("Values")

local is = game:GetService("UserInputService")
local cr = script.Parent.Car.Value
local lt = cr.Body.Lights2
local tk = cr.Body.TK2
local vl = script.Parent.Values
local GBrake = vl.Brake
local gr = vl.Gear
local bk = vl.Brake.Value

local l1 = lt.RunL
local r1 = lt.RunR
local b1 = tk.RLeft
local b2 = tk.RRight
local b3 = lt.Brake
local b4 = tk.Brake
local lw = lt.B
local lww = lt.L
local lwww = lt.L2
local hi = lt.HB
local rb = tk.RB
local rv = tk.Reverse

local left = false
local right = false
local hazards = false
local reverse = false
local headlt = false
local highlt = false
local relay = false
local brake = false

function DealWithInput(input,processed)
	if (processed) then return end
	if input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then --Brake
		if input.UserInputState == Enum.UserInputState.Begin then
			brake=true
			b3.BrickColor = BrickColor.new("Really red")
			b3.Material = Enum.Material.Neon
			b4.BrickColor = BrickColor.new("Really red")
			b4.Material = Enum.Material.Neon
		elseif input.UserInputState == Enum.UserInputState.End then
			brake=false
				b3.BrickColor = BrickColor.new("Bright red")
				b3.Material = Enum.Material.SmoothPlastic
				b4.BrickColor = BrickColor.new("Black")
				b4.Material = Enum.Material.SmoothPlastic
		end
	elseif input.KeyCode == Enum.KeyCode.Z then if input.UserInputState == Enum.UserInputState.Begin then
		if hazards then return end
		left = not left
		right = false
		if relay then repeat wait() until not relay end
		while left do
			l1.BrickColor = BrickColor.new("Deep orange")
			l1.Material = Enum.Material.Neon
			b1.BrickColor = BrickColor.new("Really red")
			b1.Material = Enum.Material.Neon
			cr.DriveSeat.Indicator.Value = true
			cr.DriveSeat.LI.Value = true
			wait(1/3)
			l1.BrickColor = BrickColor.new("Medium stone grey")
			l1.Material = Enum.Material.SmoothPlastic
			cr.DriveSeat.Indicator.Value = false
			cr.DriveSeat.LI.Value = false
			if not headlt then
			b1.BrickColor = BrickColor.new("Bright red")
			b1.Material = Enum.Material.SmoothPlastic
			else
			b1.BrickColor = BrickColor.new("Bright red")
			b1.Material = Enum.Material.SmoothPlastic
			end
			wait(1/3)
			if not left then
				l1.Material = Enum.Material.Neon
				l1.BrickColor = BrickColor.new("Pearl")
			end
		end end
	elseif input.KeyCode == Enum.KeyCode.X then if input.UserInputState == Enum.UserInputState.Begin then
		if hazards == false then
			hazards = true
			left = true
			right = true
		else
			hazards = false
			left = false
			right = false
		end
		if hazards then left = false right = false end
		if relay then repeat wait() until not relay end
		while hazards do
			l1.BrickColor = BrickColor.new("Deep orange")
			l1.Material = Enum.Material.Neon
			r1.BrickColor = BrickColor.new("Deep orange")
			r1.Material = Enum.Material.Neon
			b1.BrickColor = BrickColor.new("Really red")
			b1.Material = Enum.Material.Neon
			
			b2.BrickColor = BrickColor.new("Really red")
			b2.Material = Enum.Material.Neon
			cr.DriveSeat.Indicator.Value = true
			cr.DriveSeat.LI.Value = true
			cr.DriveSeat.RI.Value = true
			wait(1/3)
			l1.BrickColor = BrickColor.new("Medium stone grey")
			l1.Material = Enum.Material.SmoothPlastic
			r1.BrickColor = BrickColor.new("Medium stone grey")
			r1.Material = Enum.Material.SmoothPlastic
			b1.BrickColor = BrickColor.new("Bright red")
			b1.Material = Enum.Material.SmoothPlastic
			b2.BrickColor = BrickColor.new("Bright red")
			b2.Material = Enum.Material.SmoothPlastic
			cr.DriveSeat.Indicator.Value = false
			cr.DriveSeat.LI.Value = false
			cr.DriveSeat.RI.Value = false
			wait(1/3)
			if not hazards then
				l1.Material = Enum.Material.Neon
				r1.Material = Enum.Material.Neon
				l1.BrickColor = BrickColor.new("Pearl")
				r1.BrickColor = BrickColor.new("Pearl")
			end
		end end
	elseif input.KeyCode == Enum.KeyCode.C then if input.UserInputState == Enum.UserInputState.Begin then
		if hazards then return end
		right = not right
		left = false
		if relay then repeat wait() until not relay end
		while right do
			r1.BrickColor = BrickColor.new("Deep orange")
			r1.Material = Enum.Material.Neon
			b2.BrickColor = BrickColor.new("Really red")
			b2.Material = Enum.Material.Neon
			cr.DriveSeat.Indicator.Value = true
			cr.DriveSeat.RI.Value = true
			wait(1/3)
			r1.BrickColor = BrickColor.new("Pearl")
			r1.Material = Enum.Material.SmoothPlastic
			cr.DriveSeat.Indicator.Value = false
			cr.DriveSeat.RI.Value = false
			if not headlt then
			b2.BrickColor = BrickColor.new("Bright red")
			b2.Material = Enum.Material.SmoothPlastic
			else
			b2.BrickColor = BrickColor.new("Bright red")
			b2.Material = Enum.Material.SmoothPlastic
			end
			wait(1/3)
			if not right then 
				r1.Material = Enum.Material.Neon
				r1.BrickColor = BrickColor.new("Pearl")
			end
		end end
	elseif input.KeyCode == Enum.KeyCode.L then if input.UserInputState == Enum.UserInputState.Begin then
		if headlt and not highlt then
			highlt = true
		elseif headlt and highlt then
			headlt = false
			highlt = false
		elseif not headlt then
			headlt = true
		end
		if highlt then
			hi.BrickColor = BrickColor.new("Pearl")
			hi.Material = Enum.Material.Neon
			lwww.SpotLight.Enabled = true
			rb.BrickColor = BrickColor.new("Really red")
			rb.Material = Enum.Material.Neon
		elseif not highlt then
			hi.BrickColor = BrickColor.new("Pearl")
			hi.Material = Enum.Material.SmoothPlastic
			lwww.SpotLight.Enabled = false
			if not headlt then
			rb.BrickColor = BrickColor.new("Bright red")
			rb.Material = Enum.Material.SmoothPlastic
			elseif not headlt or highlt then
				rb.BrickColor = BrickColor.new("Bright red")
				rb.Material = Enum.Material.SmoothPlastic
			end
		end
		if headlt then
			lw.BrickColor = BrickColor.new("Pearl")
			lw.Material = Enum.Material.Neon
			lww.SpotLight.Enabled = true
			rb.BrickColor = BrickColor.new("Really red")
			rb.Material = Enum.Material.Neon
			if not highlt then
			lw.BrickColor = BrickColor.new("Pearl")
			rb.BrickColor = BrickColor.new("Really red")
			rb.Material = Enum.Material.Neon
			else
			end
		elseif not headlt then
			lw.BrickColor = BrickColor.new("Pearl")
			lw.Material = Enum.Material.SmoothPlastic
			lww.SpotLight.Enabled = false
			if not brake then
			end
		end end
	end
end

is.InputBegan:connect(DealWithInput)
is.InputChanged:connect(DealWithInput)
is.InputEnded:connect(DealWithInput)

gr.Changed:connect(function()
	if gr.Value == -1 then
		rv.Material = Enum.Material.Neon
	else
		rv.Material = Enum.Material.SmoothPlastic
	end
end)