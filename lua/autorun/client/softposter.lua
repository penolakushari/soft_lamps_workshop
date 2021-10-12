--print("\tIF YOU SEE THIS TELL NEATNIT!! SoftPoster just got loaded!")
local extraframes = CreateClientConVar("poster_extraframes", "0")

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


local function DoRender(progressbardata)
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

	renders = renders + 1

	-- Blend multiple renders together:
	render.PushRenderTarget(tex_blend)
		if renders == 1 then render.Clear(0, 0, 0, 255) end	-- clear on first render

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

	//if renders == 1 or fuckshit then RenderZBuffer() end	-- render depth buffer on first render
	RenderZBuffer()

	cam.Start(camstarter)
		render.Clear(0, 0, 0, 255, false, true)
		ent:DrawModel()
	cam.End()

	-- render.Clear(1, 1, 1, 255)


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


local function SoftPoster(postermul, split)
	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul + extra	-- number of calls of the render hook that need to be hooked, sometimes 1 extra called pre-poster for some reason (not always?)
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


	hook.Add("RenderScene", "SoftPoster", function(ViewOrigin, ViewAngles, ViewFOV)
		progressbar[1].progress = progressbar[1].progress + 1

		for lamp, brightness in pairs(lights) do
			lamp:HeavyLightStart(brightness)
		end

		i = 0

		for lamp in pairs(lights) do
			while lamp:HeavyLightTick() do
				i = i + 1
				progressbar[2].progress = i
				DoRender(progressbar)
			end
		end
		FinishRender()

		callsleft = callsleft - 1
		if (callsleft <= 0) then
			hook.Remove("RenderScene","SoftPoster")

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

local function GodRaysPoster(godrays, postermul, split)
	godrays = godrays + 0	-- convert to number

	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul	-- number of calls of the render hook that need to be hooked, 1 extra called pre-poster for some reason (not always?)
	local starttime = SysTime()	-- benchmarking + feedback

	local lights = {}
	local softlamps = ents.FindByClass("gmod_softlamp")

	local lightcount = 0
	for k, lamp in pairs(softlamps) do
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
			title = "Soft Lamps",
			progress = 0,
			max = lightcount
		},
		{
			title = "Godrays",
			progress = 0,
			max = godrays
		}
	}

	local i = 0
	hook.Add("RenderScene", "SoftPoster", function(ViewOrigin, ViewAngles, ViewFOV)
		if extra > 0 then
			extra = extra - 1
			return true
		end
		i = i + 1

		progressbar[1].progress = progressbar[1].progress + 1

		for lamp, brightness in pairs(lights) do
			lamp:HeavyLightStart(brightness, godrays)
		end

		for lamp in pairs(lights) do
			local cont, ptindex, ptmax, vlp, vlpindex, vlpmax = lamp:HeavyLightTick()
			while cont do
				progressbar[2].progress = ptindex
				progressbar[2].max = ptmax

				progressbar[3].progress = vlpindex
				progressbar[3].max = vlpmax

				-- enttorender:SetLocalPos(Vector(math.Remap(vlpindex,1,vlpmax,0,100), 0, 0))
				-- enttorender:SetupBones()
				-- lamp.HeavyLightPT:Update()
				-- SingleRender(enttorender, progressbar)
				SingleRender(vlp, progressbar, vlpindex == 1, camstarts[i])
				-- DoRender(progressbar)

				cont, ptindex, ptmax, vlp, vlpindex, vlpmax = lamp:HeavyLightTick()
			end
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
	//antialias = false
	if #args < 1 then
		print("poster_soft <poster size> <poster split>")
		return
	end
	SoftPoster(unpack(args))
end)--, nil, nil, FCVAR_SPONLY)

concommand.Add("poster_godrays", function(ply, cmd, args)
	if #args < 2 then
		print("poster_godrays <accuracy> <poster size> <poster split>")
		return
	end
	GodRaysPoster(unpack(args))
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

local function LightBouncePoster( lightsize, lightbright, lightpasses, postermul, split )
	local extra = extraframes:GetInt()
	local callsleft = postermul * postermul + extra	-- number of calls of the render hook that need to be hooked, sometimes 1 extra called pre-poster for some reason (not always?)
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
		pt:SetColor(Color(255, 255, 0))
		pt:SetBrightness((lightbright + 0)/lightpasses)	// +0 to convert from string to number
		pt:SetEnableShadows(true)
		pt:SetNearZ(GlobalNearZ)
		pt:SetFarZ(lightsize + 0)	// +0 to convert from string to number
		pt:SetFOV(98.5)	-- works well with effects/flashlight/square IIRC

		-- Set proper attenuation
		pt:SetConstantAttenuation(0)
		pt:SetLinearAttenuation(0)
		pt:SetQuadraticAttenuation(lightsize)
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

				for s = 1, lightpasses do
					if (lightsize/s > 5) then
						for a, pt in pairs(PTs) do
							pt:SetColor(Color(255, 255, 255))
							pt:SetPos(bounce.Pos)
							pt:SetFarZ(lightsize/s)
							pt:Update()
						end

						DoRender(progressbar)
					end
				end
			end
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

	local flashlightdepthres = GetConVar("r_flashlightdepthres"):GetInt()
	if flashlightdepthres != lightbounce_depthres then
		print("r_flashlightdepthres is "..flashlightdepthres.." ! Set it to "..lightbounce_depthres.." ! Don't forget to turn off all lights before doing so!")
		return
	end

	-- There used to be a 3rd argument, <lightpasses>. It has been disabled and set to always be 1.
	LightBouncePoster(args[1], args[2], 1, args[3], args[4])
end)--, nil, nil, FCVAR_SPONLY)
