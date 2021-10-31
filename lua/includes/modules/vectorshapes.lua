AddCSLuaFile()

module("vectorshapes", package.seeall)

local shapes = {}

function AddShape(name, nicename, func, recommendedMaxLayers)
	name = string.lower(name)

	local tab = {
		name = name,
		nicename = nicename,
		func = func,
		max = recommendedMaxLayers	-- optional, can be nil/undefined
	}

	shapes[name] = tab
	return name
end

function RemoveShape(name)
	shapes[name] = nil
end

function GetShapes()
	return shapes	-- this is "unsafe" since callers can modify our internal tables, but if they really want to do that, their headache.
end
function GetTable()	-- alias. I wonder if there's a way to make it actually point to the same function, when talking about a module...?
	return shapes
end

function MakeShape(name, radius, layers, up, right, ...)
	name = string.lower(name)
	local shape = shapes[name]
	if !shape then
		-- Default to single point
		local vec = Vector(0, 0, 0)
		local vectors = { layers = { { vec } }, all = { vec } }
		return vectors
	end

	return shape.func(radius, layers, up, right, ...)
end

if CLIENT then language.Add("vectorshapes.point", "Point") end
AddShape("point", "#vectorshapes.point", function()
	local vec = Vector(0, 0, 0)
	local vectors = { layers = { { vec } }, all = { vec } }
	return vectors
end)

if CLIENT then language.Add("vectorshapes.line", "Line") end
AddShape("line", "#vectorshapes.line", function(radius, layers, up, right)
	if layers <= 1 then		-- If you're making new shapes, always have this at the top!
		local vec = Vector(0, 0, 0)
		local vectors = { layers = { { vec } }, all = { vec } }
		return vectors
	end

	right = right or Vector(0, 1, 0)

	local vectors = { layers = {}, all = {} }

	-- distance between 2 points
	local distance = (radius * 2) / (layers - 1)

	for layer = 1, layers do
		vectors.layers[layer] = {}

		local vec = (radius - (distance * (layer-1))) * right

		table.insert(vectors.layers[layer], vec)
		table.insert(vectors.all, vec)
	end

	return vectors
end)

if CLIENT then language.Add("vectorshapes.circle", "Circle (outline)") end
AddShape("circle", "#vectorshapes.circle", function(radius, layers, up, right)
	if layers <= 1 then
		local vec = Vector(0, 0, 0)
		local vectors = { layers = { { vec } }, all = { vec } }
		return vectors
	end

	up = up or Vector(0, 0, 1)
	right = right or Vector(0, 1, 0)

	local vectors = { layers = {}, all = {} }

	for layer = 1, layers do
		vectors.layers[layer] = {}

		local ang = layer * 2 * math.pi / layers
		local vec = radius * math.sin(ang) * right + radius * math.cos(ang) * up

		table.insert(vectors.layers[layer], vec)
		table.insert(vectors.all, vec)
	end

	return vectors
end)

if CLIENT then language.Add("vectorshapes.cross", "Cross") end
AddShape("cross", "#vectorshapes.cross", function(radius, layers, up, right)
	if layers <= 1 then
		local vec = Vector(0, 0, 0)
		local vectors = { layers = { { vec } }, all = { vec } }
		return vectors
	end

	up = up or Vector(0, 0, 1)
	right = right or Vector(0, 1, 0)

	local vectors = { layers = {}, all = {} }

	-- layer 1 is just one light in the center:
	vectors.layers[1] = {}
	local vec = Vector(0, 0, 0)
	table.insert(vectors.layers[1], vec)
	table.insert(vectors.all, vec)

	local distance = radius / (layers - 1)

	-- Make a + shape with layers 2+
	for layer = 2, layers do
		vectors.layers[layer] = {}

		local vec1 = (layer - 1) * distance * up
		local vec2 = (layer - 1) * distance * -up
		local vec3 = (layer - 1) * distance * right
		local vec4 = (layer - 1) * distance * -right
		table.insert(vectors.layers[layer], vec1)
		table.insert(vectors.layers[layer], vec2)
		table.insert(vectors.layers[layer], vec3)
		table.insert(vectors.layers[layer], vec4)
		table.insert(vectors.all, vec1)
		table.insert(vectors.all, vec2)
		table.insert(vectors.all, vec3)
		table.insert(vectors.all, vec4)
	end

	return vectors
end)

