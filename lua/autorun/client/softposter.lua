---@module "softlamps.client.frustrum"
local frustrum = include("softlamps/client/frustrum.lua")

--print("\tIF YOU SEE THIS TELL NEATNIT!! SoftPoster just got loaded!")
--local extraframes = CreateClientConVar("poster_extraframes", "0")
local lampcount = CreateClientConVar("poster_uselampcount", "1", true, false, "Soft Lamps: Amount of lamps to enable during 1 render tick", 1, 8)
local checkfrustrum = CreateClientConVar("poster_checkfrustrum", "1", true, false, "Soft Lamps: Check if the view frustrum intersects with lamp frustrum. Expensive on initialization but may potentially result in less render time", 0, 1)
local checkfrustrum_farz = CreateClientConVar("poster_checkfrustrum_farz", "-1", true, false, "Soft Lamps: Override farz for frustrum checks", -1)
local lightattenuation = CreateClientConVar("poster_lightbounce_attenuation", "quadratic", true, false, "Soft Lamps: Set the attenuation for lightbounces\n\t- quadratic\n\t- linear\n\t- constant")
local attenuations = {
	quadratic = true,
	linear = true,
	constant = true,
}
cvars.AddChangeCallback("poster_lightbounce_attenuation", function (convar, oldValue, newValue)
	if not attenuations[newValue] then
		-- Revert the convar to quadratic if the new convar isn't valid
		return lightattenuation:Revert()
	end
end)

local function matchAttenuation(attenuation, target)
	return attenuation == target and 1 or 0
end

local tex_render = render.GetSuperFPTex()
local tex_blend  = render.GetSuperFPTex2()
local tex_scrfx = render.GetScreenEffectTexture()
local mat_add    = Material("pp/add")
local mat_copy = Material("pp/copy")
local mat_divide = CreateMaterial(
	"SoftPosterMultiplier",	-- Name
	"g_colourmodify",	-- Shader
	{
		[ "$fbtexture" ] = "__rt_supertexture2",	-- __rt_supertexture2 is render.GetSuperFPTex2
		[ "$pp_colour_addb" ] = 0,
		[ "$pp_colour_addg" ] = 0,
		[ "$pp_colour_addr" ] = 0,
		[ "$pp_colour_brightness" ] = 0,
		[ "$pp_colour_colour" ] = 1,
		[ "$pp_colour_contrast" ] = 1,	-- only thing that's gonna change, originally 1
		[ "$pp_colour_mulr" ] = 0,
		[ "$pp_colour_mulg" ] = 0,
		[ "$pp_colour_mulb" ] = 0,
		[ "$ignorez" ] = 1
	}
)
-- local mat_gmodscreenspace = Material("pp/motionblur")
local tex_renderint = GetRenderTargetEx("VolumetricLightingRender", ScrW(), ScrH(), RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_NONE,
	bit.bor(
		0x0001,		-- Point Sampling
		0x0800,		-- Procedural
		0x8000,		-- Render Target
		0x40000,	-- Single Copy
		0x80000,	-- Pre SRGB
		0x800000	-- No Depth Buffer
	),
	CREATERENDERTARGETFLAGS_HDR, IMAGE_FORMAT_RGBA16161616)
local tex_blendint =  GetRenderTargetEx("VolumetricLightingBlend",  ScrW(), ScrH(), RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_NONE,
	bit.bor(
		0x0001,		-- Point Sampling
		0x0800,		-- Procedural
		0x8000,		-- Render Target
		0x40000,	-- Single Copy
		0x80000,	-- Pre SRGB
		0x800000	-- No Depth Buffer
	),
	CREATERENDERTARGETFLAGS_HDR, IMAGE_FORMAT_RGBA16161616)
-- print(tex_blendint:Width(), tex_blendint:Height())
--mat_add:SetString("$linearwrite", "1")
--mat_copy:SetString("$linearwrite", "1")


local Abort_LightCountVar = CreateClientConVar("posterabort_lightcount", "0")
local Abort_TimeVar = CreateClientConVar("posterabort_time", "0")
local Abort_PredictTimeVar = CreateClientConVar("posterabort_time_predict", "0")


local renders = 0
local antialias = false
concommand.Add("poster_aa", function(ply, cmd, args)
	antialias = args[1] == "1"
	if antialias then
		print("Anti aliasing enabled!")
	else
		print("Anti aliasing disabled!")
	end
end)


local additive = false
concommand.Add("poster_additive", function(ply, cmd, args)
	additive = args[1] == "1"
	if additive then
		print("Additive blending enabled!")
	else
		print("Additive blending disabled!")
	end
end)


