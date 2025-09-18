--!strict

local Bindings = {}
local binding = assert(script:FindFirstChild("Binding") :: BindableFunction?)

function Bindings.toMeshPart(selected: BasePart): MeshPart
	return binding:Invoke("toMeshPart", selected)
end

return Bindings
