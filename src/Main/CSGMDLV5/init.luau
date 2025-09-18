local SerializationService = game:GetService("SerializationService") :: SerializationService

local SharedString = require(script.SharedString)

local CSGMDLV5Static = {}

local CSGMDLV5Class = {}
CSGMDLV5Class.__index = CSGMDLV5Class
CSGMDLV5Class.ClassName = "CSGMDLV5"

export type CSGMDLV5 = typeof(setmetatable({} :: {}, CSGMDLV5Class))

-- Constructors

function CSGMDLV5Static.new(b: buffer)
	local self = setmetatable({}, CSGMDLV5Class) :: CSGMDLV5

	print(b)

	return self
end

function CSGMDLV5Static.fromPart(part: BasePart): (boolean, string, CSGMDLV5?)
	local csg: UnionOperation?
	local success, err = pcall(function()
		if part:IsA("PartOperation") then
			csg = part:UnionAsync({}, part.CollisionFidelity, part.RenderFidelity)
		else
			csg = part:UnionAsync({})
		end
	end)

	if not success then
		return success, err
	end

	local csgmdl: CSGMDLV5?
	if csg then
		local serialized = SerializationService:SerializeInstancesAsync({ csg })
		csg:Destroy()
		local csgmdlBuffer = SharedString.readCSGMDLBuffer(serialized)
		csgmdl = CSGMDLV5Static.new(csgmdlBuffer)
	end

	return true, "Success", csgmdl
end

--

return CSGMDLV5Static