local function DoRender(progressbardata, add)
	if not add then add = 1 end
	-- Render the scene normally to the whole texture (with inevitable 100% alpha)
	-- BUG!! Rendering into a non-default RT disables anti-aliasing!!
	-- WORKAROUND: Render to default RT, copy over to tex_render
	-- Workaround downside is that bright pixels (brighter than 255) will be capped, therefore color quality is lost.
	if antialias then
		-- workaround
		render.RenderView()
		render.UpdateScreenEffectTexture()

		render.PushRenderTarget(tex_render)
			mat_copy:SetTexture("$basetexture", tex_scrfx)
			render.SetMaterial(mat_copy)
			render.DrawScreenQuad()
		render.PopRenderTarget()
	else
		-- give up on anti-aliasing to get better color accuracy in bright areas
		render.PushRenderTarget(tex_render)
			render.RenderView()
		render.PopRenderTarget()
	end

	renders = renders + add

	-- Blend multiple renders together:
	render.PushRenderTarget(tex_blend)
		if renders == add then render.Clear(0, 0, 0, 255) end	-- clear on first render

		-- Additively paste the current frame onto the blend
		mat_add:SetTexture("$basetexture", tex_render)
		render.SetMaterial(mat_add)
		render.DrawScreenQuad()
	render.PopRenderTarget()


	-- Draw progress on the screen so the user can get a sense of progress and know that the game isn't stuck
	-- Put something pretty and technical on the screen:
	local ShowOnScreen = tex_blend
	--if additive then ShowOnScreen = tex_blend end
	mat_copy:SetTexture("$basetexture", ShowOnScreen)
	render.SetMaterial(mat_copy)
	render.DrawScreenQuad()

	-- Draw progress bars:
	cam.Start2D()
		local y = ScrH() - 20
		local x = ScrW() / 2
		for k, v in ipairs(progressbardata) do
			-- Grey outline:
			surface.SetDrawColor(50, 50, 50)
			surface.DrawRect(x-301, y-10, 602, 20)
			-- lighter-grey infill:
			surface.SetDrawColor(100, 100, 100)
			surface.DrawRect(x-300, y-9, 600, 18)

			-- Green progress bar:
			local progress = 600 * v.progress / v.max
			surface.SetDrawColor(20, 150, 20)
			surface.DrawRect(x-300, y-9, progress, 18)

			-- Text:
			surface.SetFont("DermaDefault")

			-- Progress bar text (example: 100 / 350)
			local text = v.progress .. " / " .. v.max
			local w, h = surface.GetTextSize(text)
			surface.SetTextPos(x-(w/2), y-(h/2))
			surface.SetTextColor(255, 255, 255)
			surface.DrawText(text)

			-- Title:
			surface.SetTextPos(x-296, y-(h/2))	-- Start of the progress bar
			surface.DrawText(v.title)

			y = y - 50 -- next progress bar is above
		end
	cam.End2D()

	-- Update the screen
	render.Spin()
end

local function DoRenderV2(progressbardata, add)
	if not add then add = 1 end
	-- Render the scene normally to the whole texture (with inevitable 100% alpha)
	-- BUG!! Rendering into a non-default RT disables anti-aliasing!!
	-- WORKAROUND: Render to default RT, copy over to tex_render
	-- Workaround downside is that bright pixels (brighter than 255) will be capped, therefore color quality is lost.
	if antialias then
		-- workaround
		render.RenderView()
		render.UpdateScreenEffectTexture()

		render.PushRenderTarget(tex_scrfx)
			mat_copy:SetTexture("$basetexture", tex_scrfx)
			render.SetMaterial(mat_copy)
			render.DrawScreenQuad()
		render.PopRenderTarget()
	else
		-- give up on anti-aliasing to get better color accuracy in bright areas
		render.PushRenderTarget(tex_scrfx)
			render.RenderView()
			hook.Run("RenderScreenspaceEffects")
			render.UpdateScreenEffectTexture()
		render.PopRenderTarget()
	end

	renders = renders + add

	-- Blend multiple renders together:
	render.PushRenderTarget(tex_blend)
		if renders == add then render.Clear(0, 0, 0, 255) end	-- clear on first render

		-- Additively paste the current frame onto the blend
		mat_add:SetTexture("$basetexture", tex_scrfx)
		render.SetMaterial(mat_add)
		render.DrawScreenQuad()
	render.PopRenderTarget()


	-- Draw progress on the screen so the user can get a sense of progress and know that the game isn't stuck
	-- Put something pretty and technical on the screen:
	local ShowOnScreen = tex_blend
	--if additive then ShowOnScreen = tex_blend end
	mat_copy:SetTexture("$basetexture", ShowOnScreen)
	render.SetMaterial(mat_copy)
	render.DrawScreenQuad()

	-- Draw progress bars:
	cam.Start2D()
		local y = ScrH() - 20
		local x = ScrW() / 2
		for k, v in ipairs(progressbardata) do
			-- Grey outline:
			surface.SetDrawColor(50, 50, 50)
			surface.DrawRect(x-301, y-10, 602, 20)
			-- lighter-grey infill:
			surface.SetDrawColor(100, 100, 100)
			surface.DrawRect(x-300, y-9, 600, 18)

			-- Green progress bar:
			local progress = 600 * v.progress / v.max
			surface.SetDrawColor(20, 150, 20)
			surface.DrawRect(x-300, y-9, progress, 18)

			-- Text:
			surface.SetFont("DermaDefault")

			-- Progress bar text (example: 100 / 350)
			local text = v.progress .. " / " .. v.max
			local w, h = surface.GetTextSize(text)
			surface.SetTextPos(x-(w/2), y-(h/2))
			surface.SetTextColor(255, 255, 255)
			surface.DrawText(text)

			-- Title:
			surface.SetTextPos(x-296, y-(h/2))	-- Start of the progress bar
			surface.DrawText(v.title)

			y = y - 50 -- next progress bar is above
		end
	cam.End2D()

	-- Update the screen
	render.Spin()
end

function RenderZBuffer()
	render.RenderView()
	render.Clear(0, 0, 0, 255, false, true)
end

local colormod = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1024,
	[ "$pp_colour_colour" ] = 0,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}
local colormod2 = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 255, -- should be 1/255
	[ "$pp_colour_colour" ] = 0,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}
