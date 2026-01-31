local EmoteDefinitions = require("./EmoteDefinitions")

export type EmoteUtil = {
	GetEmotesWithTags: (tags: { string }, requireAllTags: boolean) -> { EmoteDefinitions.EmoteDefinition },
	GetEmotesWithTag: (tag: string) -> { EmoteDefinitions.EmoteDefinition },
}

local EmoteUtil = {} :: EmoteUtil

local function hasTag(def: EmoteDefinitions.EmoteDefinition, tag: string): boolean
	return table.find(def.tags, tag) ~= nil
end

function EmoteUtil.GetEmotesWithTags(tags: { string }, requireAllTags: boolean)
	local result = {}

	for _, def in EmoteDefinitions do
		local matchedTags = 0

		for _, tag in tags do
			if hasTag(def, tag) then
				matchedTags += 1
				if not requireAllTags then
					table.insert(result, def)
					break
				end
			elseif requireAllTags then
				break
			end
		end

		if requireAllTags and matchedTags == #tags then
			table.insert(result, def)
		end
	end

	return result
end

function EmoteUtil.GetEmotesWithTag(tag: string)
	local result = {}

	for _, def in EmoteDefinitions do
		if hasTag(def, tag) then
			table.insert(result, def)
		end
	end

	return result
end

return table.freeze(EmoteUtil)
