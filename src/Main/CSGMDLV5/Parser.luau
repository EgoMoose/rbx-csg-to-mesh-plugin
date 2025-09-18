--!strict

--[[
Permission is hereby granted, free of charge, to any
person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the
Software without restriction, including without
limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice
shall be included in all copies or substantial portions
of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

https://github.com/krakow10/rbx_mesh
--]]

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local BufferStream = require(pluginRoot.Utilities.BufferStream)

-- stylua: ignore
local OBFUSCATION_NOISE_CYCLE_XOR = {
	86, 46, 110, 88, 49, 32, 48, 4,
	52, 105, 12, 119, 12, 1, 94, 0,
	26, 96, 55, 105, 29, 82, 43, 7,
	79, 36, 89, 101, 83, 4, 122
}

local function _deobfuscate(b: buffer, offset: number)
	local n = #OBFUSCATION_NOISE_CYCLE_XOR
	for i = 0, buffer.len(b) - 1 do
		local u8 = buffer.readu8(b, i)
		buffer.writeu8(b, i, bit32.bxor(u8, OBFUSCATION_NOISE_CYCLE_XOR[((offset + i) % n) + 1]))
	end
	return b
end

-- selene: allow(bad_string_escape)
local HEADER = "\x15\x7d\x29\x15\x75\x6c\x35\x04\x34\x69"
-- equiv to: buffer.tostring(_deobfuscate(buffer.fromstring("CSGMDL\x05\x00\x00\x00"), 0))
-- which is simply "CSGMDL5" where 5 is a u32 in little endian byte ordering
-- the other formats require this deobfuscation throughout, but in v5 it's only the header

local Parser = {}

-- Private

local function wrapNumber(x: number, min: number, max: number)
	local range = max - min
	local wrapped = (x - min) % range
	if wrapped < 0 then
		wrapped = wrapped + range
	end
	return wrapped + min
end

local function quantize(x: number, bits: number)
	local max = 2 ^ bits - 1
	return wrapNumber(x - max, -max - 1, max + 1) / max
end

local function u8toi8(x: number)
	return if x >= 128 then x - 256 else x
end

local function readStateMachine(data: { number }, count: number)
	local index = 0
	local indices = {}

	local j = 0
	local function iterNext()
		j = j + 1
		return data[j]
	end

	for _ = 1, count do
		local v0 = iterNext()
		if bit32.band(v0, bit32.lshift(1, 7)) == 0 then
			if bit32.band(v0, bit32.lshift(1, 6)) == 0 then
				index = index + v0
			else
				index = index + u8toi8(bit32.bor(v0, 0x80))
			end
		else
			local v1 = iterNext()
			local v2 = iterNext()
			index = index + bit32.bor(v2, bit32.lshift(v1, 8), bit32.lshift(bit32.band(v0, 0x7F), 16))
		end
		table.insert(indices, bit32.band(index, 0x7FFFFF))
	end

	return indices
end

-- Public

function Parser.parse(csgmdlBuffer: buffer)
	local stream = BufferStream.new(csgmdlBuffer)
	assert(stream:readString(10) == HEADER, "Buffer is not CSGMDLV5")

	local positions = {}
	local nPositions = stream:readu16()
	for i = 1, nPositions do
		local x, y, z = stream:readf32(), stream:readf32(), stream:readf32()
		positions[i] = Vector3.new(x, y, z)
	end

	local normals = {}
	local nNormals = stream:readu16()
	stream:readu32() -- number of bytes containing the components: nNormals * 3 (components) * 2 (bytes, i16)
	for i = 1, nNormals do
		local x, y, z = stream:readi16(), stream:readi16(), stream:readi16()
		normals[i] = Vector3.new(quantize(x, 15), quantize(y, 15), quantize(z, 15))
	end

	local colors = {}
	local nColors = stream:readu16()
	for i = 1, nColors do
		local r, g, b, a = stream:readu8(), stream:readu8(), stream:readu8(), stream:readu8()
		colors[i] = { r, g, b, a }
	end

	local normalIds = {}
	local nNormalIds = stream:readu16()
	for i = 1, nNormalIds do
		-- 1 = right, 2 = top, 3 = back, 4 = left, 5 = bottom, 6 = front
		normalIds[i] = stream:readu8()
	end

	local uvs = {}
	local nUvs = stream:readu16()
	for i = 1, nUvs do
		local u, v = stream:readf32(), stream:readf32()
		uvs[i] = Vector2.new(u, v)
	end

	local tangents = {}
	local nTangents = stream:readu16()
	stream:readu32() -- number of bytes containing the components: nTangents * 3 (components) * 2 (bytes, i16)
	for i = 1, nTangents do
		local x, y, z = stream:readi16(), stream:readi16(), stream:readi16()
		tangents[i] = Vector3.new(quantize(x, 15), quantize(y, 15), quantize(z, 15))
	end

	local _nVertices = stream:readu32()
	local nVertexData = stream:readu32()
	local vertexData = {}
	for i = 1, nVertexData do
		vertexData[i] = stream:readu8()
	end

	local rangeMarker = stream:readu8()
	local _rangeStart = stream:readu32()
	local rangeEnd = stream:readu32()

	if rangeMarker == 3 then
		stream:readu32() -- additional range?
	end

	local indices = readStateMachine(vertexData, rangeEnd)

	return {
		positions = positions,
		normals = normals,
		colors = colors,
		normalIds = normalIds,
		uvs = uvs,
		tangents = tangents,
		faces = indices,
	}
end

--

return Parser
