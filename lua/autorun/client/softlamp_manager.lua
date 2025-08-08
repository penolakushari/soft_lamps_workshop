-- Soft Lamp Manager - Y Key Menu System
-- This provides a menu to view, edit, and teleport to all soft lamps in the scene

-- Add custom context menu option for saving presets
-- Initialize preset system
SoftLampPresets = SoftLampPresets or {}
local SOFTLAMPS_MNGR_PRESETSLOADED = false

-- Load presets from file if not already loaded
if not SOFTLAMPS_MNGR_PRESETSLOADED then
    if file.Exists("softlamp_presets.txt", "DATA") then
        local data = file.Read("softlamp_presets.txt", "DATA")
        if data then
            local decoded = util.JSONToTable(data)
            if decoded then
                for k, v in pairs(decoded) do
                    SoftLampPresets[k] = v
                end
            end
        end
    end
    SOFTLAMPS_MNGR_PRESETSLOADED = true
end

-- Menu state
local SoftLampManager = {
    isVisible = false,
    menuFrame = nil,
    lampList = {},
    editingLamp = nil,
    editSettings = {}, -- Store edited settings that don't apply to the entity
    yKeyPressed = false -- Track Y key state for Think hook
}

-- Colors and styling
local COLOR_BG = Color(30, 30, 30, 240)
local COLOR_HEADER = Color(50, 50, 50, 255)
local COLOR_SELECTED = Color(60, 100, 160, 200)
local COLOR_HOVER = Color(45, 45, 45, 255)
local COLOR_HOVERED = Color(COLOR_HOVER.r + 10, COLOR_HOVER.g + 10, COLOR_HOVER.b + 10, COLOR_HOVER.a)
local COLOR_TEXT = Color(255, 255, 255, 255)
local COLOR_TEXT_DIM = Color(180, 180, 180, 255)

local TYPE_VECTOR = 0
local TYPE_FLOAT  = 1
local TYPE_BOOL   = 2
local TYPE_STRING = 3

-- Get all soft lamps in the scene
local function GetAllSoftLamps()
    local lamps = {}
    for _, ent in pairs(ents.FindByClass("gmod_softlamp")) do
        if IsValid(ent) then
            table.insert(lamps, ent)
        end
    end
    return lamps
end

-- Get a friendly name for a lamp
local function GetLampName(lamp)
    if not IsValid(lamp) then return "Invalid Lamp" end

    -- Check if we have a custom name first
    if SoftLampManager.editSettings[lamp] and SoftLampManager.editSettings[lamp].name and SoftLampManager.editSettings[lamp].name ~= "" then
        return SoftLampManager.editSettings[lamp].name
    end

    -- Default name based on position and color
    local pos = lamp:GetPos()
    local x, y, z = math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)
    local color = lamp:GetLightColor()
    local r, g, b = math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255)

    return string.format("Lamp @(%d,%d,%d) RGB(%d,%d,%d)", x, y, z, r, g, b)
end

-- Teleport to lamp
local function TeleportToLamp(lamp)
    if not IsValid(lamp) then 
        chat.AddText(Color(255, 100, 100), "Cannot teleport: Lamp no longer exists!")
        return 
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Get the CURRENT position of the lamp (not cached)
    local lampPos = lamp:GetPos()

    -- Send teleport request to server
    net.Start("SoftLampManager_Teleport")
        net.WriteVector(lampPos)
    net.SendToServer()

    chat.AddText(Color(100, 255, 100), "Teleport requested...")
end

-- Create the edit panel
local function CreateEditPanel()
    if not IsValid(SoftLampManager.editPanel) then return end

    SoftLampManager.editPanel:Clear()

    local label = vgui.Create("DLabel", SoftLampManager.editPanel)
    label:SetPos(10, 10)
    label:SetSize(300, 20)
    label:SetText("Select a lamp to edit its settings")
    label:SetTextColor(COLOR_TEXT_DIM)
end

