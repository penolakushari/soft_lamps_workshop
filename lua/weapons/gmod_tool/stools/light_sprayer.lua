//Light Sprayer by Vioxtar

AddCSLuaFile()
require("vtrace")

TOOL.Category = "Construction"
TOOL.Name = "Light Sprayer"

if CLIENT then
	language.Add( "Tool.light_sprayer.name", "Light Sprayer" )
	language.Add( "Tool.light_sprayer.desc", "Sprays scanned light!" )
	language.Add( "Tool.light_sprayer.0",    "'Left Click' to spray, 'Right Click' to delete dispenses, 'Reload' to display scan grid." )
end

--Tool functions

local MinLight = 5

function TOOL:LeftClick(Trace)
		
	local Ply = self:GetOwner()
	// ("lightspray_calculate <FOV> <Accuracy> <Scan Radius> <Interval> <Scan Jitter> <Position Offset> <Start Distance> <End Distance>")
	if SERVER then
		Ply:ConCommand("lightspray_calculate_advanced ".." "..	self:GetClientInfo("scan_fov").." "..
																self:GetClientInfo("scan_accuracy_tolerance").." "..
																self:GetClientInfo("scan_radius").." "..
																self:GetClientInfo("scan_interval").." "..
																self:GetClientInfo("scan_jitter").." "..
																self:GetClientInfo("scan_position_offset").." "..
																self:GetClientInfo("scan_nearz").." "..
																self:GetClientInfo("scan_farz")
															)
	end
end

function TOOL:RightClick(Trace)
	if SERVER then
		self:GetOwner():ConCommand("lightbounce_delete_points ".." "..self:GetClientInfo("del_radius").." "..self:GetClientInfo("del_tolerance"))
	end
end

function TOOL:Think()
	if SERVER then
		local Ply = self:GetOwner()
		if Ply:KeyDown(IN_RELOAD) then
			local ScanFOV = math.Clamp(self:GetClientNumber("scan_fov"), 1, 179)
			Ply:SetFOV(ScanFOV, 0)
		end
		if Ply:KeyReleased(IN_RELOAD) then
			Ply:SetFOV(0, 0)
		end
	end
end

local function OverrideCalcViewLS()
	local Ply = LocalPlayer()
	if Ply.ShouldDisplayLSGrid then
		if Ply:GetActiveWeapon().Mode == "light_sprayer" then
			if Ply:KeyDown(IN_RELOAD) then

				local Tool = Ply:GetTool()
				local ViewOverride = {}
				
				ViewOverride.fov = Tool:GetClientNumber("scan_fov")
				ViewOverride.zfar = Tool:GetClientNumber("scan_farz") + 2
				ViewOverride.znear = Tool:GetClientNumber("scan_nearz")


				return ViewOverride

			end
		end
	end
end
hook.Add("CalcView", "OverrideCalcViewLS", OverrideCalcViewLS)


local function DisplayScanGridLS()
	local Ply = LocalPlayer()
	if !Ply.ShouldDisplayLSGrid then return end
	if Ply:GetActiveWeapon().Mode == "light_sprayer" then
		if Ply:KeyDown(IN_RELOAD) then
			local Tool = Ply:GetTool()
			local ScanRadius = Tool:GetClientNumber("scan_radius")
			local ScanInterval = Tool:GetClientNumber("scan_interval")
			local ScanJitter = Tool:GetClientNumber("scan_jitter")
			local R = Tool:GetClientNumber("gridcol_r")
			local G = Tool:GetClientNumber("gridcol_g")
			local B = Tool:GetClientNumber("gridcol_b")
			local A = Tool:GetClientNumber("gridcol_a")
			local GridPixelSize = Tool:GetClientNumber("gridsize")
			local GridCol = Color(R, G, B, A)
			local PixelsTable = {}
			surface.SetDrawColor(GridCol)
			local MidX = ScrW()/2
			local MidY = ScrH()/2
			surface.DrawRect(MidX-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), MidY-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), GridPixelSize, GridPixelSize)
			PixelsTable[MidX] = MidY
			if ScanRadius and ScanInterval and ScanRadius > ScanInterval then
				local ScreenRadiusRange = math.min(ScrW()/2, ScrH()/2)
				ScanRadius = math.min(ScanRadius, ScreenRadiusRange)
				ScanInterval = ScanInterval + 1
				local MinXBorder, MaxXBorder = MidX - ScanRadius, MidX + ScanRadius
				local MinYBorder, MaxYBorder = MidY - ScanRadius, MidY + ScanRadius
				--Extend to minxborder
				local LastP = MidX
				for P=MidX, MinXBorder, -1 do
					if P+ScanInterval == LastP then
						surface.DrawRect(P-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), MidY-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), GridPixelSize, GridPixelSize)
						PixelsTable[P] = MidY
						LastP = P
					end
				end
				--Extend to maxxborder
				LastP = MidX
				for P=MidX, MaxXBorder do
					if P-ScanInterval == LastP then
						surface.DrawRect(P-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), MidY-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), GridPixelSize, GridPixelSize)
						PixelsTable[P] = MidY
						LastP = P
					end
				end
				for X, Y in pairs(PixelsTable) do
					--Extend to minyborder
					LastP = MidY
					for P=MidY, MinYBorder, -1 do
						if P+ScanInterval == LastP then
							surface.DrawRect(X-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), P-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), GridPixelSize, GridPixelSize)
							LastP = P
						end
					end
					--Extend to maxyborder
					LastP = MidY
					for P=MidY, MaxYBorder do
						if P-ScanInterval == LastP then
							surface.DrawRect(X-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), P-GridPixelSize/2+math.random(-ScanJitter, ScanJitter), GridPixelSize, GridPixelSize)
							LastP = P
						end
					end
				end
			end
		end
	end
