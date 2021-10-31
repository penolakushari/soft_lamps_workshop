require("vectorshapes")

DEFINE_BASECLASS( "base_gmodentity" )

ENT.Base = "base_gmodentity"
ENT.Author = "NeatNit"
ENT.Spawnable	= false
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.PrintName = "Soft Lamp"
ENT.Editable	= true	-- Set to FALSE after making a custom edit menu - but keep the Edit values defined to enable using the same system in the custom edit menu.

--[[---------------------------------------------------------
   Name: SetupDataTables
   Desc: Define Network Variables
-----------------------------------------------------------]]
function ENT:SetupDataTables()
	local thisorder = 0
	local function orderer()
		thisorder = thisorder + 1
		return thisorder
	end

	-- Lamp
	self:NetworkVar("Bool",   0, "Toggle")
	self:NetworkVar("Vector", 0, "LightOffset",   { KeyName = "lightoffset", Edit = { order = orderer(), category = "Lamp", type = "Generic",     title = "Offset" } })
	self:NetworkVar("Vector", 1, "LightColor",    { KeyName = "lightcolor",  Edit = { order = orderer(), category = "Lamp", type = "VectorColor", title = "Color" } })
	self:NetworkVar("Float",  0, "Brightness",    { KeyName = "brightness",  Edit = { order = orderer(), category = "Lamp", type = "Float",       title = "Brightness", min = 0, max = 1000 } })
	self:NetworkVar("Float",  1, "LightFOV",      { KeyName = "fov",         Edit = { order = orderer(), category = "Lamp", type = "Float",       title = "FOV", min = 0, max = 180 } })
	self:NetworkVar("Float",  2, "NearZ",         { KeyName = "nearz",       Edit = { order = orderer(), category = "Lamp", type = "Float",       title = "NearZ", min = 1, max = 1048576 } })
	self:NetworkVar("Float",  3, "FarZ",          { KeyName = "farz",        Edit = { order = orderer(), category = "Lamp", type = "Float",       title = "FarZ",  min = 1, max = 1048576 } })
	self:NetworkVar("Float",  3, "Distance")	-- temp, need to get rid of this
	self:NetworkVar("Float",  6, "FocalDistance", { KeyName = "focal",       Edit = { order = orderer(), category = "Lamp", type = "Float",       title = "Focal Point Distance",  min = 0, max = 1048576 } })
	self:NetworkVar("String", 0, "FlashlightTexture")

	local shapes = vectorshapes.GetShapes()
	local combo = {}
	for k, v in pairs(shapes) do
		local nicename = v.nicename or k
		combo[nicename] = k
	end
	-- HeavyLight
	self:NetworkVar("Bool",   1, "HeavyOn",     { KeyName = "on",      Edit = { order = orderer(), category = "HeavyLight", type = "Boolean",     title = "On" } })
	self:NetworkVar("String", 1, "HeavyShape",  { KeyName = "pshape",  Edit = { order = orderer(), category = "HeavyLight", type = "Combo", title = "Surface Shape", values = combo } })
	self:NetworkVar("Float",  4, "ShapeRadius", { KeyName = "sradius", Edit = { order = orderer(), category = "HeavyLight", type = "Float", title = "Surface Radius", min = 1, max = 1048576 } })
	self:NetworkVar("Int",    0, "HeavyLayers", { KeyName = "players", Edit = { order = orderer(), category = "HeavyLight", type = "Int",   title = "Surface Shape Resolution", min = 1, max = 200 } })

	local combo2 = table.Copy(combo)
	combo2["Same as above"] = ""
	-- Gameplay
	self:NetworkVar("Bool",   2, "On",             { KeyName = "pon",     Edit = { order = orderer(), category = "Gameplay", type = "Boolean", title = "On" } })
	--self:NetworkVar("Float",  5, "Scroll",         { KeyName = "pon",     Edit = { order = orderer(), category = "Gameplay", type = "Float", title = "Scroll Speed (override gameplay shape)", min = 0, max = 60 } })
	self:NetworkVar("String", 2, "GameplayShape",  { KeyName = "sshape",  Edit = { order = orderer(), category = "Gameplay", type = "Combo",  title = "Surface Shape", values = combo2, text = "Same as above" } })
	self:NetworkVar("Int",    1, "GameplayLayers", { KeyName = "slayers", Edit = { order = orderer(), category = "Gameplay", type = "Int",   title = "Surface Shape Resolution", min = 1, max = 100 } })

	-- Visualization
	self:NetworkVar("Bool", 3, "PreviewPoster",   { KeyName = "previewposter",  Edit = { order = orderer(), category = "Visualization", type = "Combo", title = "Pick Target", values = { Gameplay = false, HeavyLight = true }, text = "Gameplay" } })
	self:NetworkVar("Bool", 4, "PreviewPoints",   { KeyName = "previewpoints",  Edit = { order = orderer(), category = "Visualization", type = "Boolean", title = "Light Sources" } })
	--self:NetworkVar("Bool", 5, "PreviewCone",     { KeyName = "previewcone",    Edit = { order = orderer(), category = "Visualization", type = "Boolean", title = "Projection Cones" } })
	self:NetworkVar("Bool", 6, "PreviewSafeArea", { KeyName = "previewsafe",    Edit = { order = orderer(), category = "Visualization", type = "Boolean", title = "Safe Area" } })
	self:NetworkVar("Bool", 7, "PreviewIgnoreZ",  { KeyName = "previewignorez", Edit = { order = orderer(), category = "Visualization", type = "Boolean", title = "Show Through Walls" } })

	-- Delete
	self:NetworkVar("Bool", 8, "Delete1", { KeyName = "del", Edit = { order = orderer(), category = "Delete (select both to delete)", type = "Boolean", title = "Delete (1)" } })
	self:NetworkVar("Bool", 9, "Delete2", { KeyName = "ete", Edit = { order = orderer(), category = "Delete (select both to delete)", type = "Boolean", title = "Delete (2)" } })
