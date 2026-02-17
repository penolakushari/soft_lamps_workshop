AddCSLuaFile("softlamps/client/fzy.lua")
---@module "softlamps.client.fzy"
local fzy = include("softlamps/client/fzy.lua")

---@class SoftLamp: ENT
---@field SetHeavyOn fun(self: SoftLamp, enabled: boolean)
---@field GetHeavyOn fun(self: SoftLamp): enabled: boolean
---@field SetOn fun(self: SoftLamp, enabled: boolean)
---@field GetOn fun(self: SoftLamp): enabled: boolean
---@field hovered boolean

local SOURCE_URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=2044112738"
local SOFTLAMPS_BANDWIDTH = 50 -- softlamps per tick (1000 hz)

GetAllSoftLamps = nil
local SOFTLAMP_ENTITY = "gmod_softlamp"
do
	local findByClass = ents.FindByClass
	---@return SoftLamp[]
	function GetAllSoftLamps()
		return findByClass(SOFTLAMP_ENTITY)
	end
end

local function wrapNumber(x, min, max)
	local d = max - min
	return x == max and x or ((x - min) % d + d) % d + min
end

---@class SoftLampData
---@field LightOffset Vector
---@field Color Color
---@field LightColor Vector
---@field Brightness number
---@field Model string
---@field Pos Vector World position
---@field Ang Angle World angle
---@field NearZ number
---@field FarZ number
---@field FlashlightTexture string
---@field FocalDistance number Focal point distance
---@field LightFOV number
---@field HeavyOn boolean
---@field ShapeRadius number Heavy light radius
---@field HeavyShape string Heavy light shape
---@field HeavyLayers number Heavy light layers
---@field On boolean
---@field GameplayShape string Heavy light shape
---@field GameplayLayers number Heavy light layers
---@field LinearAttenuation number Linear attenuation
---@field QuadraticAttenuation number Quadratic attenuation
---@field ConstantAttenuation number Constant attenuation
---@field EnableOrthographic boolean
---@field OrthoLeft number
---@field OrthoRight number
---@field OrthoTop number
---@field OrthoBottom number

---@param lamp any
---@return SoftLampData
local function getSoftLampData(lamp)
	local lampData = lamp:GetNetworkVars()
	local external = {
		Color = lamp:GetColor(),
		Pos = lamp:GetPos(),
		Ang = lamp:GetAngles(),
		Model = lamp:GetModel()
	}

	return table.Merge(lampData, external)
end

---@param softlamp SoftLamp
---@return string
local function getSoftLampState(softlamp)
	local state = "disabled"
	if softlamp:GetHeavyOn() and softlamp:GetOn() then
		state = "enabled"
	elseif softlamp:GetHeavyOn() then
		state = "heavylight"
	elseif softlamp:GetOn() then
		state = "gameplay"
	end

	return state
end