end
hook.Add("HUDPaint", "DisplayScanGridLS", DisplayScanGridLS)

local PlaneSize = 3000
local PlaneColor = Color(0, 0, 0, 255)
local function DisplayDistancePlaneLS()
	local Ply = LocalPlayer()
	if !Ply.ShouldDisplayLSGrid then return end
	if Ply:GetActiveWeapon().Mode == "light_sprayer" then
		if Ply:KeyDown(IN_RELOAD) and !Ply:KeyPressed(IN_ATTACK) then
			local Tool = Ply:GetTool()
			local FarZ = Tool:GetClientNumber("scan_farz")
			local EyeAng = EyeAngles()
			local PlaneAng = Angle(EyeAng.p + 90, EyeAng.y, EyeAng.r)
			cam.Start3D()
				cam.Start3D2D(EyePos()+EyeVector()*FarZ, PlaneAng, 10)
					surface.SetDrawColor(PlaneColor)
					surface.DrawRect(-PlaneSize, -PlaneSize, 2*PlaneSize, 2*PlaneSize)
				cam.End3D2D()
			cam.End3D()
		end
	end
end
hook.Add("PreDrawViewModel", "DisplayDistancePlaneLS", DisplayDistancePlaneLS)


if CLIENT then
	local function ResetAllConVars(ply, command, arguments)
		ply:ConCommand("light_sprayer_scan_fov "..tostring(ply:GetFOV()))
		ply:ConCommand("light_sprayer_scan_nearz 1")
		ply:ConCommand("light_sprayer_scan_farz 1000")
		ply:ConCommand("light_sprayer_scan_accuracy_tolerance 1")
		ply:ConCommand("light_sprayer_scan_radius 100")
		ply:ConCommand("light_sprayer_scan_interval 10")
		ply:ConCommand("light_sprayer_scan_jitter 0")
		ply:ConCommand("light_sprayer_scan_position_offset 0")

		ply:ConCommand("light_sprayer_del_radius 100")
		ply:ConCommand("light_sprayer_del_tolerance 100")

		ply:ConCommand("light_sprayer_gridsize 4")
		ply:ConCommand("light_sprayer_gridcol_r 0")
		ply:ConCommand("light_sprayer_gridcol_g 255")
		ply:ConCommand("light_sprayer_gridcol_b 0")
		ply:ConCommand("light_sprayer_gridcol_a 255")
	end
	concommand.Add("light_sprayer_resetallconvars", ResetAllConVars)

	local function ResetScanConVars(ply, command, arguments)
		ply:ConCommand("light_sprayer_scan_fov "..tostring(ply:GetFOV()))
		ply:ConCommand("light_sprayer_scan_nearz 1")
		ply:ConCommand("light_sprayer_scan_farz 1000")
		ply:ConCommand("light_sprayer_scan_accuracy_tolerance 1")
		ply:ConCommand("light_sprayer_scan_radius 100")
		ply:ConCommand("light_sprayer_scan_interval 10")
		ply:ConCommand("light_sprayer_scan_jitter 0")
		ply:ConCommand("light_sprayer_scan_position_offset 0")
	end
	concommand.Add("light_sprayer_resetscanconvars", ResetScanConVars)
