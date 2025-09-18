--!strict

local AssetService = game:GetService("AssetService")
local SerializationService = game:GetService("SerializationService") :: SerializationService

local SharedString = require(script.SharedString)
local Parser = require(script.Parser)

local CSGMDLV5Static = {}

local CSGMDLV5Class = {}
CSGMDLV5Class.__index = CSGMDLV5Class
CSGMDLV5Class.ClassName = "CSGMDLV5"

export type CSGMDLV5 = typeof(setmetatable(
	{} :: {
		positions: { Vector3 },
		normals: { Vector3 },
		colors: { { number } },
		uvs: { Vector2 },
		faces: { number },
	},
	CSGMDLV5Class
))

-- Constructors

function CSGMDLV5Static.new(csgmdlBuffer: buffer)
	local self = setmetatable({}, CSGMDLV5Class) :: CSGMDLV5

	local parsed = Parser.parse(csgmdlBuffer)
	self.positions = parsed.positions
	self.normals = parsed.normals
	self.colors = parsed.colors
	self.uvs = parsed.uvs
	self.faces = parsed.faces

	return self
end

function CSGMDLV5Static.fromPart(part: BasePart): (CSGMDLV5?, string)
	local csg: UnionOperation?
	local success, err = pcall(function()
		if part:IsA("PartOperation") then
			csg = part:UnionAsync({}, part.CollisionFidelity, part.RenderFidelity)
		else
			csg = part:UnionAsync({})
		end
	end)

	local csgmdl: CSGMDLV5?
	if success and csg then
		local serialized = SerializationService:SerializeInstancesAsync({ csg })
		csg:Destroy()
		local csgmdlBuffer = SharedString.readCSGMDLBuffer(serialized)
		csgmdl = CSGMDLV5Static.new(csgmdlBuffer)
	end

	return csgmdl, err or "Success"
end

-- Methods

function CSGMDLV5Class.ToMeshPart(self: CSGMDLV5)
	local editMesh = AssetService:CreateEditableMesh()

	local vertexIds = {}
	for i, position in self.positions do
		vertexIds[i] = editMesh:AddVertex(position)
	end

	local normalIds = {}
	for i, normal in self.normals do
		normalIds[i] = editMesh:AddNormal(normal)
	end

	local uvIds = {}
	for i, uv in self.uvs do
		uvIds[i] = editMesh:AddUV(uv)
	end

	for i = 1, #self.faces, 3 do
		local a = self.faces[i + 0] + 1
		local b = self.faces[i + 1] + 1
		local c = self.faces[i + 2] + 1

		local faceId = editMesh:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
		editMesh:SetFaceNormals(faceId, { normalIds[a], normalIds[b], normalIds[c] })
		editMesh:SetFaceUVs(faceId, { uvIds[a], uvIds[b], uvIds[c] })
	end

	local fixedSizeMesh = AssetService:CreateEditableMeshAsync(Content.fromObject(editMesh), { FixedSize = true })
	editMesh:Destroy()
	return AssetService:CreateMeshPartAsync(Content.fromObject(fixedSizeMesh))
end

--

return CSGMDLV5Static
