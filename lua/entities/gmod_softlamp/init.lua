AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

require("vectorshapes")

DEFINE_BASECLASS( "base_gmodentity" )

include("shared.lua")

--[[---------------------------------------------------------
	Name: Initialize
	Desc: Pretty much copied from gmod_lamp, no idea what's
	done here.
-----------------------------------------------------------]]
function ENT:Initialize()
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:DrawShadow( false )

	local phys = self:GetPhysicsObject()

	if ( IsValid( phys ) ) then
		phys:Wake()
	end

	-- Make lights start to the front of the lamp rather than inside it
	self:SetLightOffset( Vector(self:OBBMaxs().x, 0, 0) )
	self:SetHeavyOn(true)
end

function ENT:Come()
	local ply = Entity(1) -- we're being hacky anyway, right?
	self:SetAngles(ply:EyeAngles())
	self:SetLightOffset(self:WorldToLocal(ply:EyePos()))
end
concommand.Add("softlamp_come", function()
	for _, lamp in pairs(ents.FindByClass("gmod_softlamp")) do
		lamp:Come()
	end
end, nil, nil, FCVAR_SPONLY)

function ENT:Think()
	if self:GetDelete1() and self:GetDelete2() then
		self:Remove()
		return BaseClass.Think(self)
	end

	self.shape = self:GetHeavyShape()
	self.radius = self:GetShapeRadius()
	self.layers = self:GetGameplayLayers()

	self.fov = self:GetLightFOV()
	self.distance = self:GetDistance()
	self.nearz = self:GetNearZ()

	self.OrthoOn = self:GetEnableOrthographic()

	local col = self:GetLightColor():ToColor()
	self.r = col.r
	self.g = col.g
	self.b = col.b

	self.brightness = self:GetBrightness()

	return BaseClass.Think(self)
end

function ENT:Switch( on )
	if (on == self:GetOn()) then return end
	self.on = on
	self:SetOn(on)
end

--[[---------------------------------------------------------
   Name: Toggle
-----------------------------------------------------------]]
function ENT:Toggle()
	self:Switch( !self:GetOn() );
end

--[[---------------------------------------------------------
	Name: OnTakeDamage
	Desc: Pretty much copied from gmod_lamp.
-----------------------------------------------------------]]
function ENT:OnTakeDamage( dmginfo )
	self:TakePhysicsDamage( dmginfo )
end
