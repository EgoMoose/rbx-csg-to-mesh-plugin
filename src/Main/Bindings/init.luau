--!strict

local AssetService = game:GetService("AssetService") :: AssetService

local Bindings = {}

-- Private

type Invocation = {
	identifier: string,
	callback: (...any) -> ...any,
}

local invocationByIdentifier = {}
for _, invocationModule in script.Invocations:GetDescendants() do
	if invocationModule:IsA("ModuleScript") then
		local invocation = require(invocationModule) :: Invocation
		assert(
			not invocationByIdentifier[invocation.identifier],
			`Duplicate invocation identifier: {invocation.identifier}`
		)
		invocationByIdentifier[invocation.identifier] = invocation
	end
end

local function createBindings()
	local interface = script.Interface:Clone()
	local binding = interface.Binding
	interface.Name = "CSGTools"

	local descendants = interface:GetDescendants()
	table.insert(descendants, interface)

	for _, descendant in descendants do
		descendant.Archivable = false
	end

	binding.OnInvoke = function(identifier: string, ...: any)
		local invocation = assert(invocationByIdentifier[identifier], `No invocation found for: {identifier}`)
		return invocation.callback(...)
	end

	return interface
end

-- Public

function Bindings.setup(plugin: Plugin)
	local existing = AssetService:FindFirstChild("CSGTools")
	if existing then
		existing:Destroy()
	end

	local interface = createBindings()
	interface.Parent = AssetService

	plugin.Unloading:Connect(function()
		interface:Destroy()
	end)
end

--

return Bindings
