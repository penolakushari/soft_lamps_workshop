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

function ENT:HeavyLightPrepare()
	self:ClearFlashlights()	-- they will be recreated in the next Think, after HeavyLights is done
end

--[[---------------------------------------------------------
   Name: HeavyLightStart
   Desc: Indicates to the 
-----------------------------------------------------------]]
function ENT:HeavyLightStart(brightness, lampcount, vlplanecount, vlpasscount)
	if not self.HeavyLightPT then self.HeavyLightPT = {} end
	if not lampcount then lampcount = 1 end

	local split = self:GetHeavySplit()
	local splitf = (split > 1) and (split / 1.16) or split-- 98.5 / 90 = 1.094444 , adjustment for that flashlight square texture

	for k, pt in ipairs(self.HeavyLightPT) do
		if IsValid(pt) then pt:Remove() end
	end
	self.HeavyLightPT = {}

	if IsValid(self.HeavyLightVLPlane) then self.HeavyLightVLPlane:Remove() end

	for i = 1, lampcount do
		local pt = ProjectedTexture() 
		pt:SetEnableShadows(true)
		pt:SetTexture(self:GetFlashlightTexture())
		pt:SetNearZ(self:GetNearZ())
		pt:SetFarZ(self:GetFarZ())
		pt:SetFOV(self:GetLightFOV() / splitf)
		pt:SetOrthographic(self:GetEnableOrthographic(), self:GetOrthoLeft() / splitf, self:GetOrthoTop() / splitf, self:GetOrthoRight() / splitf, self:GetOrthoBottom() / splitf)
		pt:SetLinearAttenuation(self:GetLinearAttenuation())
		pt:SetQuadraticAttenuation(self:GetQuadraticAttenuation())
		pt:SetConstantAttenuation(self:GetConstantAttenuation())
		pt:SetColor(self:GetLightColor():ToColor())
		pt:SetBrightness(brightness * split^2)	-- brightness is dictated from outside

		self.HeavyLightPT[i] = pt
	end

	self.HeavyLightIndex = 0

	if vlplanecount then
		self.HeavyLightVLPlaneIndex = 0
		self.HeavyLightVLPlaneMax = vlplanecount
		self.HeavyLightVLPlanePass = 1
		self.HeavyLightVLPPlanePassMax = vlpasscount
		self.HeavyLightVLPlane = ClientsideModel("models/vlplane/vlplane.mdl", RENDERGROUP_TRANSLUCENT)
		self.HeavyLightVLPlane:SetNoDraw(false)--true)	-- wait until it's being activated
		self.HeavyLightVLPlane:SetModelScale(10000)
	else
		self.HeavyLightVLPlanePass = nil
		self.HeavyLightVLPlaneIndex = nil
		self.HeavyLightVLPlaneMax = nil
	end
end

function ENT:HeavyLightTick(viewpos)
	local nextpos = true

	if self.HeavyLightVLPlaneIndex then
		self.HeavyLightVLPlaneIndex = self.HeavyLightVLPlaneIndex + 1
		nextpos = self.HeavyLightIndex == 0	-- FALSE unless this is the first one. Basically a hack because I cba to restructure my code in a more logical way.
		if self.HeavyLightVLPlaneIndex > self.HeavyLightVLPlaneMax then
			if self.HeavyLightVLPlanePass >= self.HeavyLightVLPPlanePassMax then
				nextpos = true
				self.HeavyLightVLPlanePass = 1
			else
				self.HeavyLightVLPlanePass = self.HeavyLightVLPlanePass + 1
			end
			self.HeavyLightVLPlaneIndex = 1
		end
	end

	if nextpos then
		local done = false

		for k, pt in ipairs(self.HeavyLightPT) do
			self.HeavyLightIndex = self.HeavyLightIndex + 1

			if self.HeavyLightIndex > self:HeavyLightCount() then
				if k == 1 then
					done = true
				end
				break
			end

			local pos = self:GetVecs(true).positions[self.HeavyLightIndex]
			if not pos then
				-- this shouldn't happen
				error("Discrepancy between SoftLamp:HeavyLightCount() and SoftLamp:GetVecs(true) size!")
			end

			pt:SetPos(self:LocalToWorld(pos.vec))
			pt:SetAngles(self:LocalToWorldAngles(pos.ang))