function SingleRender(ent, progressbardata, fuckshit, camstarter)
	renders = renders + 1

	--if renders == 1 or fuckshit then RenderZBuffer() end	-- render depth buffer on first render
	RenderZBuffer()

	cam.Start(camstarter)
		render.Clear(0, 0, 0, 255, false, true)
		ent:DrawModel()
	cam.End()

	-- render.Clear(1, 1, 1, 255)
	render.UpdateScreenEffectTexture()
	DrawColorModify(colormod)	-- all pixels are either 0 or 255 (R=G=B)
	DrawColorModify(colormod2)	-- all pixels are either 0 or 1
	render.UpdateScreenEffectTexture()

	render.PushRenderTarget(tex_render)
		mat_copy:SetTexture("$basetexture", tex_scrfx)
		render.SetMaterial(mat_copy)
		render.DrawScreenQuad()
		-- render.Clear(1, 1, 1, 255)

		-- render.CapturePixels()
		--print(render.ReadPixel(ScrW()/2,ScrH()/2))
	render.PopRenderTarget()


	-- Blend multiple renders together:


			if antialias then
				-- workaround
				render.RenderView()
				render.UpdateScreenEffectTexture()

				render.PushRenderTarget(tex_render)
					if renders == 1 then render.Clear(0, 0, 0, 255) end
					mat_copy:SetTexture("$basetexture", tex_scrfx)
					render.SetMaterial(mat_copy)
					render.DrawScreenQuad()
				render.PopRenderTarget()

			else
				-- give up on anti-aliasing to get better color accuracy in bright areas
				render.PushRenderTarget(tex_blend)--blentint
					if renders == 1 then render.Clear(0, 0, 0, 255) end	-- clear on first render
					-- local br = renders-1
					-- print("writing:",br)
					-- render.Clear(br, br, br, 255)
					-- render.CapturePixels()
					-- local a, b, c = render.ReadPixel(ScrW()/2,ScrH()/2)

					-- Additively paste the current frame onto the blend
					mat_add:SetTexture("$basetexture", tex_render)--tex_renderint
					render.SetMaterial(mat_add)
					render.DrawScreenQuad()

					-- render.CapturePixels()
					-- local d, e, f = render.ReadPixel(ScrW()/2,ScrH()/2)
				render.PopRenderTarget()
			end

	-- mat_copy:SetTexture("$basetexture", tex_blendint)
	-- render.SetMaterial(mat_copy)
	-- render.DrawScreenQuad()

	-- render.CapturePixels()
	-- local g, h, i = render.ReadPixel(ScrW()/2,ScrH()/2)

	--print(renders,"before: ", a, b, c, "after:", d, e, f, "copied:", g, h, i)


	-- Draw progress on the screen so the user can get a sense of progress and know that the game isn't stuck
	-- Put something pretty and technical on the screen:
	-- mat_copy:SetTexture("$basetexture", tex_render)
	-- render.SetMaterial(mat_copy)
	-- render.DrawScreenQuad()

	-- DrawColorModify(colormod)	-- re-brighten the 1 1 1 pixels to 255 255 255 for display on the screen
	-- mat_divide:SetTexture("$fbtexture", tex_blendint)
	-- mat_divide:SetFloat("$pp_colour_contrast", 1/renders)
	-- render.SetMaterial(mat_divide)
	-- render.DrawScreenQuad()

	-- Draw progress bars:
	cam.Start2D()
		local y = ScrH() - 20
		local x = ScrW() / 2
		for k, v in ipairs(progressbardata) do
			-- Grey outline:
			surface.SetDrawColor(50, 50, 50)
			surface.DrawRect(x-301, y-10, 602, 20)
			-- lighter-grey infill:
			surface.SetDrawColor(100, 100, 100)
			surface.DrawRect(x-300, y-9, 600, 18)

			-- Green progress bar:
			local progress = 600 * v.progress / v.max
			surface.SetDrawColor(20, 150, 20)
			surface.DrawRect(x-300, y-9, progress, 18)

			-- Text:
			surface.SetFont("DermaDefault")

			-- Progress bar text (example: 100 / 350)
			local text = v.progress .. " / " .. v.max
			local w, h = surface.GetTextSize(text)
			surface.SetTextPos(x-(w/2), y-(h/2))
			surface.SetTextColor(255, 255, 255)
			surface.DrawText(text)

			-- Title:
			surface.SetTextPos(x-296, y-(h/2))	-- Start of the progress bar
			surface.DrawText(v.title)

			y = y - 50 -- next progress bar is above
		end
	cam.End2D()

	-- Update the screen
	render.Spin()
end

local darken = 1

concommand.Add("poster_darken", function(ply, cmd, args)
	darken = args[1] + 0
	print("Darken set to "..args[1].."!")
end)

local lastRT
local function FinishRender()
	-- Divide the sum of the additive renders by the number of renders to get an average, blended result
	local someparameter = 2100 -- the higher the darker
	local mul = (planes and 1 or 1) / (planes and someparameter or renders)
	local rt = planes and tex_blendint or tex_blend
	rt = tex_blend

	lastRT = rt

	if additive then mul = 1 end

	mul = mul / darken

	render.PushRenderTarget(rt)
		mat_divide:SetTexture("$fbtexture", rt)
		mat_divide:SetFloat("$pp_colour_contrast", mul)
		render.SetMaterial(mat_divide)
		render.DrawScreenQuad()
	render.PopRenderTarget()

	-- copy the blended image onto the framebuffer:
	-- if planes then
	-- 	mat_gmodscreenspace:SetTexture("$basetexture", tex_blend)
	-- 	mat_gmodscreenspace:SetFloat("$alpha", 1)
	-- 	render.SetMaterial(mat_gmodscreenspace)
	-- else
	mat_copy:SetTexture("$basetexture", rt)
	render.SetMaterial(mat_copy)
	-- end
	render.DrawScreenQuad()
	render.DrawScreenQuad()	-- done twice fix bug where the first DrawScreenQuad is ignored for some reason.

	renders = 0	-- reset render count for next frame

	-- let the render end naturally
end

local function FinishRenderV2()
	-- Divide the sum of the additive renders by the number of renders to get an average, blended result
	local someparameter = 2100 -- the higher the darker
	local mul = (planes and 1 or 1) / (planes and someparameter or renders)
	local rt = planes and tex_blendint or tex_blend
	rt = tex_blend

	if additive then mul = 1 end

	mul = mul / darken

	render.PushRenderTarget(rt)
		mat_divide:SetTexture("$fbtexture", rt)
		mat_divide:SetFloat("$pp_colour_contrast", mul)
		render.SetMaterial(mat_divide)
		render.DrawScreenQuad()
	render.PopRenderTarget()

	-- copy the blended image onto the framebuffer:
	-- if planes then
	-- 	mat_gmodscreenspace:SetTexture("$basetexture", tex_blend)
	-- 	mat_gmodscreenspace:SetFloat("$alpha", 1)
	-- 	render.SetMaterial(mat_gmodscreenspace)
	-- else
	mat_copy:SetTexture("$basetexture", rt)
	render.SetMaterial(mat_copy)

	-- end
	render.DrawScreenQuad()
	render.DrawScreenQuad()	-- done twice fix bug where the first DrawScreenQuad is ignored for some reason.

	renders = 0	-- reset render count for next frame

	-- let the render end naturally
