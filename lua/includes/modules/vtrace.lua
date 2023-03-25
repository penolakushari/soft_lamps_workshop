
AddCSLuaFile()
module("vtrace", package.seeall)

if SERVER then
	util.AddNetworkString("InitializeClient")
	util.AddNetworkString("InitializeServer")
	util.AddNetworkString("FinalizeServer")
end
if CLIENT then
	VTraceUseRenderHook = false
	VTraceShouldOverrideCalcView = false
end

VTracePoolTable = {}

local function RunAgain()
	if table.Count(VTracePoolTable) > 0 then
		local NewCallbackID = table.GetFirstKey(VTracePoolTable)
		Initialize(VTracePoolTable[NewCallbackID].ClientData)
	end
end

local function PerformCallback(CallbackID, PixelsTable)
	if !CallbackID or !PixelsTable then return false end
	local Callback = VTracePoolTable[CallbackID].Callback
	if !Callback then return false end
	Callback(PixelsTable)
	VTracePoolTable[CallbackID] = nil
end

local MaxPixelsCount = 4000
if SERVER then
	net.Receive("FinalizeServer", function()
		local Scanner = ents.FindByClass("vtrace_scanner")[1]

		local ExpectingCallback = net.ReadBool()

		if ExpectingCallback then
			local CallbackID = net.ReadString()
			local PixelsTableLength = math.min(net.ReadUInt(32), MaxPixelsCount)

			local PixelsTable = {}
			for i=1, PixelsTableLength do
				PixelsTable[i] = {}
				PixelsTable[i].Pos = net.ReadVector()
				PixelsTable[i].Col = net.ReadColor()
				PixelsTable[i].Dir = net.ReadNormal()
			end

			PerformCallback(CallbackID, PixelsTable)

			if VTracePoolTable[CallbackID] then
				VTracePoolTable[CallbackID] = nil
			end
		end

		Scanner.Slave:SetViewEntity(Scanner.Slave)

		--Clean scanner
		Scanner.Slave = nil
		Scanner.Busy = false

		RunAgain()
	end)
end

local function FinalizeServer(SequentialPixelsTable, CallbackID)
	if SequentialPixelsTable and CallbackID then
		net.Start("FinalizeServer", false)
			net.WriteBool(true)
			net.WriteString(CallbackID)
			net.WriteUInt(math.min(table.Count(SequentialPixelsTable), MaxPixelsCount), 32)
			local PixelCount = 1
			for _, PixTable in pairs(SequentialPixelsTable) do
				if PixelCount <= MaxPixelsCount then
					net.WriteVector(PixTable.PixelPosition)
					net.WriteColor(PixTable.PixelColor)
					net.WriteNormal(PixTable.PixelDirection)
				end
			end
		net.SendToServer()
	else
		net.Start("FinalizeServer", false)
			net.WriteBool(false)
		net.SendToServer()
	end
end

local function FinalizeClient()
	local Scanner = ents.FindByClass("vtrace_scanner")[1]
	local PixelsTable = Scanner.PixelsTable

	--Remove pixels that weren't hit and remove the hit value for those that were
	for PixString, PixTable in pairs(PixelsTable) do
		if !PixelsTable[PixString].Hit then
			PixelsTable[PixString] = nil
		else
			PixelsTable[PixString].Hit = nil
		end
	end

	--Make the pixelstable sequential
	local SequentialPixelsTable = {}
	for PixString, PixTable in pairs(PixelsTable) do
		table.insert(SequentialPixelsTable, PixTable)
	end

	local RanByClient = Scanner.RanByClient
	local CallbackID = Scanner.CallbackID

	if RanByClient then
		PerformCallback(CallbackID, PixelsTable)

		FinalizeServer()

		RunAgain()
	else
		FinalizeServer(SequentialPixelsTable, CallbackID)
	end

	VTraceShouldOverrideCalcView = false

	--Reset slave
	local Slave = LocalPlayer()
	Slave:SetNoDraw(false)
	Slave:SetFOV(0, 0)

	--Clean scanner's data
	Scanner.StartPos = nil
	Scanner.ForwardAngle = nil
	Scanner.FOV = nil
	Scanner.FarZ = nil
	Scanner.Accuracy = nil
	Scanner.PixelsTable = nil
	Scanner.RanByClient = nil
	Scanner.CallbackID = nil
end

local function IsPixelGradient(R, G, B)
	if R < 150 then return true else return false end
end

local function IsPixelNotWhite(R)
	if R == 255 then return false else return true end
end

