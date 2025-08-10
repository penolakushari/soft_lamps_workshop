---@class SoftLamp: ENT
---@field SetHeavyOn fun(self: SoftLamp, enabled: boolean)
---@field GetHeavyOn fun(self: SoftLamp): enabled: boolean
---@field SetOn fun(self: SoftLamp, enabled: boolean)
---@field GetOn fun(self: SoftLamp): enabled: boolean
---@field hovered boolean

local SOURCE_URL = "https://gist.github.com/vlazed/927cff337255b993c5fab8a0cfd44111"

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

	concommand.Add("softlamps_count", function(ply, cmd, args, argStr)
		MsgC(color_white, #GetAllSoftLamps(), "\n")
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
	local rootPath = "softlamps/lightbounce"
	if not file.Exists("softlamps", "DATA") then
		file.CreateDir("softlamps")
	end
	if not file.Exists(rootPath, "DATA") then
		file.CreateDir(rootPath)
	end

	local RED = Color(255, 0, 0)
	local YELLOW = Color(255, 255, 0)
	local GREEN = Color(0, 255, 0)
	concommand.Add("lightbounce_save", function(ply, cmd, args, argStr)
		if not istable(SoftLampsBounceTable) then
			return
		end

		if #args == 0 then
			print("lightbounce_save <savepath>")
			print("Note that the <savepath> is relative to data/softlamps")
			print("If the savepath contains slashes, this command will automatically create these directories for you")
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
		local splitPath = string.Split(path, "/")
		local count = #splitPath
		if count > 1 then
			local currentPath = rootPath
			for i, name in ipairs(splitPath) do
				currentPath = currentPath .. "/" .. name
				if i ~= count and not file.Exists(currentPath, "DATA") then
					file.CreateDir(currentPath)
				end
			end
		end

		if string.GetExtensionFromFilename(path) ~= ".txt" then
			path = path .. ".txt"
		end

		local fullPath = rootPath .. "/" .. path
		local data = serializeBounce(SoftLampsBounceTable)
		local success = file.Write(fullPath, data)
		if success then
			MsgC(color_white, "Saved to data/", fullPath, "\n")
		else
			MsgC(RED, "Failed to write to data/", fullPath, "\n")
		end
	end)

	concommand.Add("lightbounce_load", function(ply, cmd, args, argStr)
		if not istable(SoftLampsBounceTable) then
			return
		end

		if #args == 0 then
			print("lightbounce_load <loadpath> <append=0>")
			print("Load lightbounce data from a <loadpath> relative to " .. rootPath)
			print("By default, this command will remove any lightbounce data in the scene.")
			print("To add the lightbounce data to any existing lightbounce setup, set <append> to 1.")
			return
		end

		local loadPath, append = args[1], Either(args[2] ~= nil, tobool(args[2]), false)
		if not string.find(loadPath, rootPath) then
			loadPath = rootPath .. "/" .. loadPath
		end
		if string.GetExtensionFromFilename(loadPath) ~= ".txt" then
			loadPath = loadPath .. ".txt"
		end

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
	util.AddNetworkString("softlamp_removed")
	net.Receive("softlamp_removed", function()
		local softlamp = net.ReadEntity()
		if IsValid(softlamp) then
			softlamp:Remove()
		end
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
	concommand.Add("softlamps_cycle", function()
		local softlamps = GetAllSoftLamps()
		for i, softlamp in ipairs(softlamps) do
			softlamp:SetHeavyOn(i == index)
		end
		index = wrapNumber(index + 1, 0, #softlamps)
	end, nil, "Walk through all softlamps and change their HeavyLight state one at a time.")

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
					softlamp:SetOn(softlamp:GetOn())
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