end

local function ReFinishRender(postermul, split)

	mul = (planes and 1 or 1) / (planes and someparameter or renders)

	if additive then mul = 1 end

	mul = mul / darken

	rt = tex_blend
	lastRT = rt
	render.PushRenderTarget(lastRT)
		mat_divide:SetTexture("$fbtexture", lastRT)
		mat_divide:SetFloat("$pp_colour_contrast", mul)
		render.SetMaterial(mat_divide)
		render.DrawScreenQuad()
	render.PopRenderTarget()

	mat_copy:SetTexture("$basetexture", lastRT)
	render.SetMaterial(mat_copy)

	render.DrawScreenQuad()
	render.DrawScreenQuad()

	RunConsoleCommand("poster", postermul, split)
end
concommand.Add("poster_redo", function(ply, cmd, args)
	local postermul = args[1]
	ReFinishRender(postermul)
end)

local function AbortLightCount(alllights, postermul)
	local lightlimit = Abort_LightCountVar:GetInt()
	if lightlimit < 1 then return false end
	if alllights > lightlimit then
		surface.PlaySound("buttons/button10.wav")
		notification.AddLegacy("Poster Light amount exceeds limit! Check console for details", NOTIFY_ERROR, 7)
		print("Soft Lamp Render Aborted! Amount of lights exceeds one set by posterabort_lightcount (" .. lightlimit .. ").\nLower lamp's Surface Shape Resolution and Split parameters," .. ((postermul > 1) and " use lower poster resolution," or "") .. " or disable this limit by setting posterabort_lightcount to zero!\n")
		return true
	end
	return false
end

local function AbortTime(limit, starttime)
	if (SysTime() - starttime) > limit then
		surface.PlaySound("buttons/button10.wav")
		notification.AddLegacy("Soft Lamp Render took too long! Check console for details", NOTIFY_ERROR, 7)
		print("Soft Lamp Render Aborted! Render time exceeded limit! (" .. limit .. ").\nYou can disable this limit by setting posterabort_time to zero!\n")
		return true
	end
	return false
end

local function AbortTimePredict(limit, starttime, alllights, curlight)
	local passedtime = SysTime() - starttime
	local estimate = alllights/(curlight/passedtime)
	if estimate > limit then
		surface.PlaySound("buttons/button10.wav")
		notification.AddLegacy("Soft Lamp Render may take too long! Check console for details", NOTIFY_ERROR, 7)
		print("Soft Lamp Render Aborted! Predicted Render time exceeded limit! (estimated " .. estimate .. ", limit " .. limit .. ").\nYou can disable this limit by setting posterabort_time or posterabort_time_predict to zero!\n")
		return true
	end
	return false
end

local function StoreProjectedTextures(count)
	---@type ProjectedTexture[]
	local pts = {}
	for _ = 1, count do
		local pt = ProjectedTexture()
		pt:SetBrightness(0)
		pt:SetFOV(0)
		pt:Update()
		table.insert(pts, pt)
	end

	return pts, function()
		for _, pt in ipairs(pts) do
			pt:Remove()
		end
	end
end

local function SoftPoster(postermul, split)
--	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul --+ extra	-- number of calls of the render hook that need to be hooked, sometimes 1 extra called pre-poster for some reason (not always?)
	local starttime = SysTime()	-- benchmarking + feedback
	local timelimit, predicttime = Abort_TimeVar:GetFloat(), Abort_PredictTimeVar:GetBool()

	---@type {[gmod_softlamp]: integer}
	local lights = {}
	---@type gmod_softlamp[]
	local softlamps = ents.FindByClass("gmod_softlamp")
	local frustrumCheck = checkfrustrum:GetBool()
	local frustrumFarZ = checkfrustrum_farz:GetFloat()

	local viewFrustrum
	if frustrumCheck then
		local view = render.GetViewSetup()
		view.zfar = frustrumFarZ > 0 and frustrumFarZ or view.zfar
		viewFrustrum = frustrum.get(view)
	end

	local lightcount = 0
	for k, lamp in pairs(softlamps) do
		if !lamp:GetHeavyOn() then continue end
		if not lamp:GetAlwaysRender() and frustrumCheck then
			local lampFrustrum = frustrum.get({
				fov_unscaled = lamp:GetLightFOV(),
				origin = lamp:LocalToWorld(lamp:GetLightOffset()),
				angles = lamp:GetAngles(),
				znear = lamp:GetNearZ(),
				zfar = lamp:GetFarZ(),
				aspect = 1,
			})
			if not frustrum.intersectsFrustrum(viewFrustrum, lampFrustrum) then continue end
		end

		local c = lamp:HeavyLightCount()
		lightcount = lightcount + c
		lights[lamp] = c
	end

	local alllights = lightcount * callsleft
	if AbortLightCount(alllights, callsleft) then return end

	for lamp, c in pairs(lights) do
		-- The thing about brightness:
		-- The scene will be rendered lightcount times.
		-- Each lamp must actually be brighter because it will not be on every render.
		if c > 0 then
			local bright = lamp:GetBrightness() / 6.5
			local mul = lightcount / c

			lights[lamp] = bright * mul
		end
	end

	local progressbar = {
		{
			title = "Poster",
			progress = 0,
			max = callsleft
		},
		{
			title = "Soft Shadows",
			progress = 0,
			max = lightcount
		}
	}

	local abort = false

	local lampc = lampcount:GetInt()
	if lampc < 1 then lampc = 1 end
	
	local pts, removePTs = StoreProjectedTextures(lampc)

	hook.Add("RenderScene", "SoftPoster", function(ViewOrigin, ViewAngles, ViewFOV)
		progressbar[1].progress = progressbar[1].progress + 1

		i = 0

		for lamp in pairs(lights) do
			lamp:HeavyLightPrepare()
		end

		for lamp, brightness in pairs(lights) do
			if abort then break end

			lamp:HeavyLightStart(brightness, nil, nil, pts)
			local lightc = lamp:HeavyLightCount()
			local lightadd = 0

			while lamp:HeavyLightTick(nil, pts) do
				if (timelimit > 0) and not abort then
					abort = AbortTime(timelimit, starttime)
				end
				if abort then break end
				local newadd = math.min(lightadd + lampc, lightc)
				local diff = newadd - lightadd
				lightadd = newadd
				progressbar[2].progress = i + lightadd
				DoRender(progressbar, diff)
				if predicttime and (((i + lightadd) % 10) == 0) and (timelimit > 0) and not abort then
					abort = AbortTimePredict(timelimit, starttime, alllights, i + lightadd + lightcount*(progressbar[1].progress-1))
				end
			end
			i = i + lightadd
		end
		-- Still capture something if we don't have any soft lamps
		if i == 0 then
			DoRender(progressbar)
		end
		FinishRender()

		callsleft = callsleft - 1
		if (callsleft <= 0) then
			hook.Remove("RenderScene","SoftPoster")

			removePTs()

			local endtime = SysTime()
			print("Poster finished with the following values:")
			print("", "Render Time: ", endtime-starttime .. " seconds.")
			print("", "Darkness: ", darken)
			print("", "Additive: ", additive or false)
			print("", "Anti-Aliasing: ", antialias)
		end
		
		return true
	end)
	
	RunConsoleCommand("poster", postermul, split)
