--!strict
-- Pure, side-effect-free economy rules shared by server and client. Kept
-- separate from SwimConfig (data) and PlayerData (state + persistence) so the
-- award ladder can be unit-tested in isolation (see RaceEconomySpec).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwimConfig = require(ReplicatedStorage:WaitForChild("SwimConfig"))

local RaceEconomy = {}

-- Points earned for a race finish. `prevTime` is your PREVIOUS race time (nil on
-- your very first race). You always get `finish`; beating your previous time by
-- enough seconds bumps you up to the highest tier you clear.
function RaceEconomy.pointsForRace(prevTime: number?, thisTime: number): number
	local cfg = SwimConfig.points
	local award = cfg.finish
	if prevTime ~= nil then
		local faster = prevTime - thisTime
		for _, tier in cfg.improveTiers do
			if faster >= tier.faster and tier.award > award then
				award = tier.award
			end
		end
	end
	return award
end

return RaceEconomy
