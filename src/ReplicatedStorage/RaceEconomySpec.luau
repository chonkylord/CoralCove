--!nocheck
-- selene: allow(undefined_variable)
-- TestEZ spec for the points-award ladder. Run with bl_run_tests.
-- describe/it/expect are TestEZ globals injected by the runner, so type-checking
-- and the undefined-global lint are disabled for this file.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaceEconomy = require(ReplicatedStorage:WaitForChild("RaceEconomy"))

return function()
	describe("RaceEconomy.pointsForRace", function()
		it("awards the finish minimum on your first race", function()
			expect(RaceEconomy.pointsForRace(nil, 42)).to.equal(1)
		end)

		it("awards the finish minimum when you get slower", function()
			expect(RaceEconomy.pointsForRace(40, 45)).to.equal(1)
		end)

		it("awards the finish minimum for a tiny improvement (<1s)", function()
			expect(RaceEconomy.pointsForRace(40, 39.5)).to.equal(1)
		end)

		it("awards 2 for beating your time by 1-3s", function()
			expect(RaceEconomy.pointsForRace(40, 39)).to.equal(2)
			expect(RaceEconomy.pointsForRace(40, 37.5)).to.equal(2)
		end)

		it("awards 3 for beating your time by 3-5s", function()
			expect(RaceEconomy.pointsForRace(40, 37)).to.equal(3)
			expect(RaceEconomy.pointsForRace(40, 35.5)).to.equal(3)
		end)

		it("awards 4 for beating your time by 5s or more", function()
			expect(RaceEconomy.pointsForRace(40, 35)).to.equal(4)
			expect(RaceEconomy.pointsForRace(40, 20)).to.equal(4)
		end)
	end)
end