end

local function SoftPosterV2(postermul, split) -- V2 versions of these things exist to be able to fuck around and find out without messing up previous use working stuff
--	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul --+ extra	-- number of calls of the render hook that need to be hooked, sometimes 1 extra called pre-poster for some reason (not always?)
	local starttime = SysTime()	-- benchmarking + feedback
	local timelimit, predicttime = Abort_TimeVar:GetFloat(), Abort_PredictTimeVar:GetBool()

	---@type {[gmod_softlamp]: integer}
	local lights = {}
	---@type gmod_softlamp[]
	local softlamps = ents.FindByClass("gmod_softlamp")
	local frustrumCheck = checkfrustrum:GetBool()
	local frustrumFarZ = checkfrustrum_farz:GetFloat()

	local viewFrustrum
	if frustrumCheck then
		local view = render.GetViewSetup()
		view.zfar = frustrumFarZ > 0 and frustrumFarZ or view.zfar
		viewFrustrum = frustrum.get(view)
	end

	local lightcount = 0
	for k, lamp in pairs(softlamps) do
		if !lamp:GetHeavyOn() then continue end
		if not lamp:GetAlwaysRender() and frustrumCheck then
			local lampFrustrum = frustrum.get({
				fov_unscaled = lamp:GetLightFOV(),
				origin = lamp:LocalToWorld(lamp:GetLightOffset()),
				angles = lamp:GetAngles(),
				znear = lamp:GetNearZ(),
				zfar = lamp:GetFarZ(),
				aspect = 1,
			})
			if not frustrum.intersectsFrustrum(viewFrustrum, lampFrustrum) then continue end
		end

		local c = lamp:HeavyLightCount()
		lightcount = lightcount + c
		lights[lamp] = c
	end

	local alllights = lightcount * callsleft
	if AbortLightCount(alllights, callsleft) then return end

	for lamp, c in pairs(lights) do
		-- The thing about brightness:
		-- The scene will be rendered lightcount times.
		-- Each lamp must actually be brighter because it will not be on every render.
		if c > 0 then
			local bright = lamp:GetBrightness() / 6.5
			local mul = lightcount / c

			lights[lamp] = bright * mul
		end
	end

	local progressbar = {
		{
			title = "Poster",
			progress = 0,
			max = callsleft
		},
		{
			title = "Soft Shadows",
			progress = 0,
			max = lightcount
		}
	}

	local abort = false

	local lampc = lampcount:GetInt()
	if lampc < 1 then lampc = 1 end

	local pts, removePTs = StoreProjectedTextures(lampc)

	hook.Add("RenderScene", "SoftPoster", function(ViewOrigin, ViewAngles, ViewFOV)
		progressbar[1].progress = progressbar[1].progress + 1

		i = 0

		for lamp in pairs(lights) do
			lamp:HeavyLightPrepare()
		end

		for lamp, brightness in pairs(lights) do
			if abort then break end

			lamp:HeavyLightStart(brightness, nil, nil, pts)
			local lightc = lamp:HeavyLightCount()
			local lightadd = 0

			while lamp:HeavyLightTick(nil, pts) do
				if (timelimit > 0) and not abort then
					abort = AbortTime(timelimit, starttime)
				end
				if abort then break end
				local newadd = math.min(lightadd + lampc, lightc)
				local diff = newadd - lightadd
				lightadd = newadd
				progressbar[2].progress = i + lightadd
				DoRenderV2(progressbar, diff)
				if predicttime and (((i + lightadd) % 10) == 0) and (timelimit > 0) and not abort then
					abort = AbortTimePredict(timelimit, starttime, alllights, i + lightadd + lightcount*(progressbar[1].progress-1))
				end
			end
			i = i + lightadd
		end
		-- Still capture something if we don't have any soft lamps
		if i == 0 then
			DoRenderV2(progressbar)
		end
		FinishRenderV2()

		callsleft = callsleft - 1
		if (callsleft <= 0) then
			hook.Remove("RenderScene","SoftPoster")

			removePTs()

			local endtime = SysTime()
			print("Poster finished with the following values:")
			print("", "Render Time: ", endtime-starttime .. " seconds.")
			print("", "Darkness: ", darken)
			print("", "Additive: ", additive or false)
			print("", "Anti-Aliasing: ", antialias)
			RunConsoleCommand("poster", postermul, split)
		end

		return true
	end)