-- local function AllPixelsHit(PixelsTable)
-- 	for PixString, PixTable in pairs(PixelsTable) do
-- 		if !PixTable.Hit then return false end
-- 	end
-- 	return true
-- end


local function CalculatePositions()
	--Define needed values
	local Scanner = ents.FindByClass("vtrace_scanner")[1]
	local PixelsTable = Scanner.PixelsTable

	LocalPlayer():SetFOV(Scanner.FOV, 0)

	local ScannerAng = Scanner:GetAngles()
	local ScannerPos = Scanner:GetPos()
	local ScannerNormal = ScannerAng:Forward()
	local AccuracyTolerance = math.max(Scanner.AccuracyTolerance, 0.01)
	local NearZ = Scanner.NearZ
	local FarZ = Scanner.FarZ
	local PositionOffset = Scanner.PositionOffset


	local ZPlaneSize = 3000
	local ZPlaneColor = Color(255, 255, 255, 255)
	local ZPlaneAng = Angle(ScannerAng.p-90, ScannerAng.y, ScannerAng.r)
	local ZPlaneOffset = ScannerNormal*math.max(NearZ, 20)

	local Count = 0

	render.RenderView()
	render.Clear(0, 0, 0, 255, false, true)

	--Define new zplane pos, render depth with white zplane
	local ZPlanePos = ScannerPos + ScannerNormal*AccuracyTolerance + ZPlaneOffset
	local PixelsToHit = table.Count(PixelsTable)
	while ZPlanePos:Distance(ScannerPos) < FarZ and PixelsToHit > 0 do


		render.RenderView()
		render.Clear(0, 0, 0, 0, false, true)
		cam.Start3D()
			cam.Start3D2D(ZPlanePos, ZPlaneAng, 10)
				surface.SetDrawColor(ZPlaneColor)
				surface.DrawRect(-ZPlaneSize, -ZPlaneSize, 2*ZPlaneSize, 2*ZPlaneSize)
			cam.End3D2D()
		cam.End3D()

		--Capture all pixels and check if they're hit (black)
		if Count > 2 then
			render.CapturePixels()
			for PixString, v in pairs(PixelsTable) do
				if !PixelsTable[PixString].Hit then
					local ExplodedPixString = string.Explode("/", PixString)
					local X, Y = ExplodedPixString[1], ExplodedPixString[2]
					--local Hit = IsPixelNotWhite(render.ReadPixel(X, Y))
					local Hit = IsPixelGradient(render.ReadPixel(X, Y))
					if Hit then
						local Direction = PixelsTable[PixString].PixelDirection
						local Position = util.IntersectRayWithPlane(ScannerPos, Direction, ZPlanePos, ScannerNormal)
						local PositionWithOffset = Position + Direction*PositionOffset
						if PositionWithOffset then
							PixelsTable[PixString].Hit = true
							PixelsTable[PixString].PixelPosition = PositionWithOffset
						end
						PixelsToHit = PixelsToHit - 1
					else
						PixelsTable[PixString].Hit = false
					end
				end
			end
		else
			Count = Count+1
		end

		ZPlanePos = ZPlanePos + ScannerNormal*AccuracyTolerance

		render.Spin() -- Let the client see what's going on

	end

	FinalizeClient()
end

local function CalculateColorsAndDirections()
	if VTraceUseRenderHook then
		local Scanner = ents.FindByClass("vtrace_scanner")[1]
		local PixelsTable = Scanner.PixelsTable

		LocalPlayer():SetFOV(Scanner.FOV, 0)

		render.CapturePixels()
		for PixString, v in pairs(PixelsTable) do
			local ExplodedPixString = string.Explode("/", PixString)
			local X, Y = ExplodedPixString[1], ExplodedPixString[2]
			local R, G, B = render.ReadPixel(X, Y)
			PixelsTable[PixString].PixelColor = Color(R, G, B)
			PixelsTable[PixString].PixelDirection = gui.ScreenToVector(X, Y)
		end
		--Stop using the hook
		VTraceUseRenderHook = false
		--Proceed to next steps when done
		CalculatePositions()
	end
end
hook.Add("PreDrawEffects", "CalculateColorsAndDirections", CalculateColorsAndDirections)


local function VTraceOverrideCalcView()
	if VTraceShouldOverrideCalcView then

		local ViewOverride = {}
		local Scanner = ents.FindByClass("vtrace_scanner")[1]

		ViewOverride.fov = Scanner.FOV
		ViewOverride.zfar = Scanner.FarZ + 1
		ViewOverride.znear = Scanner.NearZ

		return ViewOverride
	end
end
hook.Add("CalcView", "VTraceOverrideCalcView", VTraceOverrideCalcView)

