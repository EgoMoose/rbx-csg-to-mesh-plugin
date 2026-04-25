--!strict

local AssetService = game:GetService("AssetService") :: AssetService
local GeometryService = game:GetService("GeometryService") :: GeometryService
local SerializationService = game:GetService("SerializationService") :: SerializationService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StaticContent = require(pluginRoot.Main.StaticContent)
local SharedString = require(pluginRoot.Main.SharedString)
local Parser = require(script.Parser)

local SolidMeshStatic = {}

local SolidMeshClass = {}
SolidMeshClass.__index = SolidMeshClass
SolidMeshClass.ClassName = "SolidMesh"

export type SolidMesh = typeof(setmetatable(
	{} :: {
		positions: { Vector3 },
		normals: { Vector3 },
		colors: { { number } },

		faces: { number },
		faceNormals: { number },
		faceColors: { number },
	},
	SolidMeshClass
))

function SolidMeshStatic.new(solidMeshBuffer: buffer)
	local self = setmetatable({}, SolidMeshClass)

	local parsed = Parser.parse(solidMeshBuffer)
	self.positions = parsed.positions
	self.normals = parsed.normals
	self.colors = parsed.colors

	self.faces = parsed.faces
	self.faceNormals = parsed.faceNormals
	self.faceColors = parsed.faceColors

	return self
end

function SolidMeshStatic.fromPart(part: BasePart): (SolidMesh?, string)
	local csg: UnionOperation?
	local success, err = pcall(function()
		if part:IsA("PartOperation") then
			csg = GeometryService:UnionAsync(part, {}, {
				CollisionFidelity = part.CollisionFidelity,
				RenderFidelity = part.RenderFidelity,
				FluidFidelity = part.FluidFidelity,
				SplitApart = false,
			})[1]
		else
			csg = GeometryService:UnionAsync(part, {}, {
				SplitApart = false,
			})[1]
		end
	end)

	local solidMesh: SolidMesh?
	if success and csg then
		local serialized = SerializationService:SerializeInstancesAsync({ csg })
		csg:Destroy()

		local solidMeshBuffer = SharedString.extract(serialized, function(b)
			return buffer.len(b) >= Parser.PADDING_BYTES + #Parser.HEADER
				and buffer.readstring(b, Parser.PADDING_BYTES, #Parser.HEADER) == Parser.HEADER
		end)

		if solidMeshBuffer then
			solidMesh = SolidMeshStatic.new(solidMeshBuffer)
		else
			err = "Failed find SolidMesh buffer."
		end
	end

	return solidMesh, err or "Success"
end

-- Methods

function SolidMeshClass.ToMeshPart(self: SolidMesh, useColorData: boolean)
	local editMesh = AssetService:CreateEditableMesh()

	local vertexIds = {}
	for i, position in self.positions do
		vertexIds[i] = editMesh:AddVertex(position)
	end

	local normalIds = {}
	for i, normal in self.normals do
		normalIds[i] = editMesh:AddNormal(normal)
	end

	local colorIds = {}
	if useColorData then
		for i, rgba in self.colors do
			local color = Color3.new(rgba[1], rgba[2], rgba[3])
			colorIds[i] = editMesh:AddColor(color, 1)
		end
	end

	for i = 1, #self.faces, 3 do
		local faceId = editMesh:AddTriangle(
			vertexIds[self.faces[i + 0] + 1],
			vertexIds[self.faces[i + 1] + 1],
			vertexIds[self.faces[i + 2] + 1]
		)

		editMesh:SetFaceNormals(faceId, {
			normalIds[self.faceNormals[i + 0] + 1],
			normalIds[self.faceNormals[i + 1] + 1],
			normalIds[self.faceNormals[i + 2] + 1],
		})

		if useColorData then
			editMesh:SetFaceColors(faceId, {
				colorIds[self.faceColors[i + 0] + 1],
				colorIds[self.faceColors[i + 1] + 1],
				colorIds[self.faceColors[i + 2] + 1],
			})
		end
	end

	local content = StaticContent.convert(Content.fromObject(editMesh))
	editMesh:Destroy()
	return AssetService:CreateMeshPartAsync(content)
end

--

return SolidMeshStatic
