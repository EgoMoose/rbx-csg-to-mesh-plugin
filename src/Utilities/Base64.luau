--!strict
--cspell:disable

-- https://github.com/TokenManiac/Base64
-- Base64 (Luau) — big-buffer hot path (encode uses readu32)
-- • ENCODE per 3 bytes: 1×READ_U32 + 2 LUT hits + 1×WRITE_U32
-- • DECODE per 4 chars: 1×READ_U32 + 2 LUT hits + 3 byte-LUT hits + 3 stores
-- • No bit32. Arithmetic only. ×2 unroll. Strings -> buffer once.

local BUF_CREATE, BUF_LEN, BUF_TOSTRING, BUF_FROMSTRING = buffer.create, buffer.len, buffer.tostring, buffer.fromstring
local READ_U8, READ_U16, READ_U32 = buffer.readu8, buffer.readu16, buffer.readu32
local WRITE_U8, WRITE_U16, WRITE_U32 = buffer.writeu8, buffer.writeu16, buffer.writeu32

local EQ = 61
local ALPH_STR = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Alphabet (bytes) — used in tails
local ALPH = table.create(64)
for i = 1, 64 do
	ALPH[i] = string.byte(ALPH_STR, i)
end

-- ================= ENCODE LUTs =================
-- ENC_A: (b0 + b1*256) -> u16 of two chars [s0 s1]
-- ENC_B: (b1 + b2*256) -> u16 of two chars [s2 s3]
local ENC_A = table.create(65536)
local ENC_B = table.create(65536)
do
	for b0 = 0, 255 do
		local s0 = b0 // 4
		local s0c = ALPH[s0 + 1]
		local b0low = b0 % 4
		for b1 = 0, 255 do
			local s1 = b0low * 16 + (b1 // 16)
			ENC_A[b0 + b1 * 256 + 1] = s0c + ALPH[s1 + 1] * 256
		end
	end
	for b1 = 0, 255 do
		local nib = (b1 % 16) * 4
		for b2 = 0, 255 do
			local s2 = nib + (b2 // 64)
			local s3 = b2 % 64
			ENC_B[b1 + b2 * 256 + 1] = ALPH[s2 + 1] + ALPH[s3 + 1] * 256
		end
	end
end

-- ================= DECODE LUTs =================
-- sextet decode: 0..127 => 0..63, -2 for '=', -1 invalid
local DEC6 = table.create(129, -1)
for i = 1, 64 do
	DEC6[ALPH[i] + 1] = i - 1
end
DEC6[EQ + 1] = -2

-- pair decode: key = (c0 + c1*256) + 1 -> 0..4095, -2 if '=' present, -1 invalid
local DEC12 = table.create(32768, -1)
do
	for c0 = 0, 127 do
		local d0 = DEC6[c0 + 1]
		for c1 = 0, 127 do
			local d1 = DEC6[c1 + 1]
			local k = c0 + c1 * 256 + 1
			if d0 >= 0 and d1 >= 0 then
				DEC12[k] = d0 * 64 + d1
			elseif d0 == -2 or d1 == -2 then
				DEC12[k] = -2
			end
		end
	end
end

-- Precomputed byte reconstruction (no math in loop)
-- a = s0*64+s1, b = s2*64+s3
local A_B0 = table.create(4096) -- b0 from 'a'
local A_B1HI = table.create(4096) -- high nibble of b1 from 'a'
local B_B1LO = table.create(4096) -- low nibble  of b1 from 'b'
local B_B2 = table.create(4096) -- b2 from 'b'
do
	for a = 0, 4095 do
		local s0, s1 = a // 64, a % 64
		A_B0[a + 1] = s0 * 4 + (s1 // 16)
		A_B1HI[a + 1] = (s1 % 16) * 16
	end
	for b = 0, 4095 do
		local s2, s3 = b // 64, b % 64
		B_B1LO[b + 1] = s2 // 4
		B_B2[b + 1] = (s2 % 4) * 64 + s3
	end
end

local function encLen(n: number): number
	return ((n + 2) // 3) * 4
end
local function decLen(n: number, pad: number): number
	return (n // 4) * 3 - pad
end

-- ================= ENCODE =================
local function encodeFromBuffer(inBuf: buffer): string
	local n = BUF_LEN(inBuf)
	if n == 0 then
		return ""
	end
	local out = BUF_CREATE(encLen(n))
	local encA, encB = ENC_A, ENC_B
	local i, o = 0, 0
	local fullEnd = n - (n % 3)

	if READ_U32 ~= nil and WRITE_U32 ~= nil then
		-- ×2 unroll: process 12 input bytes -> 16 output chars (4× u32 stores)
		-- Safe stop so that READ_U32(inBuf, i+9) has 4 bytes available: i <= n - 13
		local stop = n - 13
		while i <= stop do
			local w0 = READ_U32(inBuf, i) -- b0..b3
			local w1 = READ_U32(inBuf, i + 3) -- b3..b6
			local w2 = READ_U32(inBuf, i + 6) -- b6..b9
			local w3 = READ_U32(inBuf, i + 9) -- b9..b12

			-- Triplet 0 from w0
			local kA0 = w0 % 65536 -- b0 + b1*256
			local kB0 = (w0 // 256) % 65536 -- b1 + b2*256
			WRITE_U32(out, o, encA[kA0 + 1] + encB[kB0 + 1] * 0x10000)

			-- Triplet 1 from w1
			local kA1 = w1 % 65536
			local kB1 = (w1 // 256) % 65536
			WRITE_U32(out, o + 4, encA[kA1 + 1] + encB[kB1 + 1] * 0x10000)

			-- Triplet 2 from w2
			local kA2 = w2 % 65536
			local kB2 = (w2 // 256) % 65536
			WRITE_U32(out, o + 8, encA[kA2 + 1] + encB[kB2 + 1] * 0x10000)

			-- Triplet 3 from w3
			local kA3 = w3 % 65536
			local kB3 = (w3 // 256) % 65536
			WRITE_U32(out, o + 12, encA[kA3 + 1] + encB[kB3 + 1] * 0x10000)

			i += 12
			o += 16
		end
		-- remainder triplets (single step) — use u16+u8 loads to avoid over-reads
		while i < fullEnd do
			local kA = READ_U16(inBuf, i)
			local b2 = READ_U8(inBuf, i + 2)
			local kB = (kA // 256) + b2 * 256
			WRITE_U32(out, o, encA[kA + 1] + encB[kB + 1] * 0x10000)
			i += 3
			o += 4
		end
	else
		-- Fallback: 1×u16 + 1×u8 per triplet, 2×u16 store
		while i < fullEnd do
			local kA = READ_U16(inBuf, i)
			local b2 = READ_U8(inBuf, i + 2)
			local kB = (kA // 256) + b2 * 256
			WRITE_U16(out, o, encA[kA + 1])
			WRITE_U16(out, o + 2, encB[kB + 1])
			i += 3
			o += 4
		end
	end

	-- Tail (1 or 2 bytes) — tiny & branch-predictable
	local rem = n - i
	if rem == 1 then
		local b0 = READ_U8(inBuf, i)
		local s0 = b0 // 4
		local s1 = (b0 % 4) * 16
		local p = ALPH[s0 + 1] + ALPH[s1 + 1] * 256
		if WRITE_U16 ~= nil then
			WRITE_U16(out, o, p)
			WRITE_U8(out, o + 2, EQ)
			WRITE_U8(out, o + 3, EQ)
		else
			WRITE_U8(out, o, p % 256)
			WRITE_U8(out, o + 1, p // 256)
			WRITE_U8(out, o + 2, EQ)
			WRITE_U8(out, o + 3, EQ)
		end
	elseif rem == 2 then
		local b0 = READ_U8(inBuf, i)
		local b1 = READ_U8(inBuf, i + 1)
		local kA = b0 + b1 * 256
		if WRITE_U16 ~= nil then
			WRITE_U16(out, o, ENC_A[kA + 1])
		else
			local p = ENC_A[kA + 1]
			WRITE_U8(out, o, p % 256)
			WRITE_U8(out, o + 1, p // 256)
		end
		local s2 = (b1 % 16) * 4
		WRITE_U8(out, o + 2, ALPH[s2 + 1])
		WRITE_U8(out, o + 3, EQ)
	end

	return BUF_TOSTRING(out)
end

-- ================= DECODE =================
local function decodeToBufferFromBuffer(inBuf: buffer): buffer
	local n = BUF_LEN(inBuf)
	if (n % 4) ~= 0 then
		error("Invalid Base64 length")
	end
	if n == 0 then
		return BUF_CREATE(0)
	end

	local pad = 0
	if READ_U8(inBuf, n - 1) == EQ then
		pad = 1
		if READ_U8(inBuf, n - 2) == EQ then
			pad = 2
		end
	end

	local out = BUF_CREATE(decLen(n, pad))
	local i, o = 0, 0
	local bodyEnd = n - 4

	if READ_U32 ~= nil then
		-- ×2 unroll: 8 chars -> 6+6 bytes
		local stop = bodyEnd - 8
		while i <= stop do
			local w0 = READ_U32(inBuf, i) -- c0..c3
			local w1 = READ_U32(inBuf, i + 4) -- c4..c7

			local a0 = DEC12[w0 % 65536 + 1]
			if not a0 or a0 < 0 then
				error("Invalid Base64")
			end
			local b0 = DEC12[w0 // 65536 + 1]
			if not b0 or b0 < 0 then
				error("Invalid Base64")
			end
			WRITE_U8(out, o, A_B0[a0 + 1])
			WRITE_U8(out, o + 1, A_B1HI[a0 + 1] + B_B1LO[b0 + 1])
			WRITE_U8(out, o + 2, B_B2[b0 + 1])

			local a1 = DEC12[w1 % 65536 + 1]
			if not a1 or a1 < 0 then
				error("Invalid Base64")
			end
			local b1 = DEC12[w1 // 65536 + 1]
			if not b1 or b1 < 0 then
				error("Invalid Base64")
			end
			WRITE_U8(out, o + 3, A_B0[a1 + 1])
			WRITE_U8(out, o + 4, A_B1HI[a1 + 1] + B_B1LO[b1 + 1])
			WRITE_U8(out, o + 5, B_B2[b1 + 1])

			i += 8
			o += 6
		end
		while i <= bodyEnd - 4 do
			local w = READ_U32(inBuf, i)
			local a = DEC12[w % 65536 + 1]
			if not a or a < 0 then
				error("Invalid Base64")
			end
			local b = DEC12[w // 65536 + 1]
			if not b or b < 0 then
				error("Invalid Base64")
			end
			WRITE_U8(out, o, A_B0[a + 1])
			WRITE_U8(out, o + 1, A_B1HI[a + 1] + B_B1LO[b + 1])
			WRITE_U8(out, o + 2, B_B2[b + 1])
			i += 4
			o += 3
		end
	else
		-- Fallback: two u16 loads per quartet
		local stop = bodyEnd - 4
		while i <= stop do
			local kA = READ_U16(inBuf, i)
			local kB = READ_U16(inBuf, i + 2)
			local kC = READ_U16(inBuf, i + 4)
			local kD = READ_U16(inBuf, i + 6)
			local a0 = DEC12[kA + 1]
			if not a0 or a0 < 0 then
				error("Invalid Base64")
			end
			local b0 = DEC12[kB + 1]
			if not b0 or b0 < 0 then
				error("Invalid Base64")
			end
			local a1 = DEC12[kC + 1]
			if not a1 or a1 < 0 then
				error("Invalid Base64")
			end
			local b1 = DEC12[kD + 1]
			if not b1 or b1 < 0 then
				error("Invalid Base64")
			end
			WRITE_U8(out, o, A_B0[a0 + 1])
			WRITE_U8(out, o + 1, A_B1HI[a0 + 1] + B_B1LO[b0 + 1])
			WRITE_U8(out, o + 2, B_B2[b0 + 1])
			WRITE_U8(out, o + 3, A_B0[a1 + 1])
			WRITE_U8(out, o + 4, A_B1HI[a1 + 1] + B_B1LO[b1 + 1])
			WRITE_U8(out, o + 5, B_B2[b1 + 1])
			i += 8
			o += 6
		end
		while i <= bodyEnd - 4 do
			local kA = READ_U16(inBuf, i)
			local kB = READ_U16(inBuf, i + 2)
			local a = DEC12[kA + 1]
			if not a or a < 0 then
				error("Invalid Base64")
			end
			local b = DEC12[kB + 1]
			if not b or b < 0 then
				error("Invalid Base64")
			end
			WRITE_U8(out, o, A_B0[a + 1])
			WRITE_U8(out, o + 1, A_B1HI[a + 1] + B_B1LO[b + 1])
			WRITE_U8(out, o + 2, B_B2[b + 1])
			i += 4
			o += 3
		end
	end

	-- Tail (handles '=')
	do
		local c0 = READ_U8(inBuf, i)
		local c1 = READ_U8(inBuf, i + 1)
		local c2 = READ_U8(inBuf, i + 2)
		local c3 = READ_U8(inBuf, i + 3)
		local d0 = DEC6[c0 + 1]
		if not d0 or d0 < 0 then
			error("Invalid Base64")
		end
		local d1 = DEC6[c1 + 1]
		if not d1 or d1 < 0 then
			error("Invalid Base64")
		end

		if c2 == EQ then
			-- If c2 is '=', c3 must also be '=' per spec
			if c3 ~= EQ then
				error("Invalid Base64")
			end
			local a = d0 * 64 + d1
			WRITE_U8(out, o, A_B0[a + 1])
		elseif c3 == EQ then
			local d2 = DEC6[c2 + 1]
			if not d2 or d2 < 0 then
				error("Invalid Base64")
			end
			local a = d0 * 64 + d1
			local b = d2 * 64
			WRITE_U8(out, o, A_B0[a + 1])
			WRITE_U8(out, o + 1, A_B1HI[a + 1] + (b // 256))
		else
			local d2 = DEC6[c2 + 1]
			if not d2 or d2 < 0 then
				error("Invalid Base64")
			end
			local d3 = DEC6[c3 + 1]
			if not d3 or d3 < 0 then
				error("Invalid Base64")
			end
			local a = d0 * 64 + d1
			local b = d2 * 64 + d3
			WRITE_U8(out, o, A_B0[a + 1])
			WRITE_U8(out, o + 1, A_B1HI[a + 1] + (b // 256))
			WRITE_U8(out, o + 2, B_B2[b + 1])
		end
	end

	return out
end

-- ================= API =================
local function base64_encode(input: string | buffer): string
	local inBuf: buffer = ((typeof and typeof(input) == "buffer") or type(input) == "userdata") and (input :: buffer)
		or BUF_FROMSTRING(input :: string)
	return encodeFromBuffer(inBuf)
end
local function base64_decode(input: string | buffer): string
	local inBuf: buffer = ((typeof and typeof(input) == "buffer") or type(input) == "userdata") and (input :: buffer)
		or BUF_FROMSTRING(input :: string)
	return BUF_TOSTRING(decodeToBufferFromBuffer(inBuf))
end

return { encode = base64_encode, decode = base64_decode }
