--!strict

local BufferStreamStatic = {}

local BufferStreamClass = {}
BufferStreamClass.__index = BufferStreamClass
BufferStreamClass.ClassName = "BufferStream"

export type BufferStream = typeof(setmetatable(
	{} :: {
		b: buffer,
		cursor: number,
	},
	BufferStreamClass
))

function BufferStreamStatic.new(b: buffer)
	local self = setmetatable({}, BufferStreamClass) :: BufferStream

	self.b = b
	self.cursor = 0

	return self
end

-- Methods

function BufferStreamClass.skipBytes(self: BufferStream, bytes: number)
	self.cursor = self.cursor + bytes
end

function BufferStreamClass.readu8(self: BufferStream)
	local result = buffer.readu8(self.b, self.cursor)
	self.cursor = self.cursor + 1
	return result
end

function BufferStreamClass.readu16(self: BufferStream)
	local result = buffer.readu16(self.b, self.cursor)
	self.cursor = self.cursor + 2
	return result
end

function BufferStreamClass.readu32(self: BufferStream)
	local result = buffer.readu32(self.b, self.cursor)
	self.cursor = self.cursor + 4
	return result
end

function BufferStreamClass.readi8(self: BufferStream)
	local result = buffer.readi8(self.b, self.cursor)
	self.cursor = self.cursor + 1
	return result
end

function BufferStreamClass.readi16(self: BufferStream)
	local result = buffer.readi16(self.b, self.cursor)
	self.cursor = self.cursor + 2
	return result
end

function BufferStreamClass.readi32(self: BufferStream)
	local result = buffer.readi32(self.b, self.cursor)
	self.cursor = self.cursor + 4
	return result
end

function BufferStreamClass.readf32(self: BufferStream)
	local result = buffer.readf32(self.b, self.cursor)
	self.cursor = self.cursor + 4
	return result
end

function BufferStreamClass.readf64(self: BufferStream)
	local result = buffer.readf64(self.b, self.cursor)
	self.cursor = self.cursor + 8
	return result
end

function BufferStreamClass.readString(self: BufferStream, bytes: number)
	local result = buffer.readstring(self.b, self.cursor, bytes)
	self.cursor = self.cursor + bytes
	return result
end

--

return BufferStreamStatic
