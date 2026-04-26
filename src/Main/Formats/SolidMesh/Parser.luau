--!strict

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local BufferStream = require(pluginRoot.Packages.BufferStream)

local Parser = {}

Parser.PADDING_BYTES = 14
Parser.HEADER = "SolidMesh\x00\x00\x00\x00"

-- Private

local function u8toi8(x: number)
	return if x >= 128 then x - 256 else x
end

local function readStateMachine(count: number, stream: BufferStream.BufferStream)
	local index = 0
	local indices = {}

	for _ = 1, count do
		local v0 = stream:readu8()
		if bit32.band(v0, bit32.lshift(1, 7)) == 0 then
			if bit32.band(v0, bit32.lshift(1, 6)) == 0 then
				index = index + v0
			else
				index = index + u8toi8(bit32.bor(v0, 0x80))
			end
		else
			local v1 = stream:readu8()
			local v2 = stream:readu8()
			index = index + bit32.bor(v2, bit32.lshift(v1, 8), bit32.lshift(bit32.band(v0, 0x7F), 16))
		end
		table.insert(indices, bit32.band(index, 0x7FFFFF))
	end

	return indices
end
-- Public

function Parser.parse(csgmdlBuffer: buffer)
	local stream = BufferStream.static(csgmdlBuffer)
	for _ = 1, Parser.PADDING_BYTES do
		stream:readu8()
	end
	assert(stream:readString(#Parser.HEADER) == Parser.HEADER, "Buffer is not a SolidMesh.")

	local positions = {}
	local nPositions = stream:readu32()
	stream:readu32()
	for i = 1, nPositions do
		local x, y, z = stream:readf32(), stream:readf32(), stream:readf32()
		positions[i] = Vector3.new(x, y, z)
	end

	local normals = {}
	local nNormals = stream:readu32()
	stream:readu32()
	for i = 1, nNormals do
		local x, y, z = stream:readf32(), stream:readf32(), stream:readf32()
		normals[i] = Vector3.new(x, y, z)
	end

	-- this might be UVs?
	local unknown1 = stream:readu32()
	stream:readu32()
	for _i = 1, unknown1 do
		stream:readf32()
		stream:readf32()
	end

	local colors = {}
	local nColors = stream:readu32()
	stream:readu32()
	for i = 1, nColors do
		local r, g, b = stream:readf32(), stream:readf32(), stream:readf32()
		colors[i] = { r, g, b }
	end

	local nFacesData = stream:readu32()
	stream:readu32()
	local faces = readStateMachine(nFacesData, stream)

	local nFaceNormalsData = stream:readu32()
	stream:readu32()
	local faceNormals = readStateMachine(nFaceNormalsData, stream)

	local nFaceUnknown1sData = stream:readu32()
	stream:readu32()
	pcall(function()
		local _faceUnknown1s = readStateMachine(nFaceUnknown1sData, stream)
	end)

	if nFaceUnknown1sData > 0 then
		error("Unknown data detected! Please report to EgoMoose with a copy of the union you are trying to convert.")
	end

	local nFaceColorsData = stream:readu32()
	stream:readu32()
	local faceColors = readStateMachine(nFaceColorsData, stream)

	return {
		positions = positions,
		normals = normals,
		colors = colors,

		faces = faces,
		faceNormals = faceNormals,
		faceColors = faceColors,
	}
end

--

return Parser
