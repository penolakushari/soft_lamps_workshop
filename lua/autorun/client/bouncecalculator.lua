require("vtrace")

SoftLampsBounceTable = {}

local MinLight = 5

concommand.Add("lightbounce_calculate", function(Ply, Cmd, Args)
	local flashlightdepthres = GetConVar("r_flashlightdepthres"):GetInt()
	--if flashlightdepthres != 1024 then
		--print("r_flashlightdepthres is "..flashlightdepthres.." ! Set it to 1024 ! Don't forget to turn off all lights before doing so!")
		--return
	--end

	if Ply:GetActiveWeapon():GetClass() == "gmod_camera" then
		print("Camera is equipped! Equip something that doesn't override view!")
		return
	end

	local draweffectrings = GetConVar("cl_draweffectrings"):GetInt()
	if draweffectrings == 1 then
		print("cl_draweffectrings is "..draweffectrings.." ! Set it to 0!")
		return
	end

	if tonumber(Args[1]) and tonumber(Args[2]) then
		for _, SoftLamp in pairs(ents.FindByClass("gmod_softlamp")) do
			if SoftLamp:GetOn() then

				SoftLampsBounceTable[SoftLamp] = {}

				--VecTable = SoftLamp:GetVecs(true, true)

				--PrintTable(VecTable)

				--for PT, PTTable in pairs(VecTable.positions) do
					--relpos = PTTable.vec
					--relang = PTTable.ang
					local TraceTable = 	{
											Slave = Ply,
											StartPos = SoftLamp:LocalToWorld(SoftLamp:GetLightOffset()),
											ForwardAngle = Angle(SoftLamp:GetAngles().p, SoftLamp:GetAngles().y, 0),
											FOV = SoftLamp:GetLightFOV(),
											NearZ = SoftLamp:GetNearZ(),
											FarZ = SoftLamp:GetFarZ(),
											AccuracyTolerance = tonumber(Args[1]),
											ScanRadius = 1000,
											ScanInterval = tonumber(Args[2]),
											ScanJitter = 0,
											PositionOffset = -tonumber(Args[1])*3
										}

					vtrace.DoTrace(TraceTable, function(BounceData)
						
						SoftLamp:SetNoDraw(false)

						for Pix, PixTable in pairs(BounceData) do
							
							local Col = PixTable.PixelColor
							local Pos = PixTable.PixelPosition
							local Dir = PixTable.PixelDirection

							BounceData[Pix].PixelDirection = nil
							BounceData[Pix].PixelColor = nil
							BounceData[Pix].PixelPosition = nil

							if Col.r < MinLight and Col.g < MinLight and Col.b < MinLight then -- If color is too dark (below MinLight) then remove it
								BounceData[Pix] = nil
							else
								BounceData[Pix].Col = Col
								BounceData[Pix].Pos = Pos
								BounceData[Pix].Dir = Dir
							end
						end

						table.Add(SoftLampsBounceTable[SoftLamp], BounceData)
						
						local Count = 0
						for Pix, PixTable in pairs(BounceData) do
							Count = Count + 1
						end

						print("Calculated "..Count.." lights for lamp:", SoftLamp)--, "Sublamp: "..PT)

					end)
				--end
			end
		end
	else
		print("lightbounce_calculate <Accuracy> <Interval>")
	end
end)

concommand.Add("lightbounce_calculate_help", function(Ply, Cmd, Args)
	print("The lightbounce_calculate command will calculate light bounce information for every lamp that is turned on.")
	print("Before starting, make sure to darken your enviornment as much as possible, and only keep your target lamps on.")
	print("The command has the following arguements: lightbounce_calculate <Accuracy> <Interval>")
end)

concommand.Add("lightbounce_clearcalculations", function(Ply, Cmd, Args)
	SoftLampsBounceTable = {}
end)

concommand.Add("lightbounce_delete_points", function(Ply, Cmd, Args)
	if tonumber(Args[1]) and tonumber(Args[2]) then
		local DelRad = tonumber(Args[1])
		local DelTol = tonumber(Args[2])
		local PlyPos = Ply:GetPos()
		local count = 0
		for k, lamp in pairs(SoftLampsBounceTable) do
			for Pix, PixTable in pairs(lamp) do
				if PlyPos:Distance(PixTable.Pos) <= DelRad then
					if math.random(0, DelTol) == 0 then
						lamp[Pix] = nil
						count = count + 1
					end
				end
			end
		end
		if (count > 0) then
			print("Deleted "..count.." light points!")
		end
	else
		print("lightbounce_delete_points <Delete Radius> <Delete Tolerance>")
	end
end)

