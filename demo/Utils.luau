--!strict

local AssetService = game:GetService("AssetService")
local GeometryService = game:GetService("GeometryService") :: GeometryService

local Utils = {}

-- Private

local function getCSGToMeshBindings(): typeof(require(AssetService.CSGToMeshBindings))
	-- this is a really weird setup that really only need to be done b/c a benign copy of the bindings
	-- sits under asset service when you're syncing develop.project.json so the sourcemap behaves
	while true do
		for _, child in AssetService:GetChildren() do
			if child.Name == "CSGToMeshBindings" and child.Archivable == false then
				return require(child) :: any
			end
		end
		AssetService.ChildAdded:Wait()
	end
end

-- Public

local CSGToMeshBindings = getCSGToMeshBindings()

function Utils.isCSGPart(instance: Instance)
	return instance:IsA("Part")
		or instance:IsA("WedgePart")
		or instance:IsA("CornerWedgePart")
		or instance:IsA("UnionOperation")
end

function Utils.unionModel(model: Model)
	local primary = assert(model.PrimaryPart, "Model must have a PrimaryPart")
	assert(Utils.isCSGPart(primary), "PrimaryPart is not supported by CSG")

	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant ~= primary and descendant:IsA("BasePart") and Utils.isCSGPart(descendant) then
			table.insert(parts, descendant)
		end
	end

	local union = assert(
		GeometryService:UnionAsync(primary, parts, {
			SplitApart = false,
		})[1] :: UnionOperation,
		"Failed to union."
	)

	union.Anchored = true
	union.Name = model.Name
	return union
end

function Utils.meshPartFromModel(model: Model)
	local union = Utils.unionModel(model)
	union.Parent = game:GetService("ServerStorage")
	local meshPart = CSGToMeshBindings.toMeshPart(union)
	union:Destroy()
	return meshPart
end

return Utils
