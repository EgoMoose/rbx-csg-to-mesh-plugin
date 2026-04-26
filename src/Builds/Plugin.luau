--!strict

local SelectionService = game:GetService("Selection") :: Selection
local ChangeHistoryService = game:GetService("ChangeHistoryService") :: ChangeHistoryService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Bindings = require(pluginRoot.Main.Bindings)
local Icons = require(pluginRoot.Main.Icons)

local _CSGMDLV5 = require(pluginRoot.Main.Formats.CSGMDLV5)
local SolidMesh = require(pluginRoot.Main.Formats.SolidMesh)

local Plugin = {}

local function iconThemed(button: PluginToolbarButton, light: string, dark: string)
	local function onThemeChanged()
		local theme = settings().Studio.Theme
		button.Icon = if theme.Name:lower() == "light" then light else dark
	end

	onThemeChanged()
	settings().Studio.ThemeChanged:Connect(onThemeChanged)
end

local function getSelected(): BasePart?
	local selection = SelectionService:Get()
	local selected = if #selection == 1 then selection[1] else nil
	if selected and selected:IsA("BasePart") then
		if
			selected:IsA("UnionOperation")
			or selected:IsA("Part")
			or selected:IsA("WedgePart")
			or selected:IsA("CornerWedgePart")
		then
			return selected
		end
	end
	return nil
end

function Plugin.build(plugin: Plugin)
	local toolbar = plugin:CreateToolbar("CSG Tools")
	local button = toolbar:CreateButton(
		"egomoose_csg_to_mesh",
		"Convert a selected UnionOperation into an EditableMesh",
		"",
		"CSG To Mesh"
	)

	iconThemed(button, Icons.icon_light, Icons.icon_dark)

	local inProgress = false
	local selectionChanged = SelectionService.SelectionChanged:Connect(function()
		if not inProgress then
			button.Enabled = not not getSelected()
		end
	end)

	button.Enabled = not not getSelected()

	local buttonClicked = button.Click:Connect(function()
		inProgress = true
		button.Enabled = false

		local completed = false
		local recordingIdentifier = ChangeHistoryService:TryBeginRecording("egomoose_csg_to_mesh", "CSG to mesh")

		local selected = getSelected()
		if selected and selected:IsA("BasePart") then
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
				meshPart.Parent = selected.Parent

				SelectionService:Set({ meshPart })
				completed = true
			else
				warn(err)
			end
		else
			warn("Select a single BasePart to use.")
		end

		if recordingIdentifier then
			ChangeHistoryService:FinishRecording(
				recordingIdentifier,
				if completed then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end

		button:SetActive(false)
		button.Enabled = not not getSelected()
		inProgress = false
	end)

	plugin.Unloading:Connect(function()
		selectionChanged:Disconnect()
		buttonClicked:Disconnect()
	end)

	Bindings.setup(plugin)
end

return Plugin
