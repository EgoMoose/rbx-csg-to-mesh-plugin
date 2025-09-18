--!strict

--[[
this file is essentially a very bare-bones .rbxm binary reader which only reads the 3rd shared
string from the input buffer which is assumed to be the binary contents of an rbxm representing
exactly one local union
--]]

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local BufferStream = require(pluginRoot.Utilities.BufferStream)
local zstd = require(pluginRoot.Utilities.zstd)
local lz4 = require(pluginRoot.Utilities.lz4)

-- selene: allow(bad_string_escape)
local MAGIC_NUMBER = "<roblox!\x89\xff\x0d\x0a\x1a\x0a"

-- selene: allow(bad_string_escape)
local ZSTD_HEADER = "\x28\xB5\x2F\xFD"

type Extraction = {
	sharedStrings: { string },
}

local SharedString = {}

-- Private

local function readHeader(stream: BufferStream.BufferStream)
	assert(stream:readString(#MAGIC_NUMBER) == MAGIC_NUMBER, "rbxm binary header does not match")

	local modelVersion = stream:readu16()
	assert(modelVersion == 0, "Unsupported model version")

	local nClasses = stream:readu32()
	local nInstances = stream:readu32()

	stream:skipBytes(8)

	return {
		modelVersion = modelVersion,
		nClasses = nClasses,
		nInstances = nInstances,
	}
end

function readSSTRChunk(chunkStream: BufferStream.BufferStream, extraction: Extraction)
	local _version = chunkStream:readu32()
	local count = chunkStream:readu32()
	for _i = 1, count do
		local _hash = chunkStream:readString(16)

		local length = chunkStream:readu32()
		local sharedString = chunkStream:readString(length)

		table.insert(extraction.sharedStrings, sharedString)
	end
end

local function readChunk(stream: BufferStream.BufferStream, extraction: Extraction)
	local chunkType = stream:readString(4)
	local compressedLength = stream:readu32()
	local uncompressedLength = stream:readu32()

	stream:skipBytes(4)

	if chunkType ~= "END\0" then
		local content: buffer
		if compressedLength == 0 then
			content = buffer.fromstring(stream:readString(uncompressedLength))
		else
			local compressed = buffer.fromstring(stream:readString(compressedLength))
			if buffer.readstring(compressed, 0, 4) == ZSTD_HEADER then
				content = zstd.decompress(compressed)
			else
				content = lz4.decompress(compressed, 0, compressedLength, uncompressedLength)
			end
		end

		local chunkStream = BufferStream.new(content)
		if chunkType == "SSTR" then
			readSSTRChunk(chunkStream, extraction)
		end
	end

	return chunkType
end

local function extract(b: buffer)
	local extraction: Extraction = {
		sharedStrings = {},
	}

	local stream = BufferStream.new(b)
	local _header = readHeader(stream)

	repeat
		local chunkType = readChunk(stream, extraction)
	until chunkType == "END\0"

	return extraction
end

-- Public

function SharedString.readCSGMDLBuffer(b: buffer)
	local extraction = extract(b)
	return buffer.fromstring(extraction.sharedStrings[3])
end

--

return SharedString
