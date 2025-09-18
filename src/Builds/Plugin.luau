--!strict

local SelectionService = game:GetService("Selection") :: Selection

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local CSGMDLV5 = require(pluginRoot.Main.CSGMDLV5)

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

		local selection = SelectionService:Get()
		local selected = if #selection == 1 then selection[1] else nil
		if selected and selected:IsA("BasePart") then
			local success, err, csgmdl = CSGMDLV5.fromPart(selected)

			if not success then
				warn(err)
			else
				print("Success")
			end
		else
			warn("Select a single  to use.")
		end

		button:SetActive(false)
		button.Enabled = true
	end)

	plugin.Unloading:Connect(function()
		connection:Disconnect()
	end)
end

return Plugin