---- LightSpray Extras ----
concommand.Add("lightspray_calculate", function(Ply, Cmd, Args)

	local draweffectrings = GetConVar("cl_draweffectrings"):GetInt()
	if draweffectrings == 1 then
		print("cl_draweffectrings is "..draweffectrings.." ! Set it to 0!")
		return
	end

	if tonumber(Args[1]) and tonumber(Args[2]) and tonumber(Args[3]) then

		local ViewEnt = GetViewEntity()
		ViewEnt:SetNoDraw(true)
		Ply:SetNoDraw(true)

		local TraceTable = 	{
								Slave = Ply,
								StartPos = Ply:EyePos(),
								ForwardAngle = Ply:EyeAngles(),
								FOV = Ply:GetFOV(),
								NearZ = 1,
								FarZ = tonumber(Args[3]),
								AccuracyTolerance = tonumber(Args[1]),
								ScanRadius = math.max(ScrW(), ScrH()),
								ScanInterval = tonumber(Args[2]),
								ScanJitter = 0,
								PositionOffset = -tonumber(Args[1])*3,
								EntireScreen = true
							}

		vtrace.DoTrace(TraceTable, function(BounceData)

			ViewEnt:SetNoDraw(false)
			Ply:SetNoDraw(false)

			for Pix, PixTable in pairs(BounceData) do
				
				local Col = PixTable.PixelColor
				local Pos = PixTable.PixelPosition

				BounceData[Pix].PixelDirection = nil
				BounceData[Pix].PixelColor = nil
				BounceData[Pix].PixelPosition = nil

				if Col.r < MinLight and Col.g < MinLight and Col.b < MinLight then -- If color is too dark (below MinLight) then remove it
					BounceData[Pix] = nil
				else
					BounceData[Pix].Col = Col
					BounceData[Pix].Pos = Pos
				end
			end

			SoftLampsBounceTable[table.Count(SoftLampsBounceTable)+1] = BounceData
			
			local Count = 0
			for Pix, PixTable in pairs(BounceData) do
				Count = Count + 1
			end
			print("Calculated "..Count.." lights for light spray!")
		end)
	else
		print("lightspray_calculate <Accuracy> <Interval> <Distance>")
	end
end)

concommand.Add("lightspray_calculate_advanced", function(Ply, Cmd, Args)
	
	local draweffectrings = GetConVar("cl_draweffectrings"):GetInt()
	if draweffectrings == 1 then
		print("cl_draweffectrings is "..draweffectrings.." ! Set it to 0!")
		return
	end

	if tonumber(Args[1]) and tonumber(Args[2]) and tonumber(Args[3]) then

		local ViewEnt = GetViewEntity()
		ViewEnt:SetNoDraw(true)
		Ply:SetNoDraw(true)

		local TraceTable = 	{
								Slave = Ply,
								StartPos = Ply:EyePos(),
								ForwardAngle = Ply:EyeAngles(),
								FOV = tonumber(Args[1]),
								NearZ = tonumber(Args[7]),
								FarZ = tonumber(Args[8]),
								AccuracyTolerance = tonumber(Args[2]),
								ScanRadius = tonumber(Args[3]),
								ScanInterval = tonumber(Args[4]),
								ScanJitter = tonumber(Args[5]),
								PositionOffset = tonumber(Args[6]),
							}

		vtrace.DoTrace(TraceTable, function(BounceData)

			ViewEnt:SetNoDraw(false)
			Ply:SetNoDraw(false)

			for Pix, PixTable in pairs(BounceData) do
				
				local Col = PixTable.PixelColor
				local Pos = PixTable.PixelPosition

				BounceData[Pix].PixelDirection = nil
				BounceData[Pix].PixelColor = nil
				BounceData[Pix].PixelPosition = nil

				if Col.r < MinLight and Col.g < MinLight and Col.b < MinLight then -- If color is too dark (below MinLight) then remove it
					BounceData[Pix] = nil
				else
					BounceData[Pix].Col = Col
					BounceData[Pix].Pos = Pos
				end
			end

			SoftLampsBounceTable[table.Count(SoftLampsBounceTable)+1] = BounceData
			
			local Count = 0
			for Pix, PixTable in pairs(BounceData) do
				Count = Count + 1
			end
			print("Calculated "..Count.." lights for light spray!")
		end)
	else
		print("lightspray_calculate <FOV> <Accuracy> <Scan Radius> <Interval> <Scan Jitter> <Position Offset> <Start Distance> <End Distance>")
	end
end)

concommand.Add("reflection_fidelity_helper",function(Ply, Cmd, Args)
	local F = tonumber(Args[1])
	if F then
		if F > 1 || F < 0 then
			F = math.Clamp(F, 0, 1)
			print("Fidelity must be within 0-1 range. Clamping.")
			print("")
		end
		
		local Interval = math.Round(25 - 25*F, 0)
		local Boost = 0.5 + 40*F
		local Exponent = 10 + 49990*(F^2)

		print("Recommended Settings for Perfect Mirror Reflection Passes:")
		print("Scan Interval: "..Interval)
		print("Phong Boost: "..Boost)
		print("Phong Exponent: "..Exponent)

	else
		print("reflection_fideltiy_helper <0-1> recommends settings for mirrorized reflection passes.")
	end
end)

---- Debug Extras ----

local ShowDebug = false

concommand.Add("lightbounce_debug",function(Ply, Cmd, Args)
	if (tonumber(Args[1]) == 1) then
		ShowDebug = true
		print("LightBounce debugging enabled!")
	else
		ShowDebug = false
		print("LightBounce debugging disabled!")
	end
end)

local spriteSize = 15
local Mat = Material("vgui/circle")
hook.Add("HUDPaint", "Show Debug", function()
	if ShowDebug then

		cam.Start3D()

			for SoftLamp, BounceData in pairs (SoftLampsBounceTable) do
				for Pix, PixTable in pairs (BounceData) do
					render.SetMaterial(Mat)
					render.DrawSprite(PixTable.Pos, spriteSize, spriteSize, PixTable.Col)
				end
			end

		cam.End3D()
	end
end)

concommand.Add("lightbounce_debug_size",function(Ply, Cmd, Args)
	if isnumber(Args[1]) then
		spriteSize = Args[1]
	end
end)