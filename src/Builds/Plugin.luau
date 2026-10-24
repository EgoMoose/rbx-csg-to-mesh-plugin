--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService") :: ChangeHistoryService
local SelectionService = game:GetService("Selection") :: Selection

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

local function isConvertible(instance: Instance): boolean
	return instance:IsA("UnionOperation")
		or instance:IsA("Part")
		or instance:IsA("WedgePart")
		or instance:IsA("CornerWedgePart")
end

local function getSelected(): { BasePart }
	local selected = {}
	for _, instance in SelectionService:Get() do
		if isConvertible(instance) then
			table.insert(selected, instance :: BasePart)
		end
	end
	return selected
end

local function hasSelected(): boolean
	return #getSelected() > 0
end

local function toMeshPart(selected: BasePart): (MeshPart?, string)
	local applyColor = false
	if selected:IsA("UnionOperation") then
		applyColor = not selected.UsePartColor
	end

	local solidMesh, err = SolidMesh.fromPart(selected)
	if not solidMesh then
		return nil, err
	end

	local meshPart = solidMesh:ToMeshPart(applyColor)
	meshPart.Anchored = true
	meshPart.Material = selected.Material
	meshPart.MaterialVariant = selected.MaterialVariant
	meshPart.Color = if applyColor then Color3.new(1, 1, 1) else selected.Color
	meshPart.CFrame = selected.CFrame
	meshPart.Size = selected.Size

	return meshPart, err
end

function Plugin.build(plugin: Plugin)
	local toolbar = plugin:CreateToolbar("CSG Tools")
	local button = toolbar:CreateButton(
		"egomoose_csg_to_mesh",
		"Convert the selected UnionOperations into EditableMeshes",
		"",
		"CSG To Mesh"
	)

	iconThemed(button, Icons.icon_light, Icons.icon_dark)

	local inProgress = false
	local selectionChanged = SelectionService.SelectionChanged:Connect(function()
		if not inProgress then
			button.Enabled = hasSelected()
		end
	end)

	button.Enabled = hasSelected()

	local buttonClicked = button.Click:Connect(function()
		inProgress = true
		button.Enabled = false

		local selected = getSelected()
		if #selected > 0 then
			-- conversion yields, so build every mesh before recording the change
			local converted: { [BasePart]: MeshPart } = {}
			for _, part in selected do
				local meshPart, err = toMeshPart(part)
				if meshPart then
					meshPart.Name = part.Name
					converted[part] = meshPart
				else
					warn(`Failed to convert {part:GetFullName()}: {err}`)
				end
			end

			if next(converted) then
				local recording = ChangeHistoryService:TryBeginRecording("plugin:egomoose:csg_to_mesh")

				local meshParts = {}
				for _, part in selected do
					local meshPart = converted[part]
					if meshPart then
						meshPart.Parent = part.Parent
						table.insert(meshParts, meshPart)
					end
				end

				SelectionService:Set(meshParts :: any)

				if recording then
					ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
				end
			end
		else
			warn("Select at least one union or part to use.")
		end

		button:SetActive(false)
		button.Enabled = hasSelected()
		inProgress = false
	end)

	plugin.Unloading:Connect(function()
		selectionChanged:Disconnect()
		buttonClicked:Disconnect()
	end)

	Bindings.setup(plugin)
end

return Plugin
