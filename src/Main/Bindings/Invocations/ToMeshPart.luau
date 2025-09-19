--!strict

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local CSGMDLV5 = require(pluginRoot.Main.CSGMDLV5)

local function callback(selected: BasePart)
	local applyColor = false
	if selected:IsA("UnionOperation") then
		applyColor = not selected.UsePartColor
	end

	local csgmdl, err = CSGMDLV5.fromPart(selected)

	if csgmdl then
		local meshPart = csgmdl:ToMeshPart(applyColor)
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