-- Helper function to create a labeled control
local function CreateLabeledControl(parent, x, y, labelText, control, width)
    local label = vgui.Create("DLabel", parent)
    label:SetPos(x, y)
    label:SetSize(120, 20)
    label:SetText(labelText)
    label:SetTextColor(COLOR_TEXT)

    control:SetPos(x + 125, y)
    control:SetSize(width or 100, 20)

    return y + 25
end

-- Update the edit panel with selected lamp
local function UpdateEditPanel()
    if not IsValid(SoftLampManager.editPanel) or not IsValid(SoftLampManager.editingLamp) then return end

    SoftLampManager.editPanel:Clear()

    local lamp = SoftLampManager.editingLamp
    local settings = SoftLampManager.editSettings[lamp]
    if not settings then return end

    local yPos = 10

    -- Title
    local titleLabel = vgui.Create("DLabel", SoftLampManager.editPanel)
    titleLabel:SetPos(10, yPos)
    titleLabel:SetSize(300, 20)
    titleLabel:SetText("Editing: " .. string.sub(GetLampName(lamp), 1, 30) .. "...")
    titleLabel:SetTextColor(COLOR_TEXT)
    titleLabel:SetFont("DermaDefaultBold")
    yPos = yPos + 30

    -- Custom name
    local nameEntry = vgui.Create("DTextEntry", SoftLampManager.editPanel)
    nameEntry:SetText(settings.name or "")
    nameEntry.OnEnter = function(self)
        settings.name = self:GetText()
        self:KillFocus()
        UpdateLampList()
    end
    nameEntry.OnLoseFocus = function(self)
        settings.name = self:GetText()
        UpdateLampList()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Custom Name:", nameEntry, 200)

    -- Notes
    local notesEntry = vgui.Create("DTextEntry", SoftLampManager.editPanel)
    notesEntry:SetText(settings.notes or "")
    notesEntry.OnEnter = function(self)
        settings.notes = self:GetText()
        self:KillFocus()
        UpdateLampList()
    end
    notesEntry.OnLoseFocus = function(self)
        settings.notes = self:GetText()
        UpdateLampList()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Notes:", notesEntry, 200)

    -- Separator
    local separator1 = vgui.Create("DLabel", SoftLampManager.editPanel)
    separator1:SetPos(10, yPos)
    separator1:SetSize(390, 20) -- Expanded width
    separator1:SetText("─── LAMP SETTINGS ───")
    separator1:SetTextColor(COLOR_TEXT)
    separator1:SetFont("DermaDefaultBold")
    separator1:SetContentAlignment(5) -- Center
    yPos = yPos + 25

    -- Light Color
    local colorLabel = vgui.Create("DLabel", SoftLampManager.editPanel)
    colorLabel:SetPos(10, yPos)
    colorLabel:SetSize(120, 20)
    colorLabel:SetText("Light Color:")
    colorLabel:SetTextColor(COLOR_TEXT)
    yPos = yPos + 25

    local colorMixer = vgui.Create("DColorMixer", SoftLampManager.editPanel)
    colorMixer:SetPos(10, yPos)
    colorMixer:SetSize(390, 120) -- Expanded width from 340 to 390
    local currentColor = lamp:GetLightColor()
    colorMixer:SetColor(Color(currentColor.r * 255, currentColor.g * 255, currentColor.b * 255))
    colorMixer.ValueChanged = function(self, color)
        -- Network the change to the server
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("LightColor")
            net.WriteUInt(TYPE_VECTOR, 2)
            net.WriteVector(Vector(color.r / 255, color.g / 255, color.b / 255))
        net.SendToServer()
    end
    yPos = yPos + 130 -- Space for the larger color mixer

    -- Brightness
    local brightnessSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    brightnessSlider:SetMinMax(0, 100)
    brightnessSlider:SetDecimals(1)
    brightnessSlider:SetValue(lamp:GetBrightness())
    brightnessSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("Brightness")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Brightness:", brightnessSlider, 200)

    -- FOV
    local fovSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    fovSlider:SetMinMax(0, 180)
    fovSlider:SetDecimals(0)
    fovSlider:SetValue(lamp:GetLightFOV())
    fovSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("LightFOV")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "FOV:", fovSlider, 200)

    -- NearZ
    local nearZSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    nearZSlider:SetMinMax(1, 1000)
    nearZSlider:SetDecimals(0)
    nearZSlider:SetValue(lamp:GetNearZ())
    nearZSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("NearZ")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Near Z:", nearZSlider, 200)

    -- FarZ
    local farZSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    farZSlider:SetMinMax(1, 10000)
    farZSlider:SetDecimals(0)
    farZSlider:SetValue(lamp:GetFarZ())
    farZSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("FarZ")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Far Z:", farZSlider, 200)

    -- Focal Distance
    local focalSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    focalSlider:SetMinMax(0, 5000)
    focalSlider:SetDecimals(0)
    focalSlider:SetValue(lamp:GetFocalDistance())
    focalSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("FocalDistance")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Focal Distance:", focalSlider, 200)

    -- Toggle checkbox
    local toggleCheck = vgui.Create("DCheckBox", SoftLampManager.editPanel)
    toggleCheck:SetChecked(lamp:GetToggle())
    toggleCheck.OnChange = function(self, checked)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("Toggle")
            net.WriteUInt(TYPE_BOOL, 2)
            net.WriteBool(checked)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Toggle:", toggleCheck, 20)

    -- On checkbox
    local onCheck = vgui.Create("DCheckBox", SoftLampManager.editPanel)
    onCheck:SetChecked(lamp:GetOn())
    onCheck.OnChange = function(self, checked)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("On")
            net.WriteUInt(TYPE_BOOL, 2)
            net.WriteBool(checked)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "On:", onCheck, 20)

    -- Separator
    local separator2 = vgui.Create("DLabel", SoftLampManager.editPanel)
    separator2:SetPos(10, yPos)
    separator2:SetSize(390, 20) -- Expanded width
    separator2:SetText("─── HEAVY LIGHT SETTINGS ───")
    separator2:SetTextColor(COLOR_TEXT)
    separator2:SetFont("DermaDefaultBold")
    separator2:SetContentAlignment(5)
    yPos = yPos + 25

    -- Heavy On
    local heavyOnCheck = vgui.Create("DCheckBox", SoftLampManager.editPanel)
    heavyOnCheck:SetChecked(lamp:GetHeavyOn())
    heavyOnCheck.OnChange = function(self, checked)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("HeavyOn")
            net.WriteUInt(TYPE_BOOL, 2)
            net.WriteBool(checked)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Heavy On:", heavyOnCheck, 20)

    -- Shape Radius
    local radiusSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    radiusSlider:SetMinMax(1, 1000)
    radiusSlider:SetDecimals(0)
    radiusSlider:SetValue(lamp:GetShapeRadius())
    radiusSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("ShapeRadius")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Shape Radius:", radiusSlider, 200)

    -- Heavy Layers
    local heavyLayersSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    heavyLayersSlider:SetMinMax(1, 50)
    heavyLayersSlider:SetDecimals(0)
    heavyLayersSlider:SetValue(lamp:GetHeavyLayers())
    heavyLayersSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("HeavyLayers")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Heavy Layers:", heavyLayersSlider, 200)

    -- Heavy Split
    local heavySplitSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    heavySplitSlider:SetMinMax(1, 10)
    heavySplitSlider:SetDecimals(0)
    heavySplitSlider:SetValue(lamp:GetHeavySplit())
    heavySplitSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("HeavySplit")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Heavy Split:", heavySplitSlider, 200)

    -- Separator
    local separator3 = vgui.Create("DLabel", SoftLampManager.editPanel)
    separator3:SetPos(10, yPos)
    separator3:SetSize(390, 20) -- Expanded width
    separator3:SetText("─── GAMEPLAY SETTINGS ───")
    separator3:SetTextColor(COLOR_TEXT)
    separator3:SetFont("DermaDefaultBold")
    separator3:SetContentAlignment(5)
    yPos = yPos + 25

    -- Gameplay Layers
    local gameplayLayersSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    gameplayLayersSlider:SetMinMax(1, 20)
    gameplayLayersSlider:SetDecimals(0)
    gameplayLayersSlider:SetValue(lamp:GetGameplayLayers())
    gameplayLayersSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("GameplayLayers")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Gameplay Layers:", gameplayLayersSlider, 200)

    -- Separator
    local separator4 = vgui.Create("DLabel", SoftLampManager.editPanel)
    separator4:SetPos(10, yPos)
    separator4:SetSize(390, 20) -- Expanded width
    separator4:SetText("─── PREVIEW SETTINGS ───")
    separator4:SetTextColor(COLOR_TEXT)
    separator4:SetFont("DermaDefaultBold")
    separator4:SetContentAlignment(5)
    yPos = yPos + 25

    -- Preview Points
    local previewPointsCheck = vgui.Create("DCheckBox", SoftLampManager.editPanel)
    previewPointsCheck:SetChecked(lamp:GetPreviewPoints())
    previewPointsCheck.OnChange = function(self, checked)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("PreviewPoints")
            net.WriteUInt(TYPE_BOOL, 2)
            net.WriteBool(checked)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Preview Points:", previewPointsCheck, 20)

    -- Preview Safe Area
    local previewSafeCheck = vgui.Create("DCheckBox", SoftLampManager.editPanel)
    previewSafeCheck:SetChecked(lamp:GetPreviewSafeArea())
    previewSafeCheck.OnChange = function(self, checked)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("PreviewSafeArea")
            net.WriteUInt(TYPE_BOOL, 2)
            net.WriteBool(checked)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Preview Safe Area:", previewSafeCheck, 20)

    -- Preview Ignore Z
    local previewIgnoreZCheck = vgui.Create("DCheckBox", SoftLampManager.editPanel)
    previewIgnoreZCheck:SetChecked(lamp:GetPreviewIgnoreZ())
    previewIgnoreZCheck.OnChange = function(self, checked)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("PreviewIgnoreZ")
            net.WriteUInt(TYPE_BOOL, 2)
            net.WriteBool(checked)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Preview Ignore Z:", previewIgnoreZCheck, 20)

     -- Separator
    local separator5 = vgui.Create("DLabel", SoftLampManager.editPanel)
    separator5:SetPos(10, yPos)
    separator5:SetSize(390, 20) -- Expanded width
    separator5:SetText("───     EXTRA     ───")
    separator5:SetTextColor(COLOR_TEXT)
    separator5:SetFont("DermaDefaultBold")
    separator5:SetContentAlignment(5)
    yPos = yPos + 25

    -- Linear
    local linearAttenSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    linearAttenSlider:SetMinMax(0, 100)
    linearAttenSlider:SetDecimals(0)
    linearAttenSlider:SetValue(lamp:GetLinearAttenuation())
    linearAttenSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("LinearAttenuation")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Linear Attenuation:", linearAttenSlider, 200)

    -- Quadratic
    local quadraticAttenSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    quadraticAttenSlider:SetMinMax(0, 100)
    quadraticAttenSlider:SetDecimals(0)
    quadraticAttenSlider:SetValue(lamp:GetQuadraticAttenuation())
    quadraticAttenSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("QuadraticAttenuation")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Quadratic Attenuation:", quadraticAttenSlider, 200)

    -- Constant
    local constantAttenSlider = vgui.Create("DNumSlider", SoftLampManager.editPanel)
    constantAttenSlider:SetMinMax(0, 100)
    constantAttenSlider:SetDecimals(0)
    constantAttenSlider:SetValue(lamp:GetConstantAttenuation())
    constantAttenSlider.OnValueChanged = function(self, value)
        net.Start("SoftLampManager_SetProperty")
            net.WriteEntity(lamp)
            net.WriteString("ConstantAttenuation")
            net.WriteUInt(TYPE_FLOAT, 2)
            net.WriteFloat(value)
        net.SendToServer()
    end
    yPos = CreateLabeledControl(SoftLampManager.editPanel, 10, yPos, "Constant Attenuation:", constantAttenSlider, 200)