--			pt:SetVerticalFOV(self:GetLightFOV() / (self:GetHeavySplit() / 1.16)) -- There's some issue on gmod bug tracker since 2017 which mentions differing Horizontal and Vertical FOVs breaking shadows
--			pt:SetHorizontalFOV(self:GetLightFOV() * 0.9 / (self:GetHeavySplit() / 1.16)) -- I still experience that bug. I was so close to greatness!
			pt:Update()
		end

		if done then
			-- All done.
			for k, pt in ipairs(self.HeavyLightPT) do pt:Remove() end
			--if IsValid(self.HeavyLightVLPlane) then self.HeavyLightVLPlane:Remove() end
			return false
		end
	end

	if IsValid(self.HeavyLightVLPlane) then
		local fov = self:GetLightFOV() / 2
		local min = 1
		local max = self.HeavyLightVLPlaneMax

		local lamppos, lampang = self.HeavyLightPT[1]:GetPos(), self.HeavyLightPT[1]:GetAngles()
		local lviewpos = WorldToLocal(viewpos, angle_zero, lamppos, lampang)
		lviewpos.x = 0
		local roll = lviewpos:Angle().pitch
		local passmod = ((self.HeavyLightVLPlanePass-1) / self.HeavyLightVLPPlanePassMax)*180
		roll = roll + passmod

		local ang = math.Remap(self.HeavyLightVLPlaneIndex, min, max, -fov, fov)
		local worldpos, worldang
		worldpos, worldang = LocalToWorld(vector_origin, Angle(0, 0, roll), vector_origin, lampang)
		worldpos, worldang = LocalToWorld(vector_origin, Angle(0, ang, 0), lamppos, worldang)

		--print(worldpos, worldang)

		self.HeavyLightVLPlane:SetPos(worldpos)
		self.HeavyLightVLPlane:SetAngles(worldang)

		self.HeavyLightVLPlane:SetupBones()
		self.HeavyLightPT[1]:Update() --?
	end

	return true, self.HeavyLightVLPlane, self.HeavyLightVLPlaneIndex, self.HeavyLightVLPlanePass
end

function ENT:Think()
	if self.HeavyLightPT then
		for k, pt in ipairs(self.HeavyLightPT) do
			if IsValid(pt) then pt:Remove() end
		end
		self.HeavyLightPT = nil
	end

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
	local orton, ortleft, orttop, ortright, ortbot = self:GetEnableOrthographic(), self:GetOrthoLeft(), self:GetOrthoTop(), self:GetOrthoRight(), self:GetOrthoBottom()
	local tex = self:GetFlashlightTexture()
	local b = self:GetBrightness() / table.Count(self.Flashlights)	-- total sum of lights' brightness should equal requested brightness
	local c = self:GetLightColor():ToColor()	-- convert vector to color structure

	for pt, pos in pairs(self.Flashlights) do
		pt:SetTexture(tex)
		pt:SetNearZ(nearz)
		pt:SetFarZ(farz)
		pt:SetFOV(fov)
		pt:SetOrthographic(orton, ortleft, orttop, ortright, ortbot)
		pt:SetLinearAttenuation(self:GetLinearAttenuation())
		pt:SetQuadraticAttenuation(self:GetQuadraticAttenuation())
		pt:SetConstantAttenuation(self:GetConstantAttenuation())
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
	local color = Color(self.drawbrightness, self.drawbrightness, self.drawbrightness)
	self.lastdraw = now

	if self:GetPreviewIgnoreZ() then render.SetColorMaterialIgnoreZ() else render.SetColorMaterial() end
	local lastvec = nil
	for k, vec in pairs(points.all) do
		-- Draw the absolute minimal sphere that has volume for each projected texture:
		if not lastvec or not vec:IsEqualTol(lastvec, 0.5) then
			render.DrawSphere( self:LocalToWorld(vec), size, 4, 3,  color)
		end

		lastvec = vec
	end
end

function ENT:OnRemove()
	self:ClearFlashlights()
end