if CLIENT then language.Add("vectorshapes.disk", "Disk") end
AddShape("disk", "#vectorshapes.disk", function(radius, layers, up, right)
	if layers <= 1 then
		local vec = Vector(0, 0, 0)
		local vectors = { layers = { { vec } }, all = { vec } }
		return vectors
	end

	-- This is modified Cross code. It makes a square,
	-- but for each point, checks if it's within the circle and if not, doesn't add it.

	up = up or Vector(0, 0, 1)
	right = right or Vector(0, 1, 0)

	local vectors = { layers = {}, all = {} }

	-- layer 1 is the center:
	vectors.layers[1] = {}
	local vec = Vector(0, 0, 0)
	table.insert(vectors.layers[1], vec)
	table.insert(vectors.all, vec)

	local distance = radius / (layers - 1)

	-- Make the rest of the disk:
	for layer = 2, layers do
		vectors.layers[layer] = {}

		local l = layer-1	-- layers away from center

		-- ceiling and floor:
		local top = l * distance * up
		local bottom = -top

		for x = -l, l do
			if math.Distance(x, l, 0, 0) > (layers - 0.5) then continue end	-- check whether the points we're about to draw are within the circle. Symmetry says it applies to both.

			local xvec = x * distance * right

			local vec1 = xvec + top
			local vec2 = xvec + bottom

			table.insert(vectors.layers[layer], vec1)
			table.insert(vectors.layers[layer], vec2)
			table.insert(vectors.all, vec1)
			table.insert(vectors.all, vec2)
		end

		-- walls:
		local rightwall = l * distance * right
		local leftwall = -rightwall

		for y = -(l-1), (l-1) do	-- skip the corners since they were part of the ceiling and floor
			if math.Distance(l, y, 0, 0) > (layers - 0.5) then continue end	-- check whether the points we're about to draw are within the circle. Symmetry says it applies to both.

			local yvec = y * distance * up

			local vec1 = yvec + rightwall
			local vec2 = yvec + leftwall

			table.insert(vectors.layers[layer], vec1)
			table.insert(vectors.layers[layer], vec2)
			table.insert(vectors.all, vec1)
			table.insert(vectors.all, vec2)
		end
	end

	return vectors
end, 6)

if CLIENT then language.Add("vectorshapes.square", "Square") end
AddShape("square", "#vectorshapes.square", function(radius, layers, up, right)
	if layers <= 1 then
		local vec = Vector(0, 0, 0)
		local vectors = { layers = { { vec } }, all = { vec } }
		return vectors
	end

	up = up or Vector(0, 0, 1)
	right = right or Vector(0, 1, 0)

	local vectors = { layers = {}, all = {} }

	-- distance between 2 points
	local distance = (radius * 2) / (layers - 1)

	for layer = 1, layers do
		vectors.layers[layer] = {}

		-- diagonal line:
		local vec = (radius - (distance * (layer-1))) * (right + up)

		table.insert(vectors.layers[layer], vec)
		table.insert(vectors.all, vec)

		-- below and to the left of the diagonal line (rest of the area)
		for i = 1, layer-1 do
			local vec1 = vec + (distance * i * up)
			local vec2 = vec + (distance * i * right)
			table.insert(vectors.layers[layer], vec1)
			table.insert(vectors.layers[layer], vec2)
			table.insert(vectors.all, vec1)
			table.insert(vectors.all, vec2)
		end
	end

	return vectors
end, 6)

if CLIENT then language.Add("vectorshapes.hexagon", "Hexagon") end
AddShape("hexagon", "#vectorshapes.hexagon", function(radius, layers, up, right)
	if layers <= 1 then
		local vec = Vector(0, 0, 0)
		local vectors = { layers = { { vec } }, all = { vec } }
		return vectors
	end

	up = up or Vector(0, 0, 1)
	right = right or Vector(0, 1, 0)

	local upleft = -right/2 + math.sin(math.pi / 3) * up	-- -right/2 is because cos(math.pi/3) = 1/2

	local vectors = { layers = {}, all = {} }

	-- distance between 2 points
	local distance = radius / (layers - 1)

	for layer = 1, layers do
		vectors.layers[layer] = {}

		local lastRow = (2 * layer - 1)	-- how many rows this layer has

		for row = 1, lastRow do
			local hollowRow = row > 1 and row < lastRow	-- is this row hollow: true/false
			local vecs = math.min(layer + row - 1, layer + lastRow - row)	-- late night math.. this is how many vecs exist on this row in total

			for i = 1, vecs do
				if (hollowRow and i != 1 and i != vecs) then continue end	-- skip vecs that already exist as part of previous layers

				local rights = math.min(layer, lastRow + 1 - row) - i	-- more late night math, how many steps need to be taken right
				local uplefts = ((lastRow + 1) / 2) - row	-- MORE late night math, how many steps need to be taken up-left diagonally

				local vec = distance * rights  * right +
							distance * uplefts * upleft
				table.insert(vectors.layers[layer], vec)
				table.insert(vectors.all, vec)
			end
		end
	end

	return vectors
end, 4)
