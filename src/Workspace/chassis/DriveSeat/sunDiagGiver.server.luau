GUI = script.Parent:FindFirstChild("SUNDIAG_V2")

script.Parent.ChildAdded:connect(function(child)
	if child:IsA("Weld") then
		--child.C0 = CFrame.new(-1.4,-1.3,0.2)*CFrame.fromEulerAnglesXYZ(-(math.pi/2),0,0) --// Reposition player
		if child.Part1.Name == "HumanoidRootPart" then
			player = game.Players:GetPlayerFromCharacter(child.Part1.Parent)
			if player and (not player.PlayerGui:FindFirstChild("SUNDIAG_12")) then --// The part after the "and" prevents multiple GUI's to be copied over.
				GUI.CarSeat.Value = script.Parent --// Puts a reference of the seat in this ObjectValue, now you can use this ObjectValue's value to find the car directly.
				GUI:Clone().Parent = player.PlayerGui --// Compact version
			end
		end
	end
end)

script.Parent.ChildRemoved:connect(function(child)
	if child:IsA("Weld") then
		if child.Part1.Name == "HumanoidRootPart" then
			player = game.Players:GetPlayerFromCharacter(child.Part1.Parent)
			if player and player.PlayerGui:FindFirstChild("SUNDIAG_V2") then
				player.PlayerGui:FindFirstChild("SUNDIAG_V2"):Destroy()
			end
		end
	end	
end)