end

-- Select a lamp for editing
local function SelectLampForEditing(lamp)
    if not IsValid(lamp) then return end

    SoftLampManager.editingLamp = lamp

    -- Initialize edit settings if not present
    if not SoftLampManager.editSettings[lamp] then
        SoftLampManager.editSettings[lamp] = {
            name = GetLampName(lamp),
            notes = "",
            customColor = lamp:GetLightColor(),
            customBrightness = lamp:GetBrightness(),
            customFOV = lamp:GetLightFOV(),
            visible = true
        }
    end

    UpdateEditPanel()
end

-- Show preset menu for loading presets
local function ShowPresetMenu(lamp, button)
    if not IsValid(lamp) then return end

    -- Access the global presets from the tool
    local presets = SoftLampPresets or {}

    -- Count actual presets
    local presetCount = 0
    for name, preset in pairs(presets) do
        if type(preset) == "table" then
            presetCount = presetCount + 1
        end
    end

    if presetCount == 0 then
        local notice = vgui.Create("DNotify")
        notice:SetPos(button:LocalToScreen(0, 0))
        notice:AddItem("No presets available", NOTIFY_ERROR, 3)
        return
    end

    local menu = DermaMenu()
    menu:SetPos(button:LocalToScreen(0, 30))

    -- Add preset options (filter out non-table values)
    for name, preset in pairs(presets) do
        if type(preset) == "table" then
            menu:AddOption(name, function()
                SoftLampsManagerApplyPresetToLamp(lamp, preset, name)
            end)
        end
    end

    menu:Open()
