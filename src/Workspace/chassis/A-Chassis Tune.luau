local Tune = {}
	--Misc
	Tune.AutoStart		= true --set to false if using manual ignition plugin
	Tune.AutoFlip		= true
	
	--Wheel Alignment (Dont physically align the wheels, use these values)
	Tune.FCamber		= 0
	Tune.RCamber		= 0
	Tune.FToe			= 0
	Tune.RToe			= 0
	Tune.FCaster		= 0
	Tune.RCaster		= 0
	Tune.StAxisOffset	= 0
	
	--Wheel Stabilizer Gyro
	Tune.FGyroD			= 100
	Tune.FGyroMaxTorque	= Vector3.new(1,0,1)
	Tune.FGyroP			= 0
	Tune.RGyroD			= 100
	Tune.RGyroMaxTorque	= Vector3.new(1,0,1)
	Tune.RGyroP			= 0
	
	--Steering
	Tune.SteerD			= 1000
	Tune.SteerMaxTorque	= 50000
	Tune.SteerP			= 100000
	
	Tune.SteerInner		= 32
	Tune.SteerOuter		= 33
	Tune.SteerSpeed		= .15
	Tune.SteerDecay		= 320					--Speed[SPS] of gradient cutoff
	Tune.MinSteer		= .1
	Tune.MSteerExp		= 1
	
	--Engine [https://www.desmos.com/calculator/mpkd3kxovu]
	Tune.Horsepower		= 250
	Tune.IdleRPM		= 1100
	Tune.PeakRPM		= 9000
	Tune.Redline		= 10000
	Tune.IdleOffset		= 7
	Tune.RevAccel		= 700
	Tune.RevDecay		= 150
	Tune.RevBounce		= 500
	Tune.IdleThrottle	= .01
	Tune.ClutchTol		= 1000	
	
	--Drivetrain
	Tune.TransModes		= {"Semi"}		--{"Auto", "Semi", "Manual"}
	Tune.AutoShiftMode	= "Speed"				--"RPM" , "Speed"
	Tune.AutoUpThresh	= -200
	Tune.AutoDownThresh = 1400
												
	Tune.FDiffSlipThres	= 20					-- 1 - 100%				(Max threshold of applying full lock determined by deviation from avg speed)
	Tune.FDiffLockThres	= 40					-- 0 - 100%				(0 - Bias toward slower wheel, 100 - Bias toward faster wheel)
	Tune.RDiffSlipThres	= 20					-- 1 - 100%
	Tune.RDiffLockThres	= 40					-- 0 - 100%
	Tune.CDiffSlipThres	= 40					-- 1 - 100%				[AWD Only]
	Tune.CDiffLockThres	= 30					-- 0 - 100%				[AWD Only]
	
	Tune.TCSThreshold	= 15
	Tune.TCSGradient	= 20
	Tune.TCSLimit		= .05
	Tune.Config			= "AWD"					--"FWD" , "RWD" , "AWD"
	Tune.FinalDrive		= 4.2
	Tune.Ratios			= {
		--[[Reverse]]	3.333			,
		--[[Neutral]]	0			,
		--[[ 1 ]]		3.90			,
		--[[ 2 ]]		2.45		,
		--[[ 3 ]]		1.81		,
		--[[ 4 ]]	    1.42		,
		--[[ 5 ]]	 1.15 		,
		--[[ 6 ]]     .95  ,
		--[[ 7 ]]     .80 ,  
	}
	Tune.BrakeForce		= 4500
	Tune.PBrakeForce	= 16000
	
	--Controls
	Tune.Peripherals = {
		MSteerWidth				= 67		,			-- 0 - 100% of screen width
		MSteerDZone				= 20		,			-- 0 - 100%
		
		ControlLDZone			= 5			,			-- 0 - 100%
		ControlRDZone			= 5			,			-- 0 - 100%
	}
	
	Tune.Controls = {
		ToggleTCS				= Enum.KeyCode.T					,
		ToggleTransMode			= Enum.KeyCode.M					,
		ToggleMouseDrive		= Enum.KeyCode.R					,
		
		Throttle				= Enum.KeyCode.Up					,
		Brake					= Enum.KeyCode.Down					,
		SteerLeft				= Enum.KeyCode.Left					,
		SteerRight				= Enum.KeyCode.Right				,
		
		Throttle2				= Enum.KeyCode.W					,
		Brake2					= Enum.KeyCode.S					,
		SteerLeft2				= Enum.KeyCode.A					,
		SteerRight2				= Enum.KeyCode.D					,
		
		ShiftUp					= Enum.KeyCode.E					,
		ShiftDown				= Enum.KeyCode.Q					,
		Clutch					= Enum.KeyCode.LeftShift			,
		PBrake					= Enum.KeyCode.P					,
		
		MouseThrottle			= Enum.UserInputType.MouseButton1	,
		MouseBrake				= Enum.UserInputType.MouseButton2	,
		MouseClutch				= Enum.KeyCode.W					,
		MouseShiftUp			= Enum.KeyCode.E					,
		MouseShiftDown			= Enum.KeyCode.Q					,
		MousePBrake				= Enum.KeyCode.LeftShift			,
		
		ContlrThrottle			= Enum.KeyCode.ButtonR2				,
		ContlrBrake				= Enum.KeyCode.ButtonL2				,
		ContlrSteer				= Enum.KeyCode.Thumbstick1			,
		ContlrShiftUp			= Enum.KeyCode.ButtonY				,
		ContlrShiftDown			= Enum.KeyCode.ButtonX				,
		ContlrClutch			= Enum.KeyCode.ButtonR1				,
		ContlrPBrake			= Enum.KeyCode.ButtonL1				,
		ContlrToggleTMode		= Enum.KeyCode.DPadUp				,
		ContlrToggleTCS			= Enum.KeyCode.DPadDown				,
	}
return Tune
