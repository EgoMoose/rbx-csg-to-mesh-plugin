--!strict

local CSGTools = require(game:GetService("AssetService"):WaitForChild("CSGTools"))

local function skew(selected: BasePart, rotation: CFrame)
	local meshPart = CSGTools.toMeshPart(selected)
	local editMesh = meshPart.MeshContent.Object :: EditableMesh

	for _, vertexId in editMesh:GetVertices() do
		local position = editMesh:GetPosition(vertexId)
		local rotated = rotation:VectorToObjectSpace(position)
		editMesh:SetPosition(vertexId, rotated)
	end

	return meshPart
end

local union = workspace:WaitForChild("Union")
union.Parent = game:GetService("ServerStorage")

local skewControl = Instance.new("Vector3Value")
skewControl.Value = Vector3.zero
skewControl.Name = "SkewRotation"
skewControl.Parent = workspace

local prevMeshPart
local function refresh()
	if prevMeshPart then
		prevMeshPart:Destroy()
	end

	local skewVec = skewControl.Value
	prevMeshPart = skew(union, CFrame.fromEulerAnglesYXZ(math.rad(skewVec.X), math.rad(skewVec.Y), math.rad(skewVec.Z)))
	prevMeshPart.Parent = workspace
end

refresh()
skewControl.Changed:Connect(refresh)
