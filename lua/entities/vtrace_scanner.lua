AddCSLuaFile()
DEFINE_BASECLASS( "base_gmodentity" )
ENT.RenderGroup = RENDERGROUP_OTHER
function ENT:Initialize()
	self:DrawShadow(false)
end