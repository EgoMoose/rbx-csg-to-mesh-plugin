--!strict

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local SolidMesh = require(pluginRoot.Main.Formats.SolidMesh)

local function callback(selected: BasePart)
	local applyColor = false
	if selected:IsA("UnionOperation") then
		applyColor = not selected.UsePartColor
	end

	local solidMesh, err = SolidMesh.fromPart(selected)

	if solidMesh then
		local meshPart = solidMesh:ToMeshPart(applyColor)
		meshPart.Anchored = true
		meshPart.Material = selected.Material
		meshPart.MaterialVariant = selected.MaterialVariant
		meshPart.Color = if applyColor then Color3.new(1, 1, 1) else selected.Color
		meshPart.CFrame = selected.CFrame
		meshPart.Size = selected.Size

		return meshPart
	end

	error(err)
end

return {
	identifier = "toMeshPart",
	callback = callback,
}