local function CreatePixelsTable(ScanRadius, ScanInterval, ScanJitter, EntireScreen)
	--Build the pixelstable using scanradius and scanresolution
	local PixelsTable = {}
	local Grid = {}
	local MidX = ScrW()/2
	local MidY = ScrH()/2
	PixelsTable[tostring(MidX+math.random(-ScanJitter, ScanJitter)).."/"..tostring(MidY+math.random(-ScanJitter, ScanJitter))] = {}
	Grid[MidX] = MidY
	if ScanRadius and ScanInterval and ScanRadius > ScanInterval then
		local ScreenRadiusRange = math.min(ScrW()/2, ScrH()/2)
		if !EntireScreen then
			ScanRadius = math.min(ScanRadius, ScreenRadiusRange)
		end
		ScanInterval = ScanInterval + 1
		local MinXBorder, MaxXBorder = MidX - ScanRadius, MidX + ScanRadius
		local MinYBorder, MaxYBorder = MidY - ScanRadius, MidY + ScanRadius
		--Extend to minxborder
		local LastP = MidX
		for P=MidX, MinXBorder, -1 do
			if P+ScanInterval == LastP then
				PixelsTable[tostring(P+math.random(-ScanJitter, ScanJitter)).."/"..tostring(MidY+math.random(-ScanJitter, ScanJitter))] = {}
				Grid[P] = MidY
				LastP = P
			end
		end
		--Extend to maxxborder
		LastP = MidX
		for P=MidX, MaxXBorder do
			if P-ScanInterval == LastP then
				PixelsTable[tostring(P+math.random(-ScanJitter, ScanJitter)).."/"..tostring(MidY+math.random(-ScanJitter, ScanJitter))] = {}
				Grid[P] = MidY
				LastP = P
			end
		end
		for X, Y in pairs(Grid) do
			--Extend to minyborder
			LastP = MidY
			for P=MidY, MinYBorder, -1 do
				if P+ScanInterval == LastP then
					PixelsTable[tostring(X+math.random(-ScanJitter, ScanJitter)).."/"..tostring(P+math.random(-ScanJitter, ScanJitter))] = {}
					Grid[X] = P
					LastP = P
				end
			end
			--Extend to maxyborder
			LastP = MidY
			for P=MidY, MaxYBorder do
				if P-ScanInterval == LastP then
					PixelsTable[tostring(X+math.random(-ScanJitter, ScanJitter)).."/"..tostring(P+math.random(-ScanJitter, ScanJitter))] = {}
					Grid[X] = P
					LastP = P
				end
			end
		end
	end

	--Clean pixels that are over the screen borders
	for PixString, _ in pairs(PixelsTable) do
		local ExplodedPixString = string.Explode("/", PixString)
		local X, Y = tonumber(ExplodedPixString[1]), tonumber(ExplodedPixString[2])
		if X < 0 or X > ScrW() or Y < 0 or Y > ScrH() then
			PixelsTable[PixString] = nil
		end
	end

	return PixelsTable
end

local function InitializeClient(ClientData)

	local StartPos = ClientData.StartPos
	local ForwardAngle = ClientData.ForwardAngle
	local FOV = ClientData.FOV
	local NearZ = ClientData.NearZ
	local FarZ = ClientData.FarZ
	local AccuracyTolerance = ClientData.AccuracyTolerance
	local ScanRadius = ClientData.ScanRadius
	local ScanInterval = ClientData.ScanInterval
	local ScanJitter = ClientData.ScanJitter
	local PositionOffset = ClientData.PositionOffset
	local EntireScreen = ClientData.EntireScreen
	local RanByClient = ClientData.RanByClient
	local CallbackID = ClientData.CallbackID
	local PixelsTable = CreatePixelsTable(ScanRadius, ScanInterval, ScanJitter, EntireScreen)

	--Find scanner and set view
	local Scanner = ents.FindByClass("vtrace_scanner")[1]
	local Slave = LocalPlayer()

	Scanner:SetPos(StartPos)
	Scanner:SetAngles(ForwardAngle)
	Slave:SetFOV(FOV, 0)
	Slave:SetNoDraw(true)

	--Mount data on the scanner for easy access
	Scanner.StartPos = StartPos
	Scanner.ForwardAngle = ForwardAngle
	Scanner.FOV = FOV
	Scanner.NearZ = NearZ
	Scanner.FarZ = FarZ
	Scanner.AccuracyTolerance = AccuracyTolerance
	Scanner.PositionOffset = PositionOffset
	Scanner.PixelsTable = PixelsTable
	Scanner.CallbackID = CallbackID
	Scanner.RanByClient = RanByClient

	--Prepare initial data with hook
	VTraceUseRenderHook = true
	VTraceShouldOverrideCalcView = true