end

-- Everything below this point is practically only used in clientside,
-- but for future-proofing reasons I'm keeping it shared:

function ENT:GetVecs(heavy, world)
	self:CheckDirty()
	local vecs

	if (not heavy and self.VecsDirty == false) then
		vecs = self.Vecs
	elseif (heavy and self.HeavyVecsDirty == false) then
		vecs = self.HeavyVecs

	else
		if heavy then

			local shape = self:GetHeavyShape()
			local radius = self:GetShapeRadius()
			local layers = self:GetHeavyLayers()

			vecs = vectorshapes.MakeShape(shape, radius, layers)

			vecs._shape = shape
			vecs._radius = radius
			vecs._layers = layers

			self.HeavyVecs = vecs
			self.HeavyVecsDirty = false

		else

			local shape = self:GetGameplayShape()
				if shape == "" then shape = self:GetHeavyShape() end
			local radius = self:GetShapeRadius()
			local layers = self:GetGameplayLayers()

			vecs = vectorshapes.MakeShape(shape, radius, layers)

			-- Limit to a max of 8 lights for performance reasons to not crash the game:
			local l = layers
			while #vecs.all > 8 and l > 2 do
				l = l - 1
				vecs = vectorshapes.MakeShape(shape, radius, l)
			end

			vecs._shape = shape
			vecs._radius = radius
			vecs._layers = layers	-- store the original number of layers, even though technically there are fewer

			self.Vecs = vecs
			self.VecsDirty = false
			self.FlashlightsDirty = true -- used only clientside

		end

		-- Set angle to point at the focal point, and apply offset:
		local focaldist = self:GetFocalDistance()
		local focalpoint = Vector(focaldist, 0, 0)
		local offset = self:GetLightOffset()
		vecs.positions = {}
		for k, v in pairs(vecs.all) do
			vecs.positions[k] = {}

			if focaldist > 0 then
				vecs.positions[k].ang = (focalpoint - v):Angle()
			else
				vecs.positions[k].ang = Angle()
			end

			v:Add(offset)
			vecs.positions[k].vec = v
		end

		vecs._offset = offset
		vecs._focus = focaldist
	end

	if not world then return vecs end

	-- Convert to world (global) coordinates:
	local worldvecs = {all = {}, positions = {}}

	for k, v in pairs(vecs.positions) do
		worldvecs.positions[k].vec = self:LocalToWorld(v.vec)
		worldvecs.positions[k].ang = self:LocalToWorldAngles(v.ang)
		worldvecs.all[k] = worldvecs.positions[k].vec	-- mirror
	end

	return worldvecs
end

function ENT:HeavyLightCount()
	return self:GetHeavyOn() and #(self:GetVecs(true).positions) or 0
end

function ENT:CheckDirty()
	-- Check if the vecs for the heavy shape are dirty:
	if (not self.HeavyVecsDirty) and (
		(not self.HeavyVecs) or
		self.HeavyVecs._shape ~= self:GetHeavyShape() or
		self.HeavyVecs._radius ~= self:GetShapeRadius() or
		self.HeavyVecs._layers ~= self:GetHeavyLayers() or
		self.HeavyVecs._offset ~= self:GetLightOffset() or
		self.HeavyVecs._focus ~= self:GetFocalDistance() )
	then
		self.HeavyVecsDirty = true
	end

	-- Check if the vecs for the gameplay shape are dirty:
	if (not self.VecsDirty) and (
		(not self.Vecs) or
		not (self.Vecs._shape == self:GetGameplayShape() or
			self:GetGameplayShape() == "" and self.Vecs._shape == self:GetHeavyShape() ) or
		self.Vecs._radius ~= self:GetShapeRadius() or
		self.Vecs._layers ~= self:GetGameplayLayers() or
		self.Vecs._offset ~= self:GetLightOffset() or
		self.Vecs._focus ~= self:GetFocalDistance() )
	then
		self.VecsDirty = true
	end
end