end

local function GodRaysPoster(godrays, postermul, passes, split, shapemem)
	godrays = tonumber(godrays)	-- convert to number
	passes = tonumber(passes) or 1

--	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul	-- number of calls of the render hook that need to be hooked, 1 extra called pre-poster for some reason (not always?)
	local starttime = SysTime()	-- benchmarking + feedback

	local lights = {}
	local softlamps = ents.FindByClass("gmod_softlamp")

	local lightcount = 0
	for k, lamp in pairs(softlamps) do
		if !lamp:GetHeavyOn() then continue end
		local c = lamp:HeavyLightCount()
		lightcount = lightcount + c
		lights[lamp] = c
	end

	for lamp, c in pairs(lights) do
		-- The thing about brightness:
		-- The scene will be rendered lightcount times.
		-- Each lamp must actually be brighter because it will not be on every render.
		if c > 0 then
			local bright = lamp:GetBrightness()
			local mul = lightcount / c

			lights[lamp] = bright * mul
		end
	end

	local w, h = ScrW(), ScrH()
	local camstarts = {}

	for y = 0, postermul-1 do
		for x = 0, postermul-1 do
			local tab = {offcenter = {}}
			tab.offcenter.left = (x/(postermul)) * w
			tab.offcenter.right = ((x+1)/postermul) * w
			tab.offcenter.top = (1-((y+1)/postermul)) * h
			tab.offcenter.bottom = (1-(y/postermul)) * h

			table.insert(camstarts, tab)
		end
	end


	local progressbar = {
		{
			title = "Poster",
			progress = 0,
			max = callsleft
		},
		{
			title = "Passes",
			progress = 0,
			max = lightcount*passes
		},
		{
			title = "Godrays",
			progress = 0,
			max = godrays
		}
	}

	local i = 0
	hook.Add("RenderScene", "SoftPoster", function(ViewOrigin, ViewAngles, ViewFOV)
--[[		if extra > 0 then
			extra = extra - 1
			return true
		end]]
		i = i + 1

		progressbar[1].progress = progressbar[1].progress + 1

		for lamp in pairs(lights) do
			lamp:HeavyLightPrepare()
		end

		local j = 0

		for lamp, brightness in pairs(lights) do
			lamp:HeavyLightStart(brightness, godrays, passes)
			j = j + 1

			local cont, vlp, vlpindex, vlpass = lamp:HeavyLightTick(ViewAngles)
			local lastpass = 1
			while cont do
				progressbar[2].progress = j + vlpass-1
				progressbar[3].progress = vlpindex

				-- enttorender:SetLocalPos(Vector(math.Remap(vlpindex,1,vlpmax,0,100), 0, 0))
				-- enttorender:SetupBones()
				-- lamp.HeavyLightPT:Update()
				-- SingleRender(enttorender, progressbar)
				SingleRender(vlp, progressbar, vlpindex == 1, camstarts[i])
				-- DoRender(progressbar)

				cont, vlp, vlpindex, vlpass = lamp:HeavyLightTick(ViewAngles)
				lastpass = vlpass or lastpass
			end
			j = j + lastpass-1
		end
		FinishRender(false)

		callsleft = callsleft - 1
		if (callsleft <= 0) then
			hook.Remove("RenderScene", "SoftPoster")

			local endtime = SysTime()
			print("Poster finished with the following values:")
			print("", "Render Time: ", endtime-starttime .. " seconds.")
			print("", "Darkness: ", darken)
			print("", "Additive: ", additive or false)
			print("", "Anti-Aliasing: ", antialias)

			for lamp, tab in pairs(shapemem) do
				print("Resetting " .. tostring(lamp) .. " Surface Shape Resolution to " .. tostring(tab[1]) .. " and Lamp Split to " .. tostring(tab[2]))
				lamp:SetHeavyLayers(tab[1])
				lamp:SetHeavySplit(tab[2])
			end
		end

		return true
	end)

	RunConsoleCommand("poster", postermul, split)
end

-- CONSOLE COMMANDS
local function InternalConCommand(ply, cmd, args)
	SoftPoster(unpack(args))
end

concommand.Add("poster_soft", function(ply, cmd, args)
	--antialias = false
	if #args < 1 then
		print("poster_soft <poster size> <poster split>")
		return
	end

	SoftPoster(unpack(args))
end)--, nil, nil, FCVAR_SPONLY)

concommand.Add("poster_soft_v2", function(ply, cmd, args)
	--antialias = false
	if #args < 1 then
		print("poster_soft_v2 <poster size> <poster split>")
		return
	end

	SoftPosterV2(unpack(args))
end)--, nil, nil, FCVAR_SPONLY)

concommand.Add("poster_godrays", function(ply, cmd, args)
	if #args < 2 then
		print("poster_godrays <accuracy> <poster size> <godray passes = 1> <poster split>")
		return
	end

	local shapemem = {}
	local softlamps = ents.FindByClass("gmod_softlamp")

	for k, lamp in pairs(softlamps) do
		if !lamp:GetHeavyOn() then continue end
		if lamp:GetHeavyLayers() ~= 1 or lamp:GetHeavySplit() ~= 1 then
			shapemem[lamp] = {lamp:GetHeavyLayers(), lamp:GetHeavySplit()}
			print(tostring(lamp) .. " Surface Shape Resolution is set to " .. tostring(shapemem[lamp][1]) .. " and Lamp Split is set to " .. tostring(shapemem[lamp][2]) .. ", setting them to 1 for the godrays render")
			lamp:SetHeavyLayers(1)
			lamp:SetHeavySplit(1)
		end
	end

	GodRaysPoster(args[1], args[2], args[3], args[4], shapemem)
end)--, nil, nil, FCVAR_SPONLY)

local GlobalNearZ = 5
concommand.Add("poster_lightbounce_nearz_override", function(ply, cmd, args)
	GlobalNearZ = args[1] + 0
end)

