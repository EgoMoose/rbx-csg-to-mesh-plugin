--!strict

local Plugin = {}

function Plugin.build(plugin: Plugin)
	local toolbar = plugin:CreateToolbar("CSG Tools")
	local button = toolbar:CreateButton(
		"egomoose_csg_to_mesh",
		"Convert a selected UnionOperation into an EditableMesh",
		"",
		"Convert"
	)

	local connection = button.Click:Connect(function()
		button.Enabled = false

		print("Clicked!")

		button:SetActive(false)
		button.Enabled = true
	end)

	plugin.Unloading:Connect(function()
		connection:Disconnect()
	end)
end

return Plugin
