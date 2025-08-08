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

SoftLampPresets = SoftLampPresets or {}

-- Function to save preset from entity (capturing ALL entity settings)
local function SaveEntityAsPreset(entity, name)
	if not name or name == "" or not IsValid(entity) then return end

	local clr = entity:GetLightColor()
	local offset = entity:GetLightOffset()


	SoftLampPresets[name] = {
		-- Basic tool settings
		r = math.floor(clr.r * 255),
		g = math.floor(clr.g * 255),
		b = math.floor(clr.b * 255),
		fov = entity:GetLightFOV(),
		distance = entity:GetFarZ(),
		nearz = entity:GetNearZ(),
		brightness = entity:GetBrightness(),
		texture = entity:GetFlashlightTexture(),
		model = entity:GetModel(),
		toggle = entity:GetToggle() and 1 or 0,
		on = entity:GetOn() and 1 or 0,

		-- Lamp settings (from entity edit menu)
		lightoffset_x = offset.x,
		lightoffset_y = offset.y,
		lightoffset_z = offset.z,
		focaldistance = entity:GetFocalDistance(),
		linear = entity:GetLinearAttenuation(),
		quadratic = entity:GetQuadraticAttenuation(),
		constant = entity:GetConstantAttenuation(),

		-- Orthographic settings (complete)
		orthoon = entity:GetEnableOrthographic() and 1 or 0,
		ortho_left = entity:GetOrthoLeft(),
		ortho_top = entity:GetOrthoTop(),
		ortho_right = entity:GetOrthoRight(),
		ortho_bottom = entity:GetOrthoBottom(),

		-- HeavyLight settings
		heavy_on = entity:GetHeavyOn() and 1 or 0,
		heavy_shape = entity:GetHeavyShape(),
		shape_radius = entity:GetShapeRadius(),
		heavy_layers = entity:GetHeavyLayers(),
		heavy_split = entity:GetHeavySplit(),

		-- Gameplay settings (make sure we get the actual on state)
		gameplay_on = entity:GetOn() and 1 or 0,
		gameplay_shape = entity:GetGameplayShape(),
		gameplay_layers = entity:GetGameplayLayers(),

		-- Visualization settings
		preview_poster = entity:GetPreviewPoster() and 1 or 0,
		preview_points = entity:GetPreviewPoints() and 1 or 0,
		preview_safearea = entity:GetPreviewSafeArea() and 1 or 0,
		preview_ignorez = entity:GetPreviewIgnoreZ() and 1 or 0,

		-- Legacy compatibility (keep old names for backward compatibility)
		orthosize = entity:GetOrthoLeft(),
		shape = entity:GetHeavyShape(),
		radius = entity:GetShapeRadius(),
		layers = entity:GetGameplayLayers()
	}

	-- Save to file
	local encoded = util.TableToJSON(SoftLampPresets)
	if encoded then
		file.Write("softlamp_presets.txt", encoded)
	end
	hook.Run("SoftLampPresetChanged")
end

-- Function to load preset to entity (applying ALL settings)
local function LoadPresetToEntity(entity, preset)
	if not IsValid(entity) or not preset then return end

	-- Always send to server, even in singleplayer
	-- This ensures the edit properties dialog sees the correct values
	net.Start("SoftLampLoadPreset")
		net.WriteEntity(entity)
		net.WriteTable(preset)
	net.SendToServer()
end

-- Client receives confirmation
net.Receive("SoftLampPresetLoaded", function()
	local entity = net.ReadEntity()
	if not IsValid(entity) then return end
	notification.AddLegacy( "Preset applied!", NOTIFY_GENERIC, 3 )
	surface.PlaySound("buttons/button14.wav")
end)

