local EmoteDefinitions = {}

export type EmoteDefinition = {
	id: string,
	emoteName: string,
	animName: string,
	soundName: string?,

	hidden: boolean?, -- hidden from UI
	playOnClick: boolean, -- used for instances where another system might want to play the emote, or simply not play one
	tags: {},

	movement: {
		slow: number,
		canJump: boolean,
		cancelOnMove: boolean,
	},

	clientFunctions: {
		startFn: () -> (),
		endFn: () -> (),
	},

	serverFunctions: {
		startFn: () -> (),
		endFn: () -> (),
	},
}

local function validateDef(def: EmoteDefinition)
	assert(def.id, "def.id not provided")
	local DEBUG_STRING = `[{def.id}]`
	assert(def.animName, `{DEBUG_STRING} animName not provided.`)

	def.movement = def.movement or {}
	def.movement.slow = def.movement.slow or 0.2
	def.movement.canJump = def.movement.canJump or false
	def.movement.cancelOnMove = def.movement.cancelOnMove or false

	def.hidden = if def.hidden ~= nil then def.hidden else false
	def.playOnClick = if def.playOnClick ~= nil then def.playOnClick else true
	def.tags = def.tags or {}

	local function validateContextFunctions(contextName)
		def[contextName] = def[contextName] or {}
		def[contextName].startFn = def[contextName].startFn or function() end
		def[contextName].endFn = def[contextName].endFn or function() end
	end
	validateContextFunctions("clientFunctions")
	validateContextFunctions("serverFunctions")

	return def
end

local function defineEmote(def: EmoteDefinition)
	def = validateDef(def)
	EmoteDefinitions[def.id] = def
end

-- // Dances

defineEmote({
	id = "ambiguous",
	emoteName = "Ambiguous",
	animName = "Ambiguous",
	soundName = "Ambiguous",

	sync = true,
	tags = { "dance" },

	movement = {
		slow = 0.2,
		canJump = false,
	},

	clientFunctions = {},
})

defineEmote({
	id = "freestyle",
	emoteName = "Freestyle",
	animName = "Freestyle",
	soundName = "Freestyle",

	sync = true,
	tags = { "dance" },

	movement = {
		slow = 0.2,
		canJump = false,
	},

	clientFunctions = {},
})

defineEmote({
	id = "locked_in",
	emoteName = "Locked In",
	animName = "Locked In",
	soundName = "Locked In",

	sync = true,
	tags = { "dance" },

	movement = {
		slow = 0.2,
		canJump = false,
	},

	clientFunctions = {},
})

-- // Seat

-- Seat helper
local function defineSeatEmote(def: { id: string, emoteName: string, animName: string })
	defineEmote({
		id = def.id,
		emoteName = def.emoteName,
		animName = def.animName,

		hidden = true,
		playOnClick = false,
		tags = { "seat", "sit" },

		movement = {
			slow = 0,
			canJump = false,
			cancelOnMove = true,
		},

		clientFunctions = {},
	})
end

defineSeatEmote({
	id = "chair_sit_1",
	emoteName = "Chair Sit 1",
	animName = "ChairSit1",
})

defineSeatEmote({
	id = "chair_sit_2",
	emoteName = "Chair Sit 2",
	animName = "ChairSit2",
})

defineSeatEmote({
	id = "chair_sit_3",
	emoteName = "Chair Sit 3",
	animName = "ChairSit3",
})

defineSeatEmote({
	id = "chair_sit_4",
	emoteName = "Chair Sit 4",
	animName = "ChairSit4",
})

return table.freeze(EmoteDefinitions) :: { [string]: EmoteDefinition }
