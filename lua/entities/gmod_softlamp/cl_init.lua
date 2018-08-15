require("vectorshapes")

DEFINE_BASECLASS( "base_gmodentity" )

include("shared.lua")

--[[---------------------------------------------------------
   Name: Initialize
-----------------------------------------------------------]]
function ENT:Initialize()
	-- To render when the model is out of the screen but the flashlight indicators are inside:
	local mins, maxs = self:GetModelRenderBounds()
	local radius = self:GetShapeRadius()
	mins.y = math.min(mins.y, -radius)
	mins.z = math.min(mins.z, -radius)
	maxs.y = math.max(maxs.y, radius)
	maxs.z = math.max(maxs.z, radius)
	self:SetRenderBounds(mins, maxs)
end

--[[---------------------------------------------------------
   Name: ClearFlashlights
   Desc: Removes all ProjectedTextures
-----------------------------------------------------------]]
function ENT:ClearFlashlights()
	if self.Flashlights then
		for pt, vec in pairs(self.Flashlights) do
			pt:Remove()
		end
		table.Empty(self.Flashlights)
	end

	self.Flashlights = self.Flashlights or {}
	self.FlashlightsDirty = true
end

function ENT:CreateFlashlights()
	local vecs = self:GetVecs()
	self:ClearFlashlights()

	for _, pos in pairs(vecs.positions) do
		local pt = ProjectedTexture()
		pt:SetEnableShadows(true)
		-- other stuff are set every Think.

		self.Flashlights[pt] = pos
	end

	self.FlashlightsDirty = false
end

--[[---------------------------------------------------------
   Name: HeavyLightStart
   Desc: Indicates to the 
-----------------------------------------------------------]]
function ENT:HeavyLightStart(brightness, vlplanecount)
	self:ClearFlashlights()	-- they will be recreated in the next Think, after HeavyLights is done

	if IsValid(self.HeavyLightPT) then self.HeavyLightPT:Remove() end
	if IsValid(self.HeavyLightVLPlane) then self.HeavyLightVLPlane:Remove() end

	self.HeavyLightPT = ProjectedTexture()
	self.HeavyLightPT:SetEnableShadows(true)
	self.HeavyLightPT:SetTexture(self:GetFlashlightTexture())
	self.HeavyLightPT:SetNearZ(self:GetNearZ())
	self.HeavyLightPT:SetFarZ(self:GetFarZ())
	self.HeavyLightPT:SetFOV(self:GetLightFOV())
	self.HeavyLightPT:SetColor(self:GetLightColor():ToColor())
	self.HeavyLightPT:SetBrightness(brightness)	-- brightness is dictated from outside

	self.HeavyLightIndex = 0

	if vlplanecount then
		self.HeavyLightVLPlaneIndex = 0
		self.HeavyLightVLPlaneMax = vlplanecount
		self.HeavyLightVLPlane = ClientsideModel("models/vlplane/vlplane.mdl", RENDERGROUP_TRANSLUCENT)
		self.HeavyLightVLPlane:SetNoDraw(false)--true)	-- wait until it's being activated
		self.HeavyLightVLPlane:SetModelScale(10000)
	else
		self.HeavyLightVLPlaneIndex = nil
		self.HeavyLightVLPlaneMax = nil
	end
end

