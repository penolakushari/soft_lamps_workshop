-- Soft Lamp Manager - Server Side
-- Handles teleportation networking

-- Network strings
util.AddNetworkString("SoftLampManager_Teleport")
util.AddNetworkString("SoftLampManager_SetProperty")
util.AddNetworkString("SoftLampManager_ApplyLampPreset")

local TYPE_VECTOR = 0
local TYPE_FLOAT  = 1
local TYPE_BOOL   = 2
local TYPE_STRING = 3

local types = {
    net.ReadVector,
    net.ReadFloat,
    net.ReadBool,
    net.ReadString
}

-- Handle teleport requests from clients
net.Receive("SoftLampManager_Teleport", function(len, ply)
    if not IsValid(ply) then return end

    local lampPos = net.ReadVector()

    -- Teleport the player
    local newPos = Vector(lampPos.x, lampPos.y, lampPos.z + 70)
    ply:SetPos(newPos)

    -- Face the lamp
    local angles = (lampPos - newPos):Angle()
    angles.p = math.Clamp(angles.p, -89, 89)
    ply:SetEyeAngles(angles)
end)

net.Receive("SoftLampManager_SetProperty", function(len, ply)
    local lamp = net.ReadEntity()
    local property = net.ReadString()
    local val = types[net.ReadUInt(2)+1]()

    if not IsValid(ply) then return end
    if IsValid(lamp) and lamp:GetClass() == "gmod_softlamp" and lamp:GetNetworkVars()[property] ~= nil then
        lamp["Set" .. property](lamp, val)
    end
end)

net.Receive("SoftLampManager_ApplyLampPreset", function(len, ply)
    local lamp = net.ReadEntity()
    local count = net.ReadUInt(5)
    local apply = {}
    for i = 1, count do
        apply[i] = { net.ReadString(), types[net.ReadUInt(2)+1]() }
    end

    if not IsValid(ply) or not IsValid(lamp) or not lamp:GetClass() == "gmod_softlamp" then return end
    local propertytable = lamp:GetNetworkVars()
    for k, data in ipairs(apply) do
        if not (propertytable[data[1]] ~= nil) then continue end
        lamp["Set" .. data[1]](lamp, data[2])
    end
end)