end

net.Receive("InitializeClient", function()
	local ClientData = net.ReadTable()
	InitializeClient(ClientData)
end)


function StartVTrace(ClientData)
	local Scanner = ents.FindByClass("vtrace_scanner")[1]
	Scanner.Busy = true
	local Slave = ClientData.Slave
	Scanner.Slave = Slave
	Slave:SetViewEntity(Scanner)

	net.Start("InitializeClient")
		net.WriteTable(ClientData)
	net.Send(Slave)
end

local function InitializeServer(ClientData)
	local Scanner = ents.FindByClass("vtrace_scanner")[1]
	if !Scanner.Busy then
		Scanner.Busy = true
		StartVTrace(ClientData)
	end
end

if SERVER then
	net.Receive("InitializeServer", function()
		local ClientData = net.ReadTable()
		InitializeServer(ClientData)
	end)
end

function Initialize(ClientData)
	if CLIENT then
		net.Start("InitializeServer")
			net.WriteTable(ClientData)
		net.SendToServer()
	else
		InitializeServer(ClientData)
	end
end

local CID = 0
function DoTrace(TT, Callback)

	local P = Entity(1)

	local StartPos=TT.StartPos or P:GetPos()
	local ForwardAngle=TT.ForwardAngle or P:EyeAngles()
	local FOV=TT.FOV or 90
	local NearZ=TT.NearZ or 1
	local FarZ=TT.FarZ or 1000
	local AccuracyTolerance=TT.AccuracyTolerance or 1
	local ScanRadius=TT.ScanRadius or 100
	local ScanInterval=TT.ScanInterval or 10
	local ScanJitter=TT.ScanJitter or 0
	local PositionOffset=TT.PositionOffset or 0
	local Slave=TT.Slave or P
	local EntireScreen = TT.EntireScreen or false

	local Scanner = ents.FindByClass("vtrace_scanner")[1]

	if !Scanner then Scanner = ents.Create("vtrace_scanner") end

	local RanByClient = CLIENT

	--Sort out callback
	local CallbackID
	CID = CID+1
	if RanByClient then
		CallbackID = "C-CID-"..CID
	else
		CallbackID = "S-CID-"..CID
	end

	local ClientData = {
							StartPos=StartPos,
							ForwardAngle=ForwardAngle,
							FOV=FOV,
							NearZ=NearZ,
							FarZ=FarZ,
							AccuracyTolerance=AccuracyTolerance,
							ScanRadius=ScanRadius,
							ScanInterval=ScanInterval,
							ScanJitter=ScanJitter,
							PositionOffset=PositionOffset,
							Slave=Slave,
							EntireScreen=EntireScreen,
							RanByClient=RanByClient,
							CallbackID=CallbackID
						}

	VTracePoolTable[CallbackID] = {ClientData = ClientData, Callback = Callback}

	Initialize(ClientData)
end

hook.Add("PlayerInitialSpawn", "CreateScanner", function(pl)
	if SERVER then
		hook.Add("SetupMove", "ScannerInit" .. pl:UserID(), function(ply, _, cmd)
			if pl == ply and not cmd:IsForced() then
				local Scanner = ents.Create("vtrace_scanner")
				Scanner:SetPos(pl:GetPos())
				Scanner.Busy = false
				Scanner:Spawn()
				hook.Remove("SetupMove", "ScannerInit" .. pl:UserID())
			end
		end)
	end
end)

hook.Add("PostCleanupMap", "CreateScanner", function()
	if SERVER then
		local Scanner = ents.Create("vtrace_scanner")
		local _, pl = next(player.GetAll())
		Scanner:SetPos(pl:GetPos())
		Scanner.Busy = false
		Scanner:Spawn()
	end
end)

----Extras----

function GetSeperations(PixelsTable, MaxSeperation)
	if !isnumber(MaxSeperation) then return PixelsTable end
	for CurPix, CurPixTable in pairs(PixelsTable) do
		local CurPos = CurPixTable.Pos
		local MinSeperation = MaxSeperation
		for RelPix, RelPixTable in pairs(PixelsTable) do
			if CurPix != RelPix then
				local RelSeperation = RelPixTable.Pos:Distance(CurPos)
				if RelSeperation < MinSeperation then MinSeperation = RelSeperation end
			end
		end
		PixelsTable[CurPix].Seperation = MinSeperation
	end
	return PixelsTable
end