end

local types = {
    net.WriteVector,
    net.WriteFloat,
    net.WriteBool,
    net.WriteString
}

-- Apply a preset directly to a lamp entity
function SoftLampsManagerApplyPresetToLamp(lamp, preset, presetName)
    if not IsValid(lamp) or not preset then return end

    local applytable = {}

    -- Apply color
    if preset.r and preset.g and preset.b then
        table.insert(applytable, { "LightColor", TYPE_VECTOR, Vector(preset.r/255, preset.g/255, preset.b/255) } )
    end

    -- Apply brightness
    if preset.brightness then
        table.insert(applytable, { "Brightness", TYPE_FLOAT, preset.brightness } )
    end

    -- Apply FOV
    if preset.fov then
        table.insert(applytable, { "LightFOV", TYPE_FLOAT, preset.fov } )
    end

    -- Apply distance (FarZ)
    if preset.distance then
        table.insert(applytable, { "FarZ", TYPE_FLOAT, preset.distance } )
    end

    -- Apply NearZ
    if preset.nearz then
        table.insert(applytable, { "NearZ", TYPE_FLOAT, preset.nearz } )
    end
    
    -- Apply texture (the missing piece!)
    if preset.texture then
        table.insert(applytable, { "FlashlightTexture", TYPE_STRING, preset.texture } )
    end

    -- Apply focal distance
    if preset.focaldistance then
        table.insert(applytable, { "FocalDistance", TYPE_FLOAT, preset.focaldistance } )
    end

    -- Apply light offset
    if preset.lightoffset_x then
        table.insert(applytable, { "LightOffset", TYPE_VECTOR, Vector(preset.lightoffset_x, preset.lightoffset_y or 0, preset.lightoffset_z or 0) } )
    end

    -- Apply orthographic settings
    if preset.orthoon ~= nil then
        table.insert(applytable, { "EnableOrthographic", TYPE_BOOL, preset.orthoon == 1 } )
    end

    -- Apply orthographic sizes
    if preset.ortho_left or preset.orthosize then
        local orthoSize = preset.ortho_left or preset.orthosize
        table.insert(applytable, { "OrthoLeft",   TYPE_FLOAT, orthoSize } )
        table.insert(applytable, { "OrthoTop",    TYPE_FLOAT, preset.ortho_top or orthoSize } )
        table.insert(applytable, { "OrthoRight",  TYPE_FLOAT, preset.ortho_right or orthoSize } )
        table.insert(applytable, { "OrthoBottom", TYPE_FLOAT, preset.ortho_bottom or orthoSize } )
    end

    -- Apply heavy light settings
    if preset.heavy_on ~= nil then
        table.insert(applytable, { "HeavyOn", TYPE_BOOL, preset.heavy_on == 1 } )
    end

    if preset.heavy_shape or preset.shape then
        table.insert(applytable, { "HeavyShape", TYPE_STRING, preset.heavy_shape or preset.shape } )
    end

    if preset.heavy_layers then
        table.insert(applytable, { "HeavyLayers", TYPE_FLOAT, preset.heavy_layers } )
    end

    if preset.heavy_split then
        table.insert(applytable, { "HeavySplit", TYPE_FLOAT, preset.heavy_split } )
    end

    -- Apply toggle
    if preset.toggle ~= nil then
        table.insert(applytable, { "Toggle", TYPE_BOOL, preset.toggle == 1 } )
    end

    -- Apply on state
    if preset.on ~= nil or preset.gameplay_on ~= nil then
        table.insert(applytable, { "On", TYPE_BOOL, (preset.gameplay_on or preset.on) == 1 } )
    end

    -- Apply radius (shape radius)
    if preset.radius or preset.shape_radius then
        table.insert(applytable, { "ShapeRadius", TYPE_FLOAT, preset.shape_radius or preset.radius or 10 } )
    end

    -- Apply layers (gameplay layers)
    if preset.gameplay_layers or preset.layers then
        table.insert(applytable, { "GameplayLayers", TYPE_FLOAT, preset.gameplay_layers or preset.layers or 1 } )
    end

    -- Apply gameplay shape
    if preset.gameplay_shape then
        table.insert(applytable, { "GameplayShape", TYPE_STRING, preset.gameplay_shape } )
    end

    -- Apply preview settings
    if preset.preview_poster ~= nil then
        table.insert(applytable, { "PreviewPoster", TYPE_BOOL, preset.preview_poster == 1 } )
    end

    if preset.preview_points ~= nil then
        table.insert(applytable, { "PreviewPoints", TYPE_BOOL, preset.preview_points == 1 } )
    end

    if preset.preview_safearea ~= nil then
        table.insert(applytable, { "PreviewSafeArea", TYPE_BOOL, preset.preview_safearea == 1 } )
    end

    if preset.preview_ignorez ~= nil then
        table.insert(applytable, { "PreviewIgnoreZ", TYPE_BOOL, preset.preview_ignorez == 1 } )
    end

    -- Apply attenuations
    if preset.linear then
        table.insert(applytable, { "LinearAttenuation", TYPE_FLOAT, preset.linear or 100 } )
    end


    if preset.quadratic then
        table.insert(applytable, { "QuadraticAttenuation", TYPE_FLOAT, preset.quadratic or 0 } )
    end


    if preset.constant then
        table.insert(applytable, { "ConstantAttenuation", TYPE_FLOAT, preset.constant or 0 } )
    end

    net.Start("SoftLampManager_ApplyLampPreset")
        net.WriteEntity(lamp)
        net.WriteUInt(#applytable, 5)
        for k, data in ipairs(applytable) do
            net.WriteString(data[1])
            net.WriteUInt(data[2], 2)
            types[data[2]+1](data[3])
        end
    net.SendToServer()

    chat.AddText(Color(100, 255, 100), "Applied preset '" .. (presetName or "Unknown") .. "' to soft lamp!")

    -- Refresh the edit panel if this lamp is being edited
    if SoftLampManager.editingLamp == lamp then
        timer.Simple(0.1, function()
            UpdateEditPanel()
        end)
    end
end

-- Update the lamp list
local function UpdateLampList()
    if not IsValid(SoftLampManager.lampListPanel) then return end

    SoftLampManager.lampListPanel:Clear()

    local yPos = 5
    for i, lamp in ipairs(SoftLampManager.lampList) do
        if IsValid(lamp) then
            local lampPanel = vgui.Create("DButton", SoftLampManager.lampListPanel)
            lampPanel:SetPos(5, yPos)
            lampPanel:SetSize(400, 60) -- Expanded width from 350 to 400
            lampPanel:SetText("") -- No button text
            lampPanel.lampEntity = lamp
            lampPanel.Paint = function(self, w, h)
                local col = COLOR_HOVER
                if SoftLampManager.editingLamp == lamp then
                    col = COLOR_SELECTED
                elseif self:IsHovered() then
                    col = COLOR_HOVERED
                end
                draw.RoundedBox(4, 0, 0, w, h, col)
            end
            lampPanel.DoClick = function(self)
                SelectLampForEditing(lamp)
            end

            -- Lamp name
            local nameLabel = vgui.Create("DLabel", lampPanel)
            nameLabel:SetPos(10, 5)
            nameLabel:SetSize(250, 20)
            nameLabel:SetText(GetLampName(lamp))
            nameLabel:SetTextColor(COLOR_TEXT)

            -- Status info
            local statusLabel = vgui.Create("DLabel", lampPanel)
            statusLabel:SetPos(10, 25)
            statusLabel:SetSize(250, 15)
            local onText = lamp:GetOn() and "ON" or "OFF"
            local brightness = math.floor(lamp:GetBrightness() * 10) / 10

            local statusText = string.format("Status: %s | Brightness: %g | FOV: %g°", onText, brightness, lamp:GetLightFOV())
            statusLabel:SetText(statusText)
            statusLabel:SetTextColor(COLOR_TEXT_DIM)
            statusLabel:SetFont("DermaDefaultBold")

            -- Notes on separate line below status
            if SoftLampManager.editSettings[lamp] and SoftLampManager.editSettings[lamp].notes and SoftLampManager.editSettings[lamp].notes ~= "" then
                local notesLabel = vgui.Create("DLabel", lampPanel)
                notesLabel:SetPos(10, 40)
                notesLabel:SetSize(250, 15)
                local notesText = "Notes: " .. SoftLampManager.editSettings[lamp].notes
                notesLabel:SetText(notesText)
                notesLabel:SetTextColor(Color(150, 200, 150, 255)) -- Slightly green tint for notes
                notesLabel:SetFont("DermaDefault")
            end

            -- Load Preset button (moved further right)
            local loadBtn = vgui.Create("DButton", lampPanel)
            loadBtn:SetPos(260, 15) -- Moved from 210 to 260
            loadBtn:SetSize(50, 30)
            loadBtn:SetText("Load")
            loadBtn:SetFont("DermaDefaultBold")
            loadBtn.DoClick = function(self)
                ShowPresetMenu(lamp, self)
                return true -- Prevent the panel click from firing
            end
            loadBtn:SetTooltip("Load Preset")

            -- Teleport button (moved further right)
            local teleBtn = vgui.Create("DButton", lampPanel)
            teleBtn:SetPos(320, 15) -- Moved from 265 to 320
            teleBtn:SetSize(70, 30)
            teleBtn:SetText("Teleport")
            teleBtn:SetFont("DermaDefaultBold")
            teleBtn.DoClick = function(self)
                TeleportToLamp(lamp)
                return true -- Prevent the panel click from firing
            end

            yPos = yPos + 65
        end
    end
end

-- Create the main menu frame
local function CreateMenu()
    if IsValid(SoftLampManager.menuFrame) then
        SoftLampManager.menuFrame:Remove()
        SoftLampManager.menuFrame = nil
        -- Small delay to ensure cleanup
        timer.Simple(0.01, function()
            CreateMenu()
        end)
        return
    end
    local frame = vgui.Create("DFrame")
    frame:SetSize(450, 600) -- Expanded width from 400 to 450
    frame:SetPos(50, 50)
    frame:SetTitle("") -- Remove built-in title to avoid duplication
    frame:SetDraggable(true)
    frame:ShowCloseButton(false) -- Hide default close button since we use Y key
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BG)
        draw.RoundedBox(8, 0, 0, w, 30, COLOR_HEADER)
    end

    -- Header label (this is our only title now)
    local headerLabel = vgui.Create("DLabel", frame)
    headerLabel:SetPos(10, 5)
    headerLabel:SetSize(300, 20)
    headerLabel:SetText("Soft Lamp Manager - Press Y to close")
    headerLabel:SetTextColor(COLOR_TEXT)
    headerLabel:SetFont("DermaDefaultBold")

    -- Refresh button
    local refreshBtn = vgui.Create("DButton", frame)
    refreshBtn:SetPos(350, 35) -- Moved right due to expanded width
    refreshBtn:SetSize(80, 25)
    refreshBtn:SetText("Refresh")
    refreshBtn.DoClick = function()
        SoftLampManager.lampList = GetAllSoftLamps()
        UpdateLampList()
    end

    -- Lamp list panel
    local lampListPanel = vgui.Create("DScrollPanel", frame)
    lampListPanel:SetPos(10, 65)
    lampListPanel:SetSize(430, 200) -- Expanded width from 380 to 430
    lampListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 200))
    end

    -- Edit panel (make it larger to fit all settings)
    local editPanel = vgui.Create("DScrollPanel", frame)
    editPanel:SetPos(10, 275)
    editPanel:SetSize(430, 315) -- Expanded width from 380 to 430
    editPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    SoftLampManager.menuFrame = frame
    SoftLampManager.lampListPanel = lampListPanel
    SoftLampManager.editPanel = editPanel

    -- Initialize
    SoftLampManager.lampList = GetAllSoftLamps()
    UpdateLampList()
    CreateEditPanel()

    return frame
