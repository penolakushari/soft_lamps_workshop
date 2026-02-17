---Module to help do frustrum checks between lamps and view
---This helps optimize soft lamp render times for lighting
---which isn't in view

---@class FrustrumVertices
---@field topleft Vector
---@field topright Vector
---@field bottomleft Vector
---@field bottomright Vector

---@class FrustrumPlanes
---@field near Vector
---@field far Vector
---@field left Vector
---@field right Vector
---@field up Vector
---@field down Vector

---@class FrustrumDistances
---@field near number
---@field far number
---@field left number
---@field right number
---@field up number
---@field down number

---@class FrustrumData
---@field vertices {far: FrustrumVertices, near: FrustrumVertices}
---@field planes FrustrumPlanes
---@field distances FrustrumDistances


---@param view ViewSetup
---@return FrustrumData
local function GetFrustrum(view)
	local aspect = view.aspect
	local angles = view.angles
	local origin = view.origin
	local fov = view.fov_unscaled
	local nearz = view.znear
	local farz = view.zfar

	local forward = angles:Forward()
	local right = angles:Right()
	local up = angles:Up()

	local endFog = 9000
	farz = math.min(farz, endFog)

	local hNear = math.tan(math.rad(fov) * 0.5) * nearz
	local hFar = math.tan(math.rad(fov) * 0.5) * farz
	local wNear = hNear * aspect
	local wFar = hFar * aspect

	local nearCenter = origin + nearz*forward
	local farCenter = origin + farz*forward
	---@type FrustrumVertices
	local nearData = {
		topleft = nearCenter - right*wNear + up*hNear,
		topright = nearCenter + right*wNear + up*hNear,
		bottomleft = nearCenter - right*wNear - up*hNear,
		bottomright = nearCenter + right*wNear - up*hNear,
	}
	---@type FrustrumVertices
	local farData = {
		topleft = farCenter - right*wFar + up*hFar,
		topright = farCenter + right*wFar + up*hFar,
		bottomleft = farCenter - right*wFar - up*hFar,
		bottomright = farCenter + right*wFar - up*hFar,	
	}

	local centerData = {
		near = nearCenter,
		far = farCenter,
		left = (farData.topleft + nearData.bottomleft + farData.bottomleft + nearData.topleft) * 0.25,
		right = (farData.topright + nearData.bottomright + farData.bottomright + nearData.topright) * 0.25,
		up = (farData.topleft + nearData.topright + farData.topright + nearData.topleft) * 0.25,
		down = (farData.bottomleft + nearData.bottomright + farData.bottomright + nearData.bottomleft) * 0.25,
	}

	local planeData = {
		near = forward,
		far = -forward,
		left = (forward * nearz - right * wNear):GetNormalized():Cross(up),
		right = (forward * nearz + right * wNear):GetNormalized():Cross(-up),
		up = (forward * nearz + up * hNear):GetNormalized():Cross(right),
		down = (forward * nearz - up * hNear):GetNormalized():Cross(-right)
	}


	return {
		vertices = {
			far = farData,
			near = nearData
		},
		planes = planeData,
		distances = {
			near = -planeData.near:Dot(centerData.near),
			far = -planeData.far:Dot(centerData.far),
			up = -planeData.up:Dot(centerData.up),
			down = -planeData.down:Dot(centerData.down),
			right = -planeData.right:Dot(centerData.right),
			left = -planeData.left:Dot(centerData.left),
		}
	}
end

---@param frustrum FrustrumData
---@return Vector[]
local function GetFrustrumEdges(frustrum)
	return {
		frustrum.vertices.far.topleft - frustrum.vertices.near.topleft,
		frustrum.vertices.far.topright - frustrum.vertices.near.topright,
		frustrum.vertices.far.bottomleft - frustrum.vertices.near.bottomleft,
		frustrum.vertices.far.bottomright - frustrum.vertices.near.bottomright,
		frustrum.vertices.far.topright - frustrum.vertices.far.topleft,
		frustrum.vertices.far.topright - frustrum.vertices.far.bottomright,
	}
end

---@param view FrustrumData
---@param lamp FrustrumData
---@return boolean
local function FrustrumInViewFrustrum(view, lamp)
	local viewEdges = GetFrustrumEdges(view)
	local lampEdges = GetFrustrumEdges(lamp)

	local count = #viewEdges
	---@type Vector[]
	local crosses = {}
	for i = 1, count do
		for j = 1, count do
			table.insert(crosses, viewEdges[i]:Cross(lampEdges[j]):GetNormalized())
		end
	end

	for _, l in ipairs(crosses) do
		local minA, maxA = math.huge, -math.huge
		local minB, maxB = math.huge, -math.huge
		for _, vertex in pairs(view.vertices.far) do
			local val = l:Dot(vertex)
			if val < minA then
				minA = val
			end
			if val > maxA then
				maxA = val
			end 
		end
		for _, vertex in pairs(view.vertices.near) do
			local val = l:Dot(vertex)
			if val < minA then
				minA = val
			end
			if val > maxA then
				maxA = val
			end 
		end

		for _, vertex in pairs(lamp.vertices.far) do
			local val = l:Dot(vertex)
			if val < minB then
				minB = val
			end
			if val > maxB then
				maxB = val
			end 
		end
		for _, vertex in pairs(lamp.vertices.near) do
			local val = l:Dot(vertex)
			if val < minB then
				minB = val
			end
			if val > maxB then
				maxB = val
			end 
		end

		local gap = minA > maxB or minB > maxA
		if gap then return false end
	end
		
	return true
end

---@param view FrustrumData
---@param pos Vector
---@param radius number
---@return boolean
local function SphereInViewFrustrum(view, pos, radius)

	for key, normal in pairs(view.planes) do
		---@cast normal Vector
		
		local d = view.distances[key]
		local dist = normal:Dot(pos) + d
		-- print("sphere outside frustrum?", key, dist < -radius)
		if dist < -radius then
			return false
		end
	end

	return true
end

return {
    get = GetFrustrum,
    intersectsFrustrum = FrustrumInViewFrustrum,
	intersectsSphere = SphereInViewFrustrum,
}