AddCSLuaFile()
require("vectorshapes")

if CLIENT then
	language.Add( "tool.softlamp.name",				"Soft Lamps" )
	language.Add( "tool.softlamp.desc",				"Soft Projected lights" )
	language.Add( "tool.softlamp.0",				"Click anywhere to create a soft lamp. Click on a soft lamp to update it. Right-click on a lamp or soft lamp to copy its settings." )
	language.Add( "tool.softlamp.fov",				"FOV:" )
	language.Add( "tool.softlamp.distance",			"Distance (Far Z):" )
	language.Add( "tool.softlamp.nearz",			"Near Z:" )
	language.Add( "tool.softlamp.brightness",		"Brightness:" )
	language.Add( "tool.softlamp.color",			"Color:" )
	language.Add( "tool.softlamp.toggle",			"Toggle" )
	language.Add( "tool.softlamp.model",			"Model:" )
	language.Add( "tool.softlamp.key",				"Activation Key" )
  
 	language.Add( "tool.softlamp.on",				"Start On (if toggle)" )
 	language.Add( "tool.softlamp.shape",			"Shape:" )
 	language.Add( "tool.softlamp.radius",			"Shape radius:" )
 	language.Add( "tool.softlamp.radius.help",		"The radius of your lamp's light area" )
 	language.Add( "tool.softlamp.layers",			"Shape Layers:" )
 	language.Add( "tool.softlamp.lightcount",		"Lights used:" )
  
	language.Add( "tool.softlamp.ortho_on",			"Enable Orthographic" )
	language.Add( "tool.softlamp.ortho_size",		"Orthographic size:" )
  
	language.Add( "lamptexture.debug",				"Debug White" )
end

TOOL.Category = "Construction"
TOOL.Name = "#tool.softlamp.name"

TOOL.ClientConVar[ "r" ] = "255"
TOOL.ClientConVar[ "g" ] = "255"
TOOL.ClientConVar[ "b" ] = "255"
TOOL.ClientConVar[ "key" ] = "-1"
TOOL.ClientConVar[ "fov" ] = "90"
TOOL.ClientConVar[ "distance" ] = "1024"
TOOL.ClientConVar[ "nearz" ] = "12"
TOOL.ClientConVar[ "brightness" ] = "4"
TOOL.ClientConVar[ "texture" ] = "models/debug/debugwhite"
TOOL.ClientConVar[ "model" ] = "models/lamps/torch.mdl"
TOOL.ClientConVar[ "toggle" ] = "1"
TOOL.ClientConVar[ "on" ] = "1"
TOOL.ClientConVar[ "orthoon" ] = "0"
TOOL.ClientConVar[ "orthosize" ] = "512"

TOOL.ClientConVar[ "shape" ] = next(vectorshapes.GetShapes(), nil) -- first shape found. really doesn't matter.
TOOL.ClientConVar[ "radius" ] = "10"
TOOL.ClientConVar[ "layers" ] = "1"

cleanup.Register( "softlamps" )

