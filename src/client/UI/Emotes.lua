-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Modules
local Controls = require("@client/Managers/UIController/Settings/Controls")
local EmoteDefinitions = require("@shared/Emotes/EmoteDefinitions")
local Signal = require("@shared/Signal")
local DistanceTweenUtil = require("@utilShared/DistanceTweenUtil")
local Promise = require("@utilShared/Promise")

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse: Mouse = player:GetMouse()

-- UI
local emoteScreenGui = playerGui:WaitForChild("Emotes")
local mainFrame = emoteScreenGui:WaitForChild("MainFrame")
local emoteList = mainFrame:WaitForChild("EmoteList")
local emoteFrameTemplate = emoteList:WaitForChild("EmoteFrame")

-- Runtime
local charObj
local emoteController
local currentEmoteId

local cachedFrames = {} :: { [string]: Frame }
local frameHoverConfigs = {}

local Emotes = {}

Emotes.UIShown = Signal.new()
Emotes.UIHidden = Signal.new()
Emotes.EmoteChosen = Signal.new()

-- Constants
local OPEN_ANIMATION_TIME = 0.15
local EMOTE_LIST_SIZE = UDim2.fromOffset(120, 180)

local SIZE_NORMAL = 0.75
local SIZE_HOVER = 0.9

local COLOR_NORMAL = Color3.fromRGB(225, 225, 225)
local COLOR_HOVER = Color3.fromRGB(255, 244, 213)

local HOVER_GRADIENT_NORMAL = 1
local HOVER_GRADIENT_HOVER = 0

local SIZE_SPEED = 2.0
local COLOR_SPEED = 3.0
local HOVER_GRADIENT_SPEED = 6.0

-- // Helpers

local function setCurrentEmote(emoteId: string)
	currentEmoteId = emoteId
end

local function clearCurrentEmote()
	currentEmoteId = nil
end

-- // Hover logic

local function applyHover(config, isHovering: boolean)
	local state = isHovering and config.enter or config.exit

	for instance, props in pairs(state) do
		for property, targetValue in pairs(props) do
			local speed = config.speeds and config.speeds[property] or 1
			DistanceTweenUtil.TweenWithSpeed(instance, property, targetValue, speed)
		end
	end
end

local function resetAllHovers()
	for _, config in pairs(frameHoverConfigs) do
		applyHover(config, false)
	end
end

-- // UI initialization

function Emotes.fillEmotes()
	for i, def in EmoteDefinitions do
		local frame = emoteFrameTemplate:Clone()
		frame.Name = def.id
		frame.LayoutOrder = i
		frame.Visible = not def.hidden
		frame.Parent = emoteList

		frame.EmoteName.Text = def.emoteName
		frame.EmoteName.Size = UDim2.fromScale(1, SIZE_NORMAL)
		frame.EmoteName.TextColor3 = COLOR_NORMAL
		frame.HoverGradient.ImageTransparency = HOVER_GRADIENT_NORMAL

		local hoverConfig = {
			enter = {
				[frame.EmoteName] = {
					Size = UDim2.fromScale(1, SIZE_HOVER),
					TextColor3 = COLOR_HOVER,
				},
				[frame.HoverGradient] = {
					ImageTransparency = HOVER_GRADIENT_HOVER,
				},
			},
			exit = {
				[frame.EmoteName] = {
					Size = UDim2.fromScale(1, SIZE_NORMAL),
					TextColor3 = COLOR_NORMAL,
				},
				[frame.HoverGradient] = {
					ImageTransparency = HOVER_GRADIENT_NORMAL,
				},
			},
			speeds = {
				Size = SIZE_SPEED,
				TextColor3 = COLOR_SPEED,
				ImageTransparency = HOVER_GRADIENT_SPEED,
			},
		}

		Emotes.connectFrameInput(frame, def.id, hoverConfig)

		cachedFrames[def.id] = frame
		frameHoverConfigs[frame] = hoverConfig
	end
end

function Emotes.updateInitialVisibility()
	for _, frame in emoteList:GetChildren() do
		local def = EmoteDefinitions[frame.Name]
		if def then
			frame.Visible = not def.hidden
		end
	end
end

function Emotes.connectFrameInput(frame: Frame, emoteId: string, hoverConfig)
	frame.MouseEnter:Connect(function()
		setCurrentEmote(emoteId)
		applyHover(hoverConfig, true)
	end)

	frame.MouseLeave:Connect(function()
		if currentEmoteId == emoteId then
			clearCurrentEmote()
		end
		applyHover(hoverConfig, false)
	end)
end

-- // Emote window

local function resolveEmoteSelection()
	if not (emoteController and currentEmoteId) then
		return
	end

	Emotes.EmoteChosen:Fire(currentEmoteId)

	local def = EmoteDefinitions[currentEmoteId]
	if def and def.playOnClick then
		emoteController:PlayEmote(currentEmoteId)
	end
end

function Emotes.openWindow()
	Emotes.updateInitialVisibility()
	Emotes.UIShown:Fire()

	emoteScreenGui.Enabled = true
	mainFrame.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	mainFrame.Size = UDim2.fromOffset(120, 0)

	TweenService:Create(
		mainFrame,
		TweenInfo.new(OPEN_ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = EMOTE_LIST_SIZE }
	):Play()
end

function Emotes.closeWindow()
	Emotes.UIHidden:Fire()
	emoteScreenGui.Enabled = false

	resolveEmoteSelection()
	clearCurrentEmote()
	resetAllHovers()
end

-- // Input

local TIMEOUT = "Timeout"
local INPUT = "Input"

local function waitForReleaseOrTimeout(keyCode: Enum.KeyCode, duration: number)
	return Promise.race({
		Promise.delay(duration):andThen(function()
			return TIMEOUT
		end),

		Promise.fromEvent(UserInputService.InputEnded, function(input)
			return input.KeyCode == keyCode
		end):andThen(function()
			return INPUT
		end),
	})
end

function Emotes.canOpenWindow(): boolean
	local combatController = charObj and charObj.controller and charObj.controller.combatController
	return not (combatController and os.clock() - combatController.lastHit < 3)
end

function Emotes.connectUserInput()
	local emotesKeybind = Controls.GetKeybindSignals("Emotes")

	emotesKeybind.InputBegan:Connect(function(_, gpe)
		if gpe or not Emotes.canOpenWindow() then
			return
		end

		if not emoteController:IsEmoting() then
			Emotes.openWindow()
			return
		end

		-- If window is already open, allow user to hold the key to open the window back again.
		-- This feels much better than always forcing the user to stop the emote first.
		waitForReleaseOrTimeout(Enum.KeyCode.N, 0.3):andThen(function(result)
			if result == TIMEOUT then
				Emotes.openWindow()
			elseif result == INPUT and emoteController:IsEmoting() then
				emoteController:StopEmote()
			end
		end)
	end)

	emotesKeybind.InputEnded:Connect(function()
		Emotes.closeWindow()
	end)
end

-- // Public API

function Emotes.Init(newCharacter)
	Emotes.Reinitialize(newCharacter)
	Emotes.fillEmotes()
	Emotes.connectUserInput()
end

function Emotes.Reinitialize(newCharacter)
	charObj = newCharacter
	emoteController = charObj.controller.emoteController
end

function Emotes.ShowEmote(emoteId: string)
	local frame = cachedFrames[emoteId]
	if frame then
		frame.Visible = true
	end
end

function Emotes.HideEmote(emoteId: string)
	local frame = cachedFrames[emoteId]
	if frame then
		frame.Visible = false
	end
end

return Emotes