--[[---------------------------
untested because who the fuck
tests stuff before  releasing
it? hope it  works  and  hope
it looks awesome :D
--]]---------------------------

hook.Remove("PreDrawEffects", "DrawFrustrum")
-- hook.Add("PreDrawEffects", "DrawFrustrum", function()
-- 	local viewsetup = render.GetViewSetup()
-- 	viewsetup.zfar = checkfrustrum_farz:GetFloat() > 0 and checkfrustrum_farz:GetFloat() or viewsetup.zfar
-- 	local view = frustrum.get(viewsetup)
-- 	for key, center in pairs(view.centers) do
-- 		debugoverlay.Axis(center, view.planes[key]:Angle(), checkfrustrum_farz:GetFloat(), 0.2, true)
-- 	end
-- end)

hook.Remove("RenderScene","SoftPoster")
local function LightBouncePoster( lightsize, lightbright, lightpasses, postermul, split, depthres )
--	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul --+ extra	-- number of calls of the render hook that need to be hooked, sometimes 1 extra called pre-poster for some reason (not always?)
	local starttime = SysTime()	-- benchmarking + feedback

	local amt = 0
	for _, v in pairs(SoftLampsBounceTable) do
		for _, _ in pairs(v) do
			amt = amt + 1
		end
	end

	lightpasses = math.max(lightpasses, 1)

	local progressbar = {
		{
			title = "Poster",
			progress = 0,
			max = callsleft
		},
		{
			title = "Bounces",
			progress = 0,
			max = amt
		}
	}


	local PT = ProjectedTexture
	local PTs = {}

		PTs.up, PTs.dn, PTs.lt, PTs.rt, PTs.ft, PTs.bk = PT(), PT(), PT(), PT(), PT(), PT()

		PTs.up:SetAngles(Angle(90, 0, 0))
		PTs.dn:SetAngles(Angle(-90, 0, 0))
		PTs.lt:SetAngles(Angle(0, 90, 0))
		PTs.rt:SetAngles(Angle(0, -90, 0))
		PTs.ft:SetAngles(Angle(0, 0, 0))
		PTs.bk:SetAngles(Angle(0, 180, 0))

	lightsize = lightsize + 0
	for _, pt in pairs(PTs) do
		pt:SetTexture("effects/flashlight/square")--"models/debug/debugwhite")
		pt:SetColor(Color(0, 0, 0))
		pt:SetBrightness((lightbright + 0)/lightpasses)	-- +0 to convert from string to number
		pt:SetEnableShadows(true)
		pt:SetNearZ(GlobalNearZ)
		pt:SetFarZ(lightsize + 0)	-- +0 to convert from string to number
		pt:SetFOV(98.5)	-- works well with effects/flashlight/square IIRC

		-- Set proper attenuation
		pt:SetConstantAttenuation(matchAttenuation(lightattenuation:GetString(), "constant") * lightsize)
		pt:SetLinearAttenuation(matchAttenuation(lightattenuation:GetString(), "linear") * lightsize)
		pt:SetQuadraticAttenuation(matchAttenuation(lightattenuation:GetString(), "quadratic") * lightsize)
		pt:Update()
	end
	local frustrumCheck = checkfrustrum:GetBool()
	local frustrumFarZ = checkfrustrum_farz:GetFloat()

	local viewFrustrum
	if frustrumCheck then
		local view = render.GetViewSetup()
		view.zfar = frustrumFarZ > 0 and frustrumFarZ or view.zfar
		viewFrustrum = frustrum.get(view)
	end

	hook.Add("RenderScene", "SoftPoster", function(ViewOrigin, ViewAngles, ViewFOV)
		progressbar[1].progress = progressbar[1].progress + 1

		i = 0

		for _, lamp in pairs(ents.FindByClass("gmod_softlamp")) do
			lamp:ClearFlashlights()
		end

		for _, PixTable in pairs(SoftLampsBounceTable) do
			for _, bounce in pairs(PixTable) do
				i = i + 1
				progressbar[2].progress = i
				if frustrumCheck and not frustrum.intersectsSphere(viewFrustrum, bounce.Pos, lightsize) then continue end

				for s = 1, lightpasses do
					if (lightsize/s > 5) then
						for a, pt in pairs(PTs) do
							pt:SetColor(bounce.Col)
							pt:SetPos(bounce.Pos)
							pt:SetFarZ(lightsize/s)
							pt:Update()
						end

						DoRender(progressbar)
					end
				end
			end
		end
		-- Still capture something if we don't have any soft lamps
		if i == 0 then
			DoRender(progressbar)
		end
		FinishRender()

		callsleft = callsleft - 1
		if (callsleft <= 0) then
			hook.Remove("RenderScene","SoftPoster")

			for _, pt in pairs(PTs) do
				pt:Remove()
			end

			local endtime = SysTime()
			print("Poster finished with the following values:")
			print("", "Render Time: ", endtime-starttime .. " seconds.")
			print("", "Darkness: ", darken)
			print("", "Additive: ", additive or false)
			print("", "Anti-Aliasing: ", antialias)

			if depthres then
				print("Restoring flashlightdepthres!")
				RunConsoleCommand("r_flashlightdepthres", depthres)
			end
		end

		return true
	end)

	RunConsoleCommand("poster", postermul, split)
end

