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
local HEADER = "SolidMesh\x00\x00\x00\x00"
-- 14 bytes preceding

local Parser = {}

-- Private

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
	for _ = 1, 14 do
		stream:readu8()
	end
	assert(stream:readString(#HEADER) == HEADER, "Buffer is not CSGMDLV5")

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

	-- unknown?
	stream:readu32()
	stream:readu32()

	local colors = {}
	local nColors = stream:readu32()
	stream:readu32()
	for i = 1, nColors do
		local r, g, b = stream:readf32(), stream:readf32(), stream:readf32()
		colors[i] = { r, g, b }
	end

	local vertexData = {}
	local nVertices = stream:readu32()
	stream:readu32()
	for i = 1, nVertices do
		vertexData[i] = stream:readu8()
	end

	local indices = readStateMachine(vertexData, nVertices)

	return {
		positions = positions,
		normals = normals,
		colors = colors,
		faces = indices,
	}
end

--

return Parser