end

-- Toggle menu visibility
local function ToggleMenu()
    SoftLampManager.isVisible = not SoftLampManager.isVisible

    if SoftLampManager.isVisible then
        CreateMenu()
        -- Wait for the frame to be created properly
        timer.Simple(0.02, function()
            if IsValid(SoftLampManager.menuFrame) then
                SoftLampManager.menuFrame:MakePopup()
                SoftLampManager.menuFrame:SetKeyboardInputEnabled(true) -- Enable keyboard input for text fields
            end
        end)
    elseif IsValid(SoftLampManager.menuFrame) then
        SoftLampManager.menuFrame:Remove()
        SoftLampManager.menuFrame = nil
    end
end

-- Alternative key binding using Think hook for more reliability
local nextKeyCheck = 0
hook.Add("Think", "SoftLampManager_KeyCheck", function()
    if CurTime() < nextKeyCheck then return end
    nextKeyCheck = CurTime() + 0.1 -- Check every 0.1 seconds

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if input.IsKeyDown(KEY_Y) and not SoftLampManager.yKeyPressed then
        -- Check if we're typing in a text field
        local focusedPanel = vgui.GetKeyboardFocus()
        if not focusedPanel or not focusedPanel.ClassName or focusedPanel.ClassName ~= "DTextEntry" then
            SoftLampManager.yKeyPressed = true
            ToggleMenu()
        end
    elseif not input.IsKeyDown(KEY_Y) then
        SoftLampManager.yKeyPressed = false
    end
end)