local function LightBouncePosterV2( lightsize, lightbright, lightpasses, postermul, split, depthres )
--	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul --+ extra	-- number of calls of the render hook that need to be hooked, sometimes 1 extra called pre-poster for some reason (not always?)
	local starttime = SysTime()	-- benchmarking + feedback

	local amt = 0
	for _, v in pairs(SoftLampsBounceTable) do
		for _, _ in pairs(v) do
			amt = amt + 1
		end
	end

	lightpasses = math.max(lightpasses, 1)

	local progressbar = {
		{
			title = "Poster",
			progress = 0,
			max = callsleft
		},
		{
			title = "Bounces",
			progress = 0,
			max = amt
		}
	}


	local PT = ProjectedTexture
	local PTs = {}

		PTs.up, PTs.dn, PTs.lt, PTs.rt, PTs.ft, PTs.bk = PT(), PT(), PT(), PT(), PT(), PT()

		PTs.up:SetAngles(Angle(90, 0, 0))
		PTs.dn:SetAngles(Angle(-90, 0, 0))
		PTs.lt:SetAngles(Angle(0, 90, 0))
		PTs.rt:SetAngles(Angle(0, -90, 0))
		PTs.ft:SetAngles(Angle(0, 0, 0))
		PTs.bk:SetAngles(Angle(0, 180, 0))

	lightsize = lightsize + 0
	for _, pt in pairs(PTs) do
		pt:SetTexture("effects/flashlight/square")--"models/debug/debugwhite")
		pt:SetColor(Color(0, 0, 0))
		pt:SetBrightness((lightbright + 0)/lightpasses)	-- +0 to convert from string to number
		pt:SetEnableShadows(true)
		pt:SetNearZ(GlobalNearZ)
		pt:SetFarZ(lightsize + 0)	-- +0 to convert from string to number
		pt:SetFOV(98.5)	-- works well with effects/flashlight/square IIRC

		-- Set proper attenuation
		pt:SetConstantAttenuation(matchAttenuation(lightattenuation:GetString(), "quadratic") * lightsize)
		pt:SetLinearAttenuation(matchAttenuation(lightattenuation:GetString(), "quadratic") * lightsize)
		pt:SetQuadraticAttenuation(matchAttenuation(lightattenuation:GetString(), "quadratic") * lightsize)
		pt:Update()
	end
	local frustrumCheck = checkfrustrum:GetBool()
	local frustrumFarZ = checkfrustrum_farz:GetFloat()

	local viewFrustrum
	if frustrumCheck then
		local view = render.GetViewSetup()
		view.zfar = frustrumFarZ > 0 and frustrumFarZ or view.zfar
		viewFrustrum = frustrum.get(view)
	end

	hook.Add("RenderScene", "SoftPoster", function(ViewOrigin, ViewAngles, ViewFOV)
		progressbar[1].progress = progressbar[1].progress + 1

		i = 0

		for _, lamp in pairs(ents.FindByClass("gmod_softlamp")) do
			lamp:ClearFlashlights()
		end

		for _, PixTable in pairs(SoftLampsBounceTable) do
			for _, bounce in pairs(PixTable) do
				i = i + 1
				progressbar[2].progress = i
				if frustrumCheck and not frustrum.intersectsSphere(viewFrustrum, bounce.Pos, lightsize) then continue end

				for s = 1, lightpasses do
					if (lightsize/s > 5) then
						for a, pt in pairs(PTs) do
							pt:SetColor(bounce.Col)
							pt:SetPos(bounce.Pos)
							pt:SetFarZ(lightsize/s)
							pt:Update()
						end

						DoRenderV2(progressbar)
					end
				end
			end
		end
		-- Still capture something if we don't have any soft lamps
		if i == 0 then
			DoRenderV2(progressbar)
		end
		FinishRenderV2()

		callsleft = callsleft - 1
		if (callsleft <= 0) then
			hook.Remove("RenderScene","SoftPoster")

			for _, pt in pairs(PTs) do
				pt:Remove()
			end

			local endtime = SysTime()
			print("Poster finished with the following values:")
			print("", "Render Time: ", endtime-starttime .. " seconds.")
			print("", "Darkness: ", darken)
			print("", "Additive: ", additive or false)
			print("", "Anti-Aliasing: ", antialias)

			if depthres then
				print("Restoring flashlightdepthres!")
				RunConsoleCommand("r_flashlightdepthres", depthres)
			end
		end

		return true
	end)

	RunConsoleCommand("poster", postermul, split)
end

lightbounce_depthres = 1024

concommand.Add("poster_lightbounce_depthres_override", function(ply, cmd, args)
	lightbounce_depthres = args[1] + 0
end)

concommand.Add("poster_lightbounce", function(ply, cmd, args)
	if #args < 3 then print("poster_lightbounce <lightsize> <lightbrightness> <postersize> <postersplit>") return end

	local cvflashlightdepthres = GetConVar("r_flashlightdepthres")
	local depthres = cvflashlightdepthres:GetInt()
	if depthres ~= lightbounce_depthres then
		print("r_flashlightdepthres is "..depthres.." ! Setting it to "..lightbounce_depthres.." ! Don't forget to turn off all lights before doing lightbounce")
		RunConsoleCommand("r_flashlightdepthres", lightbounce_depthres)

		LightBouncePoster(args[1], args[2], 1, args[3], args[4], depthres)
	else
		-- There used to be a 3rd argument, <lightpasses>. It has been disabled and set to always be 1.
		LightBouncePoster(args[1], args[2], 1, args[3], args[4])
	end
end)--, nil, nil, FCVAR_SPONLY)

concommand.Add("poster_lightbounce_v2", function(ply, cmd, args)
	if #args < 3 then print("poster_lightbounce_v2 <lightsize> <lightbrightness> <postersize> <postersplit>") return end

	local cvflashlightdepthres = GetConVar("r_flashlightdepthres")
	local depthres = cvflashlightdepthres:GetInt()
	if depthres ~= lightbounce_depthres then
		print("r_flashlightdepthres is "..depthres.." ! Setting it to "..lightbounce_depthres.." ! Don't forget to turn off all lights before doing lightbounce")
		RunConsoleCommand("r_flashlightdepthres", lightbounce_depthres)

		LightBouncePosterV2(args[1], args[2], 1, args[3], args[4], depthres)
	else
		-- There used to be a 3rd argument, <lightpasses>. It has been disabled and set to always be 1.
		LightBouncePosterV2(args[1], args[2], 1, args[3], args[4])
	end
end)--, nil, nil, FCVAR_SPONLY)