end

--Create ClientConVars
TOOL.ClientConVar[ "scan_fov" ] = 90
TOOL.ClientConVar[ "scan_nearz" ] = 1
TOOL.ClientConVar[ "scan_farz" ] = 1000
TOOL.ClientConVar[ "scan_accuracy_tolerance" ] = 1
TOOL.ClientConVar[ "scan_radius" ] = 100
TOOL.ClientConVar[ "scan_interval" ] = 10
TOOL.ClientConVar[ "scan_jitter" ] = 0
TOOL.ClientConVar[ "scan_position_offset" ] = 0

TOOL.ClientConVar[ "del_radius" ] = 100
TOOL.ClientConVar[ "del_tolerance" ] = 100

TOOL.ClientConVar[ "gridsize" ] = 4
TOOL.ClientConVar[ "gridcol_r" ] = 0
TOOL.ClientConVar[ "gridcol_g" ] = 255
TOOL.ClientConVar[ "gridcol_b" ] = 0
TOOL.ClientConVar[ "gridcol_a" ] = 255

--Button, TextBox, Header, Slider
function TOOL.BuildCPanel(CPanel)
	
	LocalPlayer().ShouldDisplayLSGrid = true
	
	CPanel:AddControl( "Header", { Description	= "Sprayer Settings"} )
	CPanel:AddControl( "Button", { Label = "Reset All Settings", Command = "light_sprayer_resetallconvars", Text = "Reset All Settings" } )

	CPanel:AddControl( "Button", { Label = "Show Light Points", Command = "lightbounce_debug 1", Text = "Show Points" } )
	CPanel:AddControl( "Button", { Label = "Hide Light Points", Command = "lightbounce_debug 0", Text = "Show Points" } )

	CPanel:AddControl( "Header", { Description	= "Scan Settings"} )
	CPanel:AddControl( "Slider", { Label = "FOV", Command = "light_sprayer_scan_fov", Type = "Float", Min = 1, Max = 180, Help = false } )
	CPanel:AddControl( "Slider", { Label = "Start Distance", Command = "light_sprayer_scan_nearz", Type = "Float", Min = 1, Max = 10000, Help = false } )
	CPanel:AddControl( "Slider", { Label = "End Distance", Command = "light_sprayer_scan_farz", Type = "Float", Min = 1, Max = 10000, Help = false } )
	CPanel:AddControl( "Slider", { Label = "Accuracy Tolerance", Command = "light_sprayer_scan_accuracy_tolerance", Type = "Float", Min = 1, Max = 100, Help = false } )
	CPanel:AddControl( "Slider", { Label = "Radius", Command = "light_sprayer_scan_radius", Type = "Int", Min = 0, Max = 1500, Help = false } )
	CPanel:AddControl( "Slider", { Label = "Interval", Command = "light_sprayer_scan_interval", Type = "Int", Min = 0, Max = 500, Help = false } )
	CPanel:AddControl( "Slider", { Label = "Jitter", Command = "light_sprayer_scan_jitter", Type = "Int", Min = 0, Max = 500, Help = false } )
	CPanel:AddControl( "Slider", { Label = "Offset", Command = "light_sprayer_scan_position_offset", Type = "Float", Min = -100, Max = 100, Help = false } )
	CPanel:AddControl( "Button", { Label = "Reset Scan Settings", Command = "light_sprayer_resetscanconvars", Text = "Reset Scan Settings" } )

	CPanel:AddControl( "Header", { Description	= "Grid Display Settings"} )
	CPanel:AddControl( "Slider", { Label = "Dot Size", Command = "light_sprayer_gridsize", Type = "Float", Min = 0, Max = 20, Help = false } )
	CPanel:AddControl( "Color", { Label = "Grid Color", Red = "light_sprayer_gridcol_r", Green = "light_sprayer_gridcol_g", Blue = "light_sprayer_gridcol_b", Alpha = "light_sprayer_gridcol_a" } )

	CPanel:AddControl( "Header", { Description	= "Extra Settings"} )
	CPanel:AddControl( "Slider", { Label = "Delete Radius", Command = "light_sprayer_del_radius", Type = "Float", Min = 0, Max = 5000, Help = false } )
	CPanel:AddControl( "Slider", { Label = "Delete Tolerance", Command = "light_sprayer_del_tolerance", Type = "Float", Min = 0, Max = 100, Help = false } )
end