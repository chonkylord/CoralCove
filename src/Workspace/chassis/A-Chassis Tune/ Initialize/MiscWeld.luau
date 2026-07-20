local MiscWeld = {}

function MakeWeld(x,y,type,s) 
	local W=Instance.new(type) 
	W.Part0=x W.Part1=y 
	W.C0=x.CFrame:inverse()*x.CFrame 
	W.C1=y.CFrame:inverse()*x.CFrame 
	W.Parent=x 
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

car = script.Parent.Parent.Parent


MakeWeld(car.Misc.Spoiler.A.A1,car.DriveSeat,"Motor",.0074).Name="W"
MakeWeld(car.Misc.Spoiler.A.A2,car.Misc.Spoiler.A.A1,"Motor",.015).Name="W"
MakeWeld(car.Misc.Spoiler.A.A3,car.Misc.Spoiler.A.A2,"Motor",.0074).Name="W"
ModelWeld(car.Misc.Spoiler.Base,car.Misc.Spoiler.A.A3)

MakeWeld(car.Misc.Spoiler.B.B1,car.Misc.Spoiler.A.A3,"Motor",.005).Name="W"
MakeWeld(car.Misc.Spoiler.B.B2,car.Misc.Spoiler.B.B1,"Motor",.01).Name="W"
MakeWeld(car.Misc.Spoiler.B.B3,car.Misc.Spoiler.B.B2,"Motor",.005).Name="W"
MakeWeld(car.Misc.Spoiler.B.B,car.Misc.Spoiler.B.B3,"Weld").Name="W"

MakeWeld(car.Misc.Spoiler.C.C1,car.Misc.Spoiler.A.A3,"Motor",.005).Name="W"
MakeWeld(car.Misc.Spoiler.C.C2,car.Misc.Spoiler.C.C1,"Motor",.01).Name="W"
MakeWeld(car.Misc.Spoiler.C.C3,car.Misc.Spoiler.C.C2,"Motor",.005).Name="W"
MakeWeld(car.Misc.Spoiler.C.C,car.Misc.Spoiler.C.C3,"Weld").Name="W"

MakeWeld(car.Misc.Spoiler.D,car.Misc.Spoiler.B.B3,"Motor",.15).Name="W"
ModelWeld(car.Misc.Spoiler.Wing,car.Misc.Spoiler.D)




return MiscWeld