function TOOL:LeftClick( trace )

	if ( IsValid( trace.Entity ) && trace.Entity:IsPlayer() ) then return false end
	if ( CLIENT ) then return true end

	local ply = self:GetOwner()
	local pos = trace.HitPos

	local r = math.Clamp( self:GetClientNumber( "r" ), 0, 255 )
	local g = math.Clamp( self:GetClientNumber( "g" ), 0, 255 )
	local b = math.Clamp( self:GetClientNumber( "b" ), 0, 255 )
	local key = self:GetClientNumber( "key" )
	local texture = self:GetClientInfo( "texture" )
	local mdl = self:GetClientInfo( "model" )
	local fov = self:GetClientNumber( "fov" )
	local distance = self:GetClientNumber( "distance" )
	local nearz = self:GetClientNumber( "nearz" )
	local bright = self:GetClientNumber( "brightness" )
	local toggle = self:GetClientNumber( "toggle" ) != 1	-- why is this opposite?
	local on = self:GetClientNumber( "on" ) != 0
	local softradius = self:GetClientNumber( "radius" )
	local softlayers = math.max(math.floor(self:GetClientNumber("layers")), 1)
	local softshape = self:GetClientInfo("shape")
	local orthoon = self:GetClientNumber("orthoon")
	local orthosize = self:GetClientNumber("orthosize")

	if ( !util.IsValidModel( mdl ) ) then return false end
	if ( !util.IsValidProp( mdl ) ) then return false end

	local mat = Material( texture )
	local texture = mat:GetString( "$basetexture" )

	if	( IsValid( trace.Entity ) && trace.Entity:GetClass() == "gmod_softlamp" && trace.Entity:GetPlayer() == ply ) then

		trace.Entity:SetLightColor( Vector(r/255, g/255, b/255) )
		trace.Entity:SetFlashlightTexture( texture )
		trace.Entity:SetLightFOV( fov )
		trace.Entity:SetDistance( distance )
		trace.Entity:SetNearZ(nearz)
		trace.Entity:SetBrightness( bright )
		trace.Entity:SetToggle( !toggle )

		trace.Entity:SetEnableOrthographic(tobool(orthoon))
		trace.Entity:SetOrthoLeft(orthosize)
		trace.Entity:SetOrthoTop(orthosize)
		trace.Entity:SetOrthoRight(orthosize)
		trace.Entity:SetOrthoBottom(orthosize)

		trace.Entity:SetHeavyShape(softshape)
		trace.Entity:SetGameplayLayers(softlayers)
		trace.Entity:SetShapeRadius(softradius)

		numpad.Remove( trace.Entity.NumDown )
		numpad.Remove( trace.Entity.NumUp )

		trace.Entity.NumDown = numpad.OnDown( ply, key, "SoftLampToggle", trace.Entity, 1 )
		trace.Entity.NumUp = numpad.OnUp( ply, key, "SoftLampToggle", trace.Entity, 0 )

		-- For duplicator
		trace.Entity.Texture = texture
		trace.Entity.fov = fov
		trace.Entity.distance = distance
		trace.Entity.nearz = nearz
		trace.Entity.r = r
		trace.Entity.g = g
		trace.Entity.b = b
		trace.Entity.brightness	= bright
		trace.Entity.KeyDown = key

		trace.Entity.OrthoOn = orthoon
		trace.Entity.OrthoSize = orthosize

		trace.Entity.SoftRadius = softradius
		trace.Entity.SoftLayers = softlayers
		trace.Entity.SoftShape = softshape

		return true

	end

	--if ( !self:GetSWEP():CheckLimit( "softlamps" ) ) then return false end

	local lamp = MakeSoftLamp( ply, r, g, b, key, toggle, texture, mdl, fov, distance, nearz, bright, !toggle && on, softshape, softradius, softlayers, { Pos = pos, Angle = Angle( 0, 0, 0 ) }, orthoon, orthosize )

	local CurPos = lamp:GetPos()
	local NearestPoint = lamp:NearestPoint( CurPos - ( trace.HitNormal * 512 ) )
	local LampOffset = CurPos - NearestPoint

	lamp:SetPos( trace.HitPos + LampOffset )

	undo.Create( "SoftLamp" )
		undo.AddEntity( lamp )
		undo.SetPlayer( self:GetOwner() )
	undo.Finish()

	return true

end

function TOOL:Reload( trace )

	if ( CLIENT ) then return true end

	local ply = self:GetOwner()
	local pos = trace.StartPos
	local ang = trace.Normal:Angle()

	local r = math.Clamp( self:GetClientNumber( "r" ), 0, 255 )
	local g = math.Clamp( self:GetClientNumber( "g" ), 0, 255 )
	local b = math.Clamp( self:GetClientNumber( "b" ), 0, 255 )
	local key = self:GetClientNumber( "key" )
	local texture = self:GetClientInfo( "texture" )
	local mdl = self:GetClientInfo( "model" )
	local fov = self:GetClientNumber( "fov" )
	local distance = self:GetClientNumber( "distance" )
	local nearz = self:GetClientNumber( "nearz" )
	local bright = self:GetClientNumber( "brightness" )
	local toggle = self:GetClientNumber( "toggle" ) != 1	-- why is this opposite?
	local on = self:GetClientNumber( "on" ) != 0
	local softradius = self:GetClientNumber( "radius" )
	local softlayers = math.max(math.floor(self:GetClientNumber("layers")), 1)
	local softshape = self:GetClientInfo("shape")
	local orthoon = self:GetClientNumber("orthoon")
	local orthosize = self:GetClientNumber("orthosize")

	if ( !util.IsValidModel( mdl ) ) then return false end
	if ( !util.IsValidProp( mdl ) ) then return false end

	local mat = Material( texture )
	local texture = mat:GetString( "$basetexture" )

	if ( !self:GetSWEP():CheckLimit( "softlamps" ) ) then return false end

	local lamp = MakeSoftLamp( ply, r, g, b, key, toggle, texture, mdl, fov, distance, nearz, bright, !toggle && on, softshape, softradius, softlayers, { Pos = pos, Angle = ang }, orthoon, orthosize )

	undo.Create( "SoftLamp" )
		undo.AddEntity( lamp )
		undo.SetPlayer( self:GetOwner() )
	undo.Finish()

	return true

end

function TOOL:RightClick( trace )
	if !IsValid(trace.Entity) then return false end
	local class = trace.Entity:GetClass()
	if !(class == "gmod_softlamp" or class == "gmod_lamp") then return false end
	if CLIENT then return true end

	local ent = trace.Entity
	local pl = self:GetOwner()

	pl:ConCommand( "softlamp_fov " .. ent:GetLightFOV() )
	pl:ConCommand( "softlamp_distance " .. ent:GetDistance() )
	pl:ConCommand( "softlamp_brightness " .. ent:GetBrightness() )
	pl:ConCommand( "softlamp_texture " .. ent:GetFlashlightTexture() )

	if ( ent:GetToggle() ) then
		pl:ConCommand( "softlamp_toggle 1" )
	else
		pl:ConCommand( "softlamp_toggle 0" )
	end

	local clr = ent:GetColor()
	pl:ConCommand( "softlamp_r " .. clr.r )
	pl:ConCommand( "softlamp_g " .. clr.g )
	pl:ConCommand( "softlamp_b " .. clr.b )

	if class != "gmod_softlamp" then return true end

	pl:ConCommand( "softlamp_nearz " .. ent:GetNearZ() )
	pl:ConCommand( "softlamp_shape " .. ent:GetHeavyShape() )
	pl:ConCommand( "softlamp_radius " .. ent:GetShapeRadius() )
	pl:ConCommand( "softlamp_layers " .. ent:GetGameplayLayers() )

	return true
end

if ( SERVER ) then
	function MakeSoftLamp(pl, r, g, b, KeyDown, toggle, Texture, Model, fov, distance, nearz, brightness, on, SoftShape, SoftRadius, SoftLayers, Data, OrthoOn, OrthoSize)

		--if (IsValid(pl) and !pl:CheckLimit("softlamps")) then return false end

		local lamp = ents.Create("gmod_softlamp")

		if (!IsValid(lamp)) then return end

		lamp:SetModel( Model )
		lamp:SetFlashlightTexture( Texture )
		lamp:SetLightFOV( fov )
		lamp:SetLightColor(Vector(r/255, g/255, b/255))
		lamp:SetDistance( distance )
		lamp:SetNearZ( nearz )
		lamp:SetBrightness( brightness )

		lamp:SetEnableOrthographic(tobool(OrthoOn))
		lamp:SetOrthoLeft(OrthoSize)
		lamp:SetOrthoTop(OrthoSize)
		lamp:SetOrthoRight(OrthoSize)
		lamp:SetOrthoBottom(OrthoSize)

		lamp:SetHeavyShape( SoftShape )
		lamp:SetShapeRadius( SoftRadius )
		lamp:SetGameplayLayers( SoftLayers )
		lamp:SetHeavyLayers( SoftLayers )

		lamp:Switch( on )
		lamp:SetToggle( !toggle )

		duplicator.DoGeneric( lamp, Data )

		lamp:Spawn()

		duplicator.DoGenericPhysics( lamp, pl, Data )

		lamp:SetPlayer( pl )

		if ( IsValid( pl ) ) then
			pl:AddCount( "softlamps", lamp )
			pl:AddCleanup( "softlamps", lamp )
		end

		lamp.NumDown = numpad.OnDown( pl, KeyDown, "SoftLampToggle", lamp, 1 )
		lamp.NumUp = numpad.OnUp( pl, KeyDown, "SoftLampToggle", lamp, 0 )

		lamp.Texture = Texture
		lamp.KeyDown = KeyDown
		lamp.fov = fov
		lamp.distance = distance
		lamp.nearz = nearz
		lamp.r = r
		lamp.g = g
		lamp.b = b
		lamp.brightness	= brightness

		lamp.OrthoOn = OrthoOn
		lamp.OrthoSize = OrthoSize

		lamp.shape = SoftShape
		lamp.radius = SoftRadius
		lamp.layers = SoftLayers

		return lamp
	end
	duplicator.RegisterEntityClass("gmod_softlamp", MakeSoftLamp, "r", "g", "b", "KeyDown", "Toggle", "Texture", "Model", "fov", "distance", "nearz", "brightness", "on", "shape", "radius", "layers", "Data", "OrthoOn", "OrthoSize")

	local function Toggle( pl, ent, onoff )

		if ( !IsValid( ent ) ) then return false end
		if ( !ent:GetToggle() ) then ent:Switch( onoff == 1 ) return end

		if ( numpad.FromButton() ) then

			ent:Toggle()
			return

		end

		if ( onoff == 0 ) then return end

		return ent:Toggle()

	end
	numpad.Register( "SoftLampToggle", Toggle )

