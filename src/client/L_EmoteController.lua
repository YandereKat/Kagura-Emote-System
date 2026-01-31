local replicatedStorage = game:GetService("ReplicatedStorage")

local remotes = replicatedStorage.Remotes.Game.Character.Emotes
local EmoteDefinitions = require("@shared/Emotes/EmoteDefinitions")
local Signal = require("@shared/Signal")
local Maid = require("@utilShared/Maid")

local REQUEST_EMOTE_PLAY: RemoteFunction = remotes.RequestEmotePlay
local REQUEST_EMOTE_STOP: RemoteEvent = remotes.RequestEmoteStop

local EMOTE_PLAYED = remotes.EmotePlayed
local EMOTE_STOPPED = remotes.EmoteStopped

local L_EmoteController = {}
L_EmoteController.__index = L_EmoteController

function L_EmoteController.new(character, controller)
	local self = setmetatable({}, L_EmoteController)

	self._character = character
	self._controller = controller
	self._speedController = character.humanoid.speedController
	self._jumpController = character.humanoid.jumpController

	self:Init()
	return self
end

function L_EmoteController:Init()
	self._controllerMaid = Maid.new()
	self._emoteMaid = Maid.new()

	self._activeEmote = nil
	self._requesting = false

	self.EmotePlayed = Signal.new()
	self.EmoteStopped = Signal.new()
	self.EmoteRequested = Signal.new()

	self:_connectRemotes()

	self._character.ActionPerformed:Connect(function()
		if not self:IsEmoting() and not self._requesting then
			return
		end
		self:StopEmote()
	end)
end

-- // Public API

function L_EmoteController:PlayEmote(emoteId: string)
	local emote = EmoteDefinitions[emoteId]
	if not emote then
		return
	end

	self.EmoteRequested:Fire(emoteId)

	self._requesting = true
	REQUEST_EMOTE_PLAY:InvokeServer(emoteId)
	self._requesting = true
end

function L_EmoteController:StopEmote()
	REQUEST_EMOTE_STOP:FireServer()
end

function L_EmoteController:IsEmoting()
	return self:GetActiveEmote() ~= nil
end

function L_EmoteController:GetActiveEmote()
	return self._activeEmote
end

-- // Private API

function L_EmoteController:_connectRemotes()
	self._controllerMaid:GiveTask(EMOTE_PLAYED.OnClientEvent:Connect(function(emoteId)
		self:_emotePlayed(emoteId)
	end))

	self._controllerMaid:GiveTask(EMOTE_STOPPED.OnClientEvent:Connect(function()
		self:_emoteStopped()
	end))
end

function L_EmoteController:_emotePlayed(emoteId)
	local emote = EmoteDefinitions[emoteId]
	if not emote then
		return
	end

	self._activeEmote = emote
	self:_updateMovement()
	self.EmotePlayed:Fire(emoteId)
end

function L_EmoteController:_emoteStopped()
	self.EmoteStopped:Fire(self._activeEmote.id)
	self._activeEmote = nil
	self:_updateMovement()
end

function L_EmoteController:_updateMovement()
	if self:IsEmoting() and self._activeEmote then
		local slow = self._activeEmote.movement.slow
		local canJump = self._activeEmote.movement.canJump

		if slow then
			self._speedController:SetBoost("EMOTE", slow, "MULTIPLY")
		end

		if not canJump then
			self._jumpController:SetBoost("EMOTE", 0, "MULTIPLY")
		end
	else
		self._speedController:RemoveBoost("EMOTE", "MULTIPLY")
		self._jumpController:RemoveBoost("EMOTE", "MULTIPLY")
	end
end

-- // Cleanup
function L_EmoteController:Destroy()
	self._controllerMaid:Destroy()
	self._controllerMaid = nil
end

return L_EmoteController
