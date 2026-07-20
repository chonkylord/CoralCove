script.Parent = nil
local StarterGui = game:GetService("StarterGui")

for _, coreGuiType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(coreGuiType, false)
	end)
end