-- Clean up on disconnect
hook.Add("ShutDown", "SoftLampManager_Cleanup", function()
    if IsValid(SoftLampManager.menuFrame) then
        SoftLampManager.menuFrame:Remove()
    end
end)

-- Handle entity removal
hook.Add("EntityRemoved", "SoftLampManager_EntityRemoved", function(ent)
    if ent:GetClass() == "gmod_softlamp" then
        -- Remove from our tracking
        for i, lamp in ipairs(SoftLampManager.lampList) do
            if lamp == ent then
                table.remove(SoftLampManager.lampList, i)
                break
            end
        end

        -- Clear edit settings
        if SoftLampManager.editSettings[ent] then
            SoftLampManager.editSettings[ent] = nil
        end

        -- Update UI if open
        if SoftLampManager.isVisible then
            UpdateLampList()
            if SoftLampManager.editingLamp == ent then
                SoftLampManager.editingLamp = nil
                CreateEditPanel()
            end
        end
    end
end)

-- Console command as backup
concommand.Add("softlamp_manager", function()
    ToggleMenu()
end)

-- Debug command to test if the script is loaded
concommand.Add("softlamp_manager_test", function()
    print("[SoftLamp Manager] Script is loaded and working!")
    print("[SoftLamp Manager] Found " .. #GetAllSoftLamps() .. " soft lamps in scene")
end)

print("Soft Lamp Manager loaded! Press Y to open the lamp manager.")
print("Backup commands: 'softlamp_manager' to open menu, 'softlamp_manager_test' to test") 
