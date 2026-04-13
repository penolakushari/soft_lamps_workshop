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

return {
    colors = {
		disabled = Color(128, 128, 128),
		gameplay = Color(255, 255, 0),
		heavylight = Color(255, 128, 0),
		enabled = Color(0, 255, 0),
	},
    get = getSoftLampState
}