end

function TOOL:UpdateGhostLamp( ent, player )

	if ( !IsValid( ent ) ) then return end

	local tr = util.GetPlayerTrace( player )
	local trace	= util.TraceLine( tr )
	if ( !trace.Hit ) then return end

	if ( trace.Entity:IsPlayer() || trace.Entity:GetClass() == "gmod_softlamp" ) then

		ent:SetNoDraw( true )
		return

	end

	local CurPos = ent:GetPos()
	local NearestPoint = ent:NearestPoint( CurPos - ( trace.HitNormal * 512 ) )
	local LampOffset = CurPos - NearestPoint

	ent:SetPos( trace.HitPos + LampOffset )

	ent:SetNoDraw( false )

end

function TOOL:Think()

	if ( !IsValid( self.GhostEntity ) || self.GhostEntity:GetModel() != self:GetClientInfo( "model" ) ) then
		self:MakeGhostEntity( self:GetClientInfo( "model" ), Vector( 0, 0, 0 ), Angle( 0, 0, 0 ) )
	end

	self:UpdateGhostLamp( self.GhostEntity, self:GetOwner() )

end

function TOOL.BuildCPanel( CPanel )
	CPanel:Help("#tool.softlamp.desc")

	CPanel:AddControl( "Numpad", { Label = "#tool.softlamp.key", Command = "softlamp_key" } )

	CPanel:NumSlider("#tool.softlamp.fov", "softlamp_fov", 10, 170)
	CPanel:NumSlider("#tool.softlamp.distance", "softlamp_distance", 64, 2048)
	CPanel:NumSlider("#tool.softlamp.nearz", "softlamp_nearz", 0, 24)

	CPanel:NumSlider("#tool.softlamp.brightness", "softlamp_brightness", 0, 8, 2)

	local shapelist = {}
	for k, v in pairs(vectorshapes.GetShapes()) do
		shapelist[v.nicename] = { softlamp_shape = k}
	end
	local shapeselect = CPanel:AddControl( "listbox", { label = "#tool.softlamp.shape", options = shapelist } )

	CPanel:NumSlider("#tool.softlamp.radius", "softlamp_radius", 0, 250)
	local layerslider = CPanel:NumSlider("#tool.softlamp.layers", "softlamp_layers", 1, 30, 0)
	local countlabel = vgui.Create("DLabel", CPanel)
	countlabel:SetText("#tool.softlamp.lightcount")
	local countnumber = vgui.Create("DLabel", CPanel)
	CPanel:AddItem(countlabel, countnumber)

	local shapecvar = GetConVar("softlamp_shape")
	local radiuscvar = GetConVar("softlamp_radius")
	local layerscvar = GetConVar("softlamp_layers")

	local oldthink = countnumber.Think
	function countnumber:Think(...)
		local ret = oldthink(self, ...)

		if
			self.oldshape != shapecvar:GetString() or
			self.oldradius != radiuscvar:GetFloat() or
			self.oldlayers != layerscvar:GetInt()
		then
			self.oldshape = shapecvar:GetString()
			self.oldradius = radiuscvar:GetFloat()
			self.oldlayers = layerscvar:GetInt()

			local vecs = vectorshapes.MakeShape(self.oldshape, self.oldradius, self.oldlayers)

			self:SetText(#vecs.all)
		end
		return ret
	end

	CPanel:CheckBox("#tool.softlamp.toggle", "softlamp_toggle")
	CPanel:CheckBox("#tool.softlamp.on", "softlamp_on")

	local MatSelect = CPanel:MatSelect( "softlamp_texture", nil, true, 0.33, 0.33 )
	for k, v in pairs( list.Get( "LampTextures" ) ) do
		MatSelect:AddMaterial( v.Name or k, k )
	end

	CPanel:AddControl( "Color", { Label = "#tool.softlamp.color", Red = "softlamp_r", Green = "softlamp_g", Blue = "softlamp_b" } )

	CPanel:AddControl( "PropSelect", { Label = "#tool.softlamp.model", ConVar = "softlamp_model", Height = 3, Models = list.Get( "LampModels" ) } )

	CPanel:CheckBox("#tool.softlamp.ortho_on", "softlamp_orthoon")
	CPanel:NumSlider("#tool.softlamp.ortho_size", "softlamp_orthosize", 0, 2048)
end

list.Set( "LampTextures", "models/debug/debugwhite", { Name = "#lamptexture.debug" } )