function ENT:HeavyLightTick()
	local nextpos = true

	if self.HeavyLightVLPlaneIndex then
		self.HeavyLightVLPlaneIndex = self.HeavyLightVLPlaneIndex + 1
		nextpos = self.HeavyLightIndex == 0	-- FALSE unless this is the first one. Basically a hack because I cba to restructure my code in a more logical way.
		if self.HeavyLightVLPlaneIndex > self.HeavyLightVLPlaneMax then
			nextpos = true
			self.HeavyLightVLPlaneIndex = 1
		end
	end

	if nextpos then
		self.HeavyLightIndex = self.HeavyLightIndex + 1

		if self.HeavyLightIndex > self:HeavyLightCount() then
			-- All done.
			self.HeavyLightPT:Remove()
			--if IsValid(self.HeavyLightVLPlane) then self.HeavyLightVLPlane:Remove() end
			return false
		end

		local pos = self:GetVecs(true).positions[self.HeavyLightIndex]
		if not pos then
			-- this shouldn't happen
			error("Discrepancy between SoftLamp:HeavyLightCount() and SoftLamp:GetVecs(true) size!")
		end

		self.HeavyLightPT:SetPos(self:LocalToWorld(pos.vec))
		self.HeavyLightPT:SetAngles(self:LocalToWorldAngles(pos.ang))
		self.HeavyLightPT:Update()
	end

	if IsValid(self.HeavyLightVLPlane) then
		
		local fov = self:GetLightFOV() / 2
		local min = 1
		local max = self.HeavyLightVLPlaneMax

		local ang = math.Remap(self.HeavyLightVLPlaneIndex, min, max, -fov, fov)

		local worldpos, worldang = LocalToWorld(Vector(0, 0, 0), Angle(0, ang, 0), self.HeavyLightPT:GetPos(), self.HeavyLightPT:GetAngles())
		--print(worldpos, worldang)

		self.HeavyLightVLPlane:SetPos(worldpos)
		self.HeavyLightVLPlane:SetAngles(worldang)

		self.HeavyLightVLPlane:SetupBones()
		self.HeavyLightPT:Update() --?
	end

	return true, self.HeavyLightIndex, #self:GetVecs(true).positions, self.HeavyLightVLPlane, self.HeavyLightVLPlaneIndex, self.HeavyLightVLPlaneMax
end

function ENT:Think()
	if IsValid(self.HeavyLightPT) then
		self.HeavyLightPT:Remove()
	end
	self.HeavyLightPT = nil

	if IsValid(self.HeavyLightVLPlane) then
		self.HeavyLightVLPlane:Remove()
	end
	self.HeavyLightVLPlane = nil

	if not self:GetOn() then
		self:ClearFlashlights()
		return BaseClass.Think(self)
	end

	self:CheckDirty()

	if self.VecsDirty or self.FlashlightsDirty or not self.Flashlights then
		self:CreateFlashlights()

		-- To render when the model is out of the screen but the flashlight indicators are inside:
		local mins, maxs = self:GetModelRenderBounds()
		local radius = self:GetShapeRadius()
		mins.y = math.min(mins.y, -radius)
		mins.z = math.min(mins.z, -radius)
		maxs.y = math.max(maxs.y, radius)
		maxs.z = math.max(maxs.z, radius)
		self:SetRenderBounds(mins, maxs)
	end

	local nearz = self:GetNearZ()
	local farz = self:GetFarZ()
	local fov = self:GetLightFOV()
	local tex = self:GetFlashlightTexture()
	local b = self:GetBrightness() / table.Count(self.Flashlights)	-- total sum of lights' brightness should equal requested brightness
	local c = self:GetLightColor():ToColor()	-- convert vector to color structure

	for pt, pos in pairs(self.Flashlights) do
		pt:SetTexture(tex)
		pt:SetNearZ(nearz)
		pt:SetFarZ(farz)
		pt:SetFOV(fov)
		pt:SetColor(c)
		pt:SetBrightness(b)

		pt:SetPos(self:LocalToWorld(pos.vec))
		pt:SetAngles(self:LocalToWorldAngles(pos.ang))

		pt:Update()
	end

	--self:SetNextClientThink(CurTime() + 0.2)	-- should I...?

	return BaseClass.Think(self)
end

--[[---------------------------------------------------------
	Name: Draw
	Desc: Draw the model as well as the 
-----------------------------------------------------------]]
function ENT:Draw()
	BaseClass.Draw( self )
	if not self:GetPreviewPoints() then return end

	local points = self:GetVecs(true)	-- get the vecs for the heavy shape

	local size = EyePos():Distance(self:GetPos()) / 256

	local now = RealTime()
	self.drawbrightness = math.Approach(self.drawbrightness or 128,self:GetOn() and 255 or 0, (now-(self.lastdraw or 0))*512)
	self.lastdraw = now

	if self:GetPreviewIgnoreZ() then render.SetColorMaterialIgnoreZ() else render.SetColorMaterial() end
	for k, vec in pairs(points.all) do
		-- Draw the absolute minimal sphere that has volume for each projected texture:
		render.DrawSphere( self:LocalToWorld(vec), size, 4, 3, Color(self.drawbrightness, self.drawbrightness, self.drawbrightness) )
	end
end

function ENT:OnRemove()
	self:ClearFlashlights()
end