local states = {
	"disabled",
	"heavylight",
	"gameplay",
	"enabled",
}
local stateMap = table.Flip(states)
local stateBitCount = math.ceil(math.log(#states + 1, 2))

---@param softlamp SoftLamp
---@param state string
local function setSoftLampState(softlamp, state)
	if state == "enabled" then
		softlamp:SetOn(true)
		softlamp:SetHeavyOn(true)
	elseif state == "heavylight" then
		softlamp:SetOn(false)
		softlamp:SetHeavyOn(true)
	elseif state == "gameplay" then
		softlamp:SetOn(true)
		softlamp:SetHeavyOn(false)
	else
		softlamp:SetOn(false)
		softlamp:SetHeavyOn(false)
	end

	if CLIENT then
		net.Start("softlamp_state")
			net.WriteEntity(softlamp)
			net.WriteUInt(stateMap[state], stateBitCount)
		net.SendToServer()
	end
end

if CLIENT then
	SoftLampHoveredVar = SoftLampHoveredVar or nil -- This is also defined in Soft Lamp Manager client - to get when we hover over lamp panel

	CreateClientConVar("softlamps_count", "0")
	hook.Add("SoftLamp_EntityAdded", "SoftLampUpdateCount", function()
		local softlamps = #GetAllSoftLamps()
		RunConsoleCommand("softlamps_count", tostring(softlamps))
	end)

	hook.Add("SoftLamp_EntityRemoved", "SoftLampUpdateCount", function()
		local softlamps = #GetAllSoftLamps()
		RunConsoleCommand("softlamps_count", tostring(softlamps))
	end)

	concommand.Add("lightspray_count", function()
		if not istable(SoftLampsBounceTable) then
			return
		end

		local count = 0
		for _, data in ipairs(SoftLampsBounceTable) do
			count = count + table.Count(data)
		end
		MsgC(color_white, count, "\n")
	end, nil, "Count the number of light bounces from Light Spray (does not include light bounces from Soft Lamps)")

	concommand.Add("lightbounce_count", function()
		if not istable(SoftLampsBounceTable) then
			return
		end
		local count = 0
		for _, data in pairs(SoftLampsBounceTable) do
			count = count + table.Count(data)
		end
		MsgC(color_white, count, "\n")
	end, nil, "Count all light bounces (includes count from lightspray_count)")

	---@param bounceTable table
	---@return string bounceString
	local function serializeBounce(bounceTable)
		local serializedBounce = {}
		for key, bounceData in pairs(bounceTable) do
			if isentity(key) then
				key = tostring(key)
			end
			serializedBounce[key] = table.Copy(bounceData)

			for _, pixData in pairs(serializedBounce[key]) do
				pixData.Col.a = nil
			end
		end

		return util.TableToJSON(serializedBounce)
	end

	---@param path string
	---@param root string
	local function createDirectoriesFromPath(path, root)
		local splitPath = string.Split(path, "/")
		local count = #splitPath
		if count > 1 then
			local currentPath = root
			for i, name in ipairs(splitPath) do
				currentPath = currentPath .. "/" .. name
				if i ~= count and not file.Exists(currentPath, "DATA") then
					file.CreateDir(currentPath)
				end
			end
		end
	end

	---@param path string
	---@return string
	local function parsePathToLoad(path, root)
		if not string.find(path, root) then
			path = root .. "/" .. path
		end
		if string.GetExtensionFromFilename(path) ~= "txt" then
			path = path .. ".txt"
		end

		return path
	end

	---@param path string
	---@param root string
	---@param data string
	---@return boolean?, string
	local function writePathToTextFile(path, root, data)
		if string.GetExtensionFromFilename(path) ~= ".txt" then
			path = path .. ".txt"
		end

		local fullPath = root .. "/" .. path
		local success = file.Write(fullPath, data)
		return success, fullPath
	end

	local COLOR = FindMetaTable("Color")

	---@param bounceString string
	---@return table bounceArray
	---@return table bounceHash
	local function deserializeBounce(bounceString)
		local bounceTable = util.JSONToTable(bounceString)

		local arrayPart, hashPart = {}, {}
		for key, bounceData in pairs(bounceTable) do
			for _, pixData in pairs(bounceData) do
				if pixData.Col then
					pixData.Col.a = 255
					setmetatable(pixData.Col, COLOR)
				end
			end

			if tonumber(key) then
				table.insert(arrayPart, bounceData)
			else
				hashPart[key] = bounceData
			end
		end

		return arrayPart, hashPart
	end
	local bounceRootPath = "softlamps/lightbounce"
	local lampsRootPath = "softlamps/lamps"
	if not file.IsDir("softlamps", "DATA") then
		file.CreateDir("softlamps")
	end
	if not file.Exists(bounceRootPath, "DATA") then
		file.CreateDir(bounceRootPath)
	end
	if not file.Exists(lampsRootPath, "DATA") then
		file.CreateDir(lampsRootPath)
	end

	local function autocomplete(root, cmd, text)
		local files, dirs = file.Find(root .. "/" .. string.Trim(text) .. "*", "DATA")
		table.Add(dirs or {}, files or {})

		local text = string.Split(text, "/")
		local fullDirectory = ""
		for i = 1, #text - 1 do
			fullDirectory = fullDirectory .. string.TrimLeft(text[i]) .. "/"
		end
		local suggestions = {}
		for _, result in ipairs(fzy.filter(string.Trim(text[#text]), dirs, false)) do
			table.insert(suggestions, cmd .. " " .. fullDirectory .. dirs[result[1]])
		end

		return suggestions
	end

	local RED = Color(255, 0, 0)
	local YELLOW = Color(255, 255, 0)
	local GREEN = Color(0, 255, 0)
	concommand.Add("lightbounce_save", function(ply, cmd, args, argStr)
		if not istable(SoftLampsBounceTable) then
			return
		end

		if #args == 0 then
			MsgN("lightbounce_save <savepath>")
			MsgN("Note that the <savepath> is relative to data/" .. bounceRootPath)
			MsgN("If the savepath contains slashes, this command will automatically create these directories for you")
			return
		end

		if not next(SoftLampsBounceTable) then
			MsgC(
				YELLOW,
				"No light bounce data exists in the scene. Use the Light Sprayer tool to add data to the scene in order to save it\n"
			)
			return
		end

		local path = tostring(args[1])
		createDirectoriesFromPath(path, bounceRootPath)
		local success, fullPath = writePathToTextFile(path, bounceRootPath, serializeBounce(SoftLampsBounceTable))
		if success then
			MsgC(color_white, "Saved to data/", fullPath, "\n")
		else
			MsgC(RED, "Failed to write to data/", fullPath, "\n")
		end
	end, function (cmd, argStr)
		return autocomplete(bounceRootPath, cmd, argStr)
	end)

	concommand.Add("lightbounce_load", function(ply, cmd, args, argStr)
		if not istable(SoftLampsBounceTable) then
			return
		end

		if #args == 0 then
			MsgN("lightbounce_load <loadpath> <append=0>")
			MsgN("Load lightbounce data from a <loadpath> relative to data/" .. bounceRootPath)
			MsgN("By default, this command will remove any lightbounce data in the scene.")
			MsgN("To add the lightbounce data to any existing lightbounce setup, set <append> to 1.")
			return
		end

		local loadPath, append = args[1], Either(args[2] ~= nil, tobool(args[2]), false)
		loadPath = parsePathToLoad(loadPath, bounceRootPath)

		local bounceString = file.Read(loadPath, "DATA")
		local success, err = pcall(function()
			if bounceString then
				local bounceArray, bounceHash = deserializeBounce(bounceString)
				if not append then
					MsgC(YELLOW, "")
					SoftLampsBounceTable = {}
				end

				for _, bounceData in ipairs(bounceArray) do
					table.insert(SoftLampsBounceTable, bounceData)
				end
				table.Merge(SoftLampsBounceTable, bounceHash)
			end
		end)

		if success then
			MsgC(
				GREEN,
				not append and "Successfully loaded data/" .. loadPath or "Successfully appended data/" .. loadPath,
				"!\n"
			)
		else
			MsgC(RED, "An error occurred when attempting to load data/", loadPath, "\n", err)
			MsgC(RED, "Please report this to the following link:")
			MsgC(RED, SOURCE_URL)
		end
	end, function (cmd, argStr)
		return autocomplete(bounceRootPath, cmd, argStr)
	end)

	concommand.Add("softlamps_save", function(ply, cmd, args, argStr)
		if #args == 0 then
			MsgN("softlamps_save <savepath>")
			MsgN("Note that the <savepath> is relative to data/" .. lampsRootPath)
			MsgN("If the savepath contains slashes, this command will automatically create these directories for you")
			return
		end

		local softLamps = GetAllSoftLamps()

		if not softLamps[1] then
			MsgC(
				YELLOW,
				"Soft lamps must exist in the scene in order to save it. Spawn a soft lamp and try again\n"
			)
			return
		end

		local data = {}
		for _, softLamp in ipairs(softLamps) do
			table.insert(data, getSoftLampData(softLamp))
		end

		local path = tostring(args[1])
		createDirectoriesFromPath(path, lampsRootPath)
		local success, fullPath = writePathToTextFile(path, lampsRootPath, util.TableToJSON(data, true))
		if success then
			MsgC(color_white, "Saved to data/", fullPath, "\n")
		else
			MsgC(RED, "Failed to write to data/", fullPath, "\n")
		end
	end)

	concommand.Add("softlamps_load", function(ply, cmd, args, argStr)
		if not istable(SoftLampsBounceTable) then
			return
		end

		if #args == 0 then
			MsgN("softlamps_load <loadpath> <replace=0>")
			MsgN("Load lightbounce data from a <loadpath> relative to data/" .. lampsRootPath)
			MsgN("By default, this command will add soft lamps to the scene.")
			MsgN("To replace existing soft lamps with the loaded data, set <replace> to 1.")
			MsgN("Warning: replace cannot be undone")
			return
		end

		local loadPath, replace = args[1], Either(args[2] ~= nil, tobool(args[2]), false)
		loadPath = parsePathToLoad(loadPath, lampsRootPath)

		local json = file.Read(loadPath, "DATA")
		local success, err = pcall(function()
			if json then
				local lampArray = util.JSONToTable(json)
				local count = #lampArray
				if count == 0 then return end

				net.Start("softlamp_load")
				net.WriteBool(replace)
				net.SendToServer()

				local i = 1
				timer.Create("softlamp_load_batch", 0.001, math.ceil(count / SOFTLAMPS_BANDWIDTH) + 1, function()
					net.Start("softlamp_load_batch", true)
					net.WriteBool(i >= count)
					for j = 0, SOFTLAMPS_BANDWIDTH - 1 do
						local data = lampArray[i + j]
						net.WriteBool(data ~= nil)
						if data then
							net.WriteTable(data)
						end
					end
					net.SendToServer()
					i = i + SOFTLAMPS_BANDWIDTH
				end)
			end
		end)

		if success then
			MsgC(
				GREEN,
				replace and "Successfully replaced the scene with data/" .. loadPath or "Successfully appended data/" .. loadPath,
				"!\n"
			)
		else
			MsgC(RED, "An error occurred when attempting to load data/", loadPath, "\n", err)
			MsgC(RED, "Please report this to the following link:")
			MsgC(RED, SOURCE_URL)
		end
	end, function (cmd, argStr)
		return autocomplete(lampsRootPath, cmd, argStr)
	end)

	net.Receive("softlamp_load_batch", function (len, ply)
		notification.AddLegacy("Finished loading soft lamp scene data", NOTIFY_GENERIC, 3)
	end)

	local bboxConVar = CreateClientConVar(
		"softlamps_bbox",
		"0",
		true,
		false,
		[[
		Display the state of a soft lamp.
			- Yellow means Gameplay is on
			- Orange means Heavylight is on
			- Green means both states are on
			- No bbox means both states are off
		]]
	)

	local stateColors = {
		disabled = Color(128, 128, 128),
		gameplay = Color(255, 255, 0),
		heavylight = Color(255, 128, 0),
		enabled = Color(0, 255, 0),
	}

	-- Draw bounding box states
	hook.Remove("HUDPaint", "softlamps_bbox")
	hook.Add("HUDPaint", "softlamps_bbox", function()
		if not bboxConVar:GetBool() then
			return
		end

		cam.Start3D()
		for _, softlamp in ipairs(GetAllSoftLamps()) do
			local state = getSoftLampState(softlamp)
			local pos, ang, min, max = softlamp:GetPos(), softlamp:GetAngles(), softlamp:OBBMins(), softlamp:OBBMaxs()

			render.DrawWireframeBox(pos, ang, min, max, stateColors[state], true)
			if softlamp == SoftLampHoveredVar then
				cam.IgnoreZ(true)
				render.SetColorMaterial()
				render.DrawBox(pos, ang, min, max, stateColors[state])
				cam.IgnoreZ(false)
			end
		end
		cam.End3D()
	end)
else
	---@param data SoftLampData
	local function spawnLamp(ply, data)
		local r = data.LightColor.x * 255
		local g = data.LightColor.y * 255
		local b = data.LightColor.z * 255
		local key = GetConVar("softlamp_key"):GetInt()
		local texture = data.FlashlightTexture
		local mdl = data.Model
		local fov = data.LightFOV
		local distance = data.FarZ
		local nearz = data.NearZ
		local bright = data.Brightness
		local toggle = true
		local on = false
		local softradius = data.ShapeRadius
		local softlayers = math.max(math.floor(data.HeavyLayers), 1)
		local softshape = data.HeavyShape
		local orthoon = data.EnableOrthographic
		local orthosize = data.OrthoLeft
		local pos, ang = data.Pos, data.Ang
		
		local lamp = MakeSoftLamp(
			ply,
			r,
			g,
			b,
			key,
			toggle,
			texture,
			mdl,
			fov,
			distance,
			nearz,
			bright,
			not toggle and on,
			softshape,
			softradius,
			softlayers,
			{ Pos = pos, Angle = ang },
			orthoon,
			orthosize
		)

		if not lamp then
			return
		end

		---@cast lamp any

		lamp:SetOrthoLeft(data.OrthoLeft)
		lamp:SetOrthoTop(data.OrthoTop)
		lamp:SetOrthoRight(data.OrthoRight)
		lamp:SetOrthoBottom(data.OrthoBottom)
		lamp:SetOn(data.On)
		lamp:SetGameplayShape(data.GameplayShape)
		lamp:SetGameplayLayers(1)
		lamp:SetLinearAttenuation(data.LinearAttenuation)
		lamp:SetQuadraticAttenuation(data.QuadraticAttenuation)
		lamp:SetConstantAttenuation(data.ConstantAttenuation)
		lamp:SetLightOffset(data.LightOffset)

		lamp:SetColor(data.Color)
		lamp:SetRenderMode(RENDERMODE_TRANSCOLOR)
		local po = lamp:GetPhysicsObject()
		if IsValid(po) then
			po:EnableMotion(false)
			po:Sleep()
			po:EnableCollisions(false)
		end

		return lamp
	end

	util.AddNetworkString("softlamp_removed")
	net.Receive("softlamp_removed", function()
		local softlamp = net.ReadEntity()
		if IsValid(softlamp) then
			softlamp:Remove()
		end
	end)

	util.AddNetworkString("softlamp_load_batch")
	net.Receive("softlamp_load_batch", function (len, ply)
		local done = net.ReadBool()

		if not done then
			for _ = 1, SOFTLAMPS_BANDWIDTH do
				local dataExists = net.ReadBool()
				if not dataExists then
					return
				end
				local data = net.ReadTable()
				local lamp = spawnLamp(ply, data)
				if lamp then
					undo.AddEntity(lamp)
				end
			end
		end

		if done then
			undo.Finish()
			net.Start("softlamp_load_batch")
			net.Send(ply)
		end
	end)

	util.AddNetworkString("softlamp_load")
	net.Receive("softlamp_load", function (len, ply)
		local replace = net.ReadBool()
		---@type SoftLampData[]
		---@

		if replace then
			for _, softLamp in ipairs(GetAllSoftLamps()) do
				softLamp:Remove()
			end
		end

		undo.Create("Soft lamps scene data")
		undo.SetPlayer(ply)
	end)

	util.AddNetworkString("softlamp_state")
	net.Receive("softlamp_state", function()
		local softlamp = net.ReadEntity()
		---@cast softlamp SoftLamp
		local state = states[net.ReadUInt(stateBitCount)]
		if IsValid(softlamp) and state then
			setSoftLampState(softlamp, state)
		end
	end)

	local index = 1
	concommand.Add("softlamps_cycle", function(_, _, args)
		local softlamps = GetAllSoftLamps()
		local softcount = #softlamps

		local steps = args[1] and tonumber(args[1]) or 1
		if (index + steps) > softcount then steps = softcount - index + 1 end

		local indextab = {}
		for i = index, index + steps-1 do indextab[i] = true end

		for i, softlamp in ipairs(softlamps) do
			softlamp:SetHeavyOn(indextab[i])
		end

		MsgN("Enabling lamps from " .. index .. " to " .. index + steps-1)
		index = wrapNumber(index + steps, 0, softcount)
	end, nil, "Walk through all softlamps and change their HeavyLight state one at a time.")

	concommand.Add("softlamps_enable", function(_, _, args)
		if (not args[1]) or not tonumber(args[1]) then MsgN("Input number index for a Soft Lamp to enable") return end
		local softlamps = GetAllSoftLamps()
		local softcount = #softlamps

		local index = tonumber(args[1])

		for i, softlamp in ipairs(softlamps) do
			softlamp:SetHeavyOn(i == index)
		end
	end, nil, "Enable HeavyLight of a specific Soft Lamp.")

	concommand.Add("softlamps_detorch", function()
		for _, softlamp in ipairs(GetAllSoftLamps()) do
			softlamp:SetHeavyOn(false)
		end
	end, nil, "Turn off the heavylights of all soft lamps")

	local gameplay = false
	concommand.Add(
		"softlamps_toggle_gameplay",
		function(_, _, args, _)
			local invert = args[1] ~= nil and args[1]
			gameplay = not gameplay

			for _, softlamp in ipairs(GetAllSoftLamps()) do
				if invert then
					softlamp:SetOn(not softlamp:GetOn())
				else
					softlamp:SetOn(gameplay)
				end
			end
		end,
		function(cmd)
			return {
				cmd .. " " .. "0",
				cmd .. " " .. "1",
			}
		end,
		"Toggle all soft lamps' Gameplay state, which displays a `Projected Texture`. If set to 1, invert all soft lamps' Gameplay state instead of setting them on or off"
	)
end
