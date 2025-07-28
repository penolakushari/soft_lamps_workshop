-- Soft Lamp Manager - Server Side
-- Handles teleportation networking

if not SERVER then return end

-- Network strings
util.AddNetworkString("SoftLampManager_Teleport")
util.AddNetworkString("SoftLampManager_SetColor")
util.AddNetworkString("SoftLampManager_SetFloat")
util.AddNetworkString("SoftLampManager_SetBool")
util.AddNetworkString("SoftLampManager_SetString")
util.AddNetworkString("SoftLampManager_SetVector")

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

-- Handle color changes
net.Receive("SoftLampManager_SetColor", function(len, ply)
    if not IsValid(ply) then return end

    local lamp = net.ReadEntity()
    local color = net.ReadVector()

    if IsValid(lamp) and lamp:GetClass() == "gmod_softlamp" then
        lamp:SetLightColor(color)
    end
end)

-- Handle float value changes (brightness, FOV, etc.)
net.Receive("SoftLampManager_SetFloat", function(len, ply)
    if not IsValid(ply) then return end

    local lamp = net.ReadEntity()
    local property = net.ReadString()
    local value = net.ReadFloat()

    if IsValid(lamp) and lamp:GetClass() == "gmod_softlamp" then
        local options = {
            Brightness = function(lamp, value) lamp:SetBrightness(value) end,

            LightFOV = function(lamp, value) lamp:SetLightFOV(value) end,

            NearZ = function(lamp, value) lamp:SetNearZ(value) end,

            FarZ = function(lamp, value) lamp:SetFarZ(value) end,

            FocalDistance = function(lamp, value) lamp:SetFocalDistance(value) end,

            ShapeRadius = function(lamp, value) lamp:SetShapeRadius(value) end,

            HeavyLayers = function(lamp, value) lamp:SetHeavyLayers(value) end,

            HeavySplit = function(lamp, value) lamp:SetHeavySplit(value) end,

            GameplayLayers = function(lamp, value) lamp:SetGameplayLayers(value) end,

            OrthoLeft = function(lamp, value) lamp:SetOrthoLeft(value) end,

            OrthoTop = function(lamp, value) lamp:SetOrthoTop(value) end,

            OrthoRight = function(lamp, value) lamp:SetOrthoRight(value) end,

            OrthoBottom = function(lamp, value) lamp:SetOrthoBottom(value) end
        }

        options[property](lamp, value)
    end
end)

-- Handle boolean value changes (On, Heavy, etc.)
net.Receive("SoftLampManager_SetBool", function(len, ply)
    if not IsValid(ply) then return end

    local lamp = net.ReadEntity()
    local property = net.ReadString()
    local value = net.ReadBool()

    if IsValid(lamp) and lamp:GetClass() == "gmod_softlamp" then
        if property == "Toggle" then
            lamp:SetToggle(value)
        elseif property == "On" then
            lamp:SetOn(value)
        elseif property == "HeavyOn" then
            lamp:SetHeavyOn(value)
        elseif property == "PreviewPoints" then
            lamp:SetPreviewPoints(value)
        elseif property == "PreviewSafeArea" then
            lamp:SetPreviewSafeArea(value)
        elseif property == "PreviewIgnoreZ" then
            lamp:SetPreviewIgnoreZ(value)
        elseif property == "EnableOrthographic" then
            lamp:SetEnableOrthographic(value)
        elseif property == "PreviewPoster" then
            lamp:SetPreviewPoster(value)
        end
    end
end)

-- Handle string value changes (texture, shapes, etc.)
net.Receive("SoftLampManager_SetString", function(len, ply)
    if not IsValid(ply) then return end

    local lamp = net.ReadEntity()
    local property = net.ReadString()
    local value = net.ReadString()

    if IsValid(lamp) and lamp:GetClass() == "gmod_softlamp" then
        if property == "FlashlightTexture" then
            lamp:SetFlashlightTexture(value)
        elseif property == "HeavyShape" then
            lamp:SetHeavyShape(value)
        elseif property == "GameplayShape" then
            lamp:SetGameplayShape(value)
        end
    end
end)

-- Handle vector value changes (light offset, etc.)
net.Receive("SoftLampManager_SetVector", function(len, ply)
    if not IsValid(ply) then return end

    local lamp = net.ReadEntity()
    local property = net.ReadString()
    local value = net.ReadVector()

    if IsValid(lamp) and lamp:GetClass() == "gmod_softlamp" then
        if property == "LightOffset" then
            lamp:SetLightOffset(value)
        end
    end
end)
