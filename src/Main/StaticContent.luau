--!strict

local AssetService = game:GetService("AssetService") :: AssetService

local StaticContent = {}

local function createDataModelContentAsync(
	content: Content,
	options: { [string]: any }
): (Enum.CreateContentResult, Content)
	return (AssetService :: any):CreateDataModelContentAsync(content, options)
end

function StaticContent.convert(content: Content)
	local convertedContent: Content
	pcall(function()
		local result, resultContent = createDataModelContentAsync(content, {})
		if result == Enum.CreateContentResult.Success then
			convertedContent = resultContent
		end
	end)

	if convertedContent then
		return convertedContent
	else
		-- if we can't convert w/ CreateDataModelContentAsync then we will use a fixed size editable mesh
		local fixedMesh = AssetService:CreateEditableMeshAsync(content, { FixedSize = true })
		return Content.fromObject(fixedMesh)
	end
end

return StaticContent