-- Add the context menu options via properties system
if not properties.List["softlamp_save_preset"] then
	properties.Add("softlamp_save_preset", {
		MenuLabel = "Save as Preset",
		Order = 9998,
		MenuIcon = "icon16/disk.png",
		Filter = function(self, ent, ply)
			return ent:GetClass() == "gmod_softlamp"
		end,
		Action = function(self, ent)
			Derma_StringRequest(
				"Save Lamp as Preset",
				"Enter a name for this preset (will save current lamp properties):",
				"",
				function( text )
					if text and text ~= "" then
						SaveEntityAsPreset(ent, text)
					end
				end,
				nil
			)
		end
	})
end

if not properties.List["softlamp_load_preset"] then
	properties.Add("softlamp_load_preset", {
		MenuLabel = "Load Preset",
		Order = 9999,
		MenuIcon = "icon16/folder_go.png",
		Filter = function(self, ent, ply)
			if ent:GetClass() ~= "gmod_softlamp" then return false end

			-- Count actual presets
			local presetCount = 0
			for name, preset in pairs(SoftLampPresets or {}) do
				presetCount = presetCount + 1
			end
			return presetCount > 0
		end,
		Action = function(self, ent)
			-- Create a selection dialog with all available presets
			local frame = vgui.Create("DFrame")
			frame:SetSize(300, 400)
			frame:SetTitle("Load Preset")
			frame:Center()
			frame:MakePopup()
			frame:ShowCloseButton(true)
			frame:SetDeleteOnClose(true)
			frame:SetSizable(false)
			frame:SetDraggable(true)

			-- Prevent clicks from passing through to the game world
			frame:SetMouseInputEnabled(true)
			frame:SetKeyboardInputEnabled(true)

			local list = vgui.Create("DListView", frame)
			list:Dock(FILL)
			list:SetMultiSelect(false)
			list:AddColumn("Preset Name")
			list:SetMouseInputEnabled(true)

			-- Add all presets to the list
			local presetCount = 0
			for name, preset in pairs(SoftLampPresets or {}) do
				list:AddLine(name)
				presetCount = presetCount + 1
			end

			if presetCount == 0 then
				frame:Close()
				chat.AddText(Color(255, 100, 100), "[Soft Lamps] ", Color(255, 255, 255), "No presets available to load!")
				return
			end

			-- Handle selection
			list.OnRowSelected = function(panel, rowIndex, row)
				local presetName = row:GetColumnText(1)
				if presetName and SoftLampPresets[presetName] then
					-- Prevent click from interfering with tool/game world
					input.SetCursorPos(ScrW()/2, ScrH()/2)
					gui.EnableScreenClicker(false)

					LoadPresetToEntity(ent, SoftLampPresets[presetName])
					frame:Close()
				end
			end

			-- Add load button
			local loadButton = vgui.Create("DButton", frame)
			loadButton:SetText("Load Selected Preset")
			loadButton:Dock(BOTTOM)
			loadButton:SetTall(30)
			loadButton:SetMouseInputEnabled(true)
			loadButton.DoClick = function()
				-- Prevent click from passing through to the game world
				input.SetCursorPos(ScrW()/2, ScrH()/2)
				gui.EnableScreenClicker(false)

				local selected = list:GetSelectedLine()
				if selected then
					local line = list:GetLine(selected)
					local presetName = line:GetColumnText(1)
					if presetName and SoftLampPresets[presetName] then
						LoadPresetToEntity(ent, SoftLampPresets[presetName])
						frame:Close()
					end
				else
					chat.AddText(Color(255, 100, 100), "[Soft Lamps] ", Color(255, 255, 255), "Please select a preset first!")
				end
			end
			
			-- Add help text
			local helpLabel = vgui.Create("DLabel", frame)
			helpLabel:SetText("Double-click or select and click 'Load' to apply preset")
			helpLabel:Dock(BOTTOM)
			helpLabel:SetTall(20)
			helpLabel:SetContentAlignment(5) -- Center
			helpLabel:SetTextColor(Color(100, 100, 100))
		end
	})
end
