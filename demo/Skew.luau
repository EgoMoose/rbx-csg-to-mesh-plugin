--!strict

local Utils = require(script.Parent.Utils)

local meshPart = Utils.meshPartFromModel(script.Parent.Models.HappyHome)
local editMesh = meshPart.MeshContent.Object :: EditableMesh

local positions = {}
for _, vertexId in editMesh:GetVertices() do
	positions[vertexId] = editMesh:GetPosition(vertexId)
end

local normals = {}
for _, normalId in editMesh:GetNormals() do
	normals[normalId] = editMesh:GetNormal(normalId) :: Vector3
end

local rootCF = meshPart.CFrame
local function refresh()
	local rotation = rootCF:ToObjectSpace(meshPart.CFrame):Inverse().Rotation

	for vertexId, position in positions do
		editMesh:SetPosition(vertexId, rotation:VectorToWorldSpace(position))
	end

	for normalId, normal in normals do
		editMesh:SetNormal(normalId, rotation:VectorToWorldSpace(normal))
	end
end

refresh()
meshPart:GetPropertyChangedSignal("CFrame"):Connect(refresh)
meshPart.Parent = workspace

return {}
