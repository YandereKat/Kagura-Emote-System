local replicatedStorage = game:GetService("ReplicatedStorage")
local remotes = replicatedStorage.Remotes

local Kagura = require(game:GetService("ReplicatedStorage").Shared.Kagura)
local TweenService = game:GetService("TweenService")
local REQUEST_EMOTE_PLAY = remotes.Game.Character.Emotes.RequestEmotePlay
local REQUEST_EMOTE_STOP = remotes.Game.Character.Emotes.RequestEmoteStop

local EMOTE_PLAYED = remotes.Game.Character.Emotes.EmotePlayed
local EMOTE_STOPPED = remotes.Game.Character.Emotes.EmoteStopped

local Maid = require("@utilShared/Maid")
local ComponentHolder = require("@shared/ComponentHolder")
local EmoteSync = require("@self/EmoteSync")
local AudioManager = require("@server/Managers/AudioManager")
local EmoteDefinitions = require("@shared/Emotes/EmoteDefinitions")
local Signal = require("@shared/Signal")

local EmoteController = setmetatable({}, ComponentHolder)
EmoteController.__index = EmoteController

function EmoteController.new(master, player, character)
	local self = setmetatable(ComponentHolder.new(master), EmoteController)

	self.master = master
	self.player = player
	self.character = character
	self.characterObj = master:GetComponent("Character")
	self._animator = self.character.Humanoid.Animator

	self.className = "EmoteController"

	self:Init()
	return self
end

function EmoteController:Init()
	self._controllerMaid = Maid.new() -- controller lifetime
	self._emoteMaid = Maid.new() -- resets for every emote

	self.EmotePlayed = Signal.new()
	self.EmoteStopped = Signal.new()

	self._activeEmote = nil
end

-- // Public API

function EmoteController:PlayEmote(emoteId: string)
	local emote = EmoteDefinitions[emoteId]
	if not emote then
		return
	end

	if self:IsEmoting() then
		self:StopEmote()
	end

	self._activeEmote = emote

	self.EmotePlayed:Fire(self._activeEmote.id)
	Kagura.PlayAnimationOnServer(self._animator, emote.animName)

	if emote.sync then
		EmoteSync.Start(self)
	end

	if emote.movement.cancelOnMove then
		self._emoteMaid:GiveTask(self.character.Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			local isMoving = self.character.Humanoid.MoveDirection.Magnitude > 0
			if isMoving then
				self:StopEmote()
			end
		end))
	end

	self._emoteMaid:GiveTask(self.characterObj.ActionPerformed:Connect(function(actionId)
		self:StopEmote()
	end))

	local combatController = self.characterObj:GetComponent("CombatController")
	if combatController then
		self._emoteMaid:GiveTask(combatController.signals.characterDamaged:Connect(function(attack)
			self:StopEmote()
		end))
	end

	EMOTE_PLAYED:FireClient(self.player, emoteId)
end

function EmoteController:StopEmote()
	if not self._activeEmote then
		return
	end

	self.EmoteStopped:Fire(self._activeEmote.id)

	if self._activeEmote.sync then
		EmoteSync.Stop(self)
	end

	Kagura.StopAnimationOnServer(self.character.Humanoid, self._activeEmote.animName)

	self._emoteMaid:Destroy()
	self._activeEmote = nil

	EMOTE_STOPPED:FireClient(self.player)
end

function EmoteController:IsEmoting()
	return self:GetActiveEmote() ~= nil
end

function EmoteController:GetActiveEmote()
	return self._activeEmote
end

function EmoteController:Destroy()
	self:StopEmote()

	self._controllerMaid:Destroy()
	self._controllerMaid = nil

	self.master = nil
	self.player = nil
	self.character = nil
	self.characterObj = nil
	self._animator = nil
end

-- // Private API
function EmoteController:_playSound(emote)
	local sound = AudioManager.Play("SFX", emote.soundName, self.character.HumanoidRootPart)
	local originalVolume = sound.Volume
	sound.Volume = 0
	TweenService:Create(sound, TweenInfo.new(5), { Volume = originalVolume }):Play()
	self._emoteMaid.sound = sound
end

function EmoteController:_stopSound()
	if self._emoteMaid.sound then
		self._emoteMaid.sound:Destroy()
		self._emoteMaid.sound = nil
	end
end

REQUEST_EMOTE_PLAY.OnServerInvoke = function(player, emoteId)
	local characterObj = Kagura.GetCharacterObjectByModel(player.Character)
	if not characterObj then
		return
	end
	local emoteController = characterObj:GetComponent("EmoteController")
	if not emoteController then
		return
	end

	emoteController:PlayEmote(emoteId)
	return true
end

REQUEST_EMOTE_STOP.OnServerEvent:Connect(function(player)
	local characterObj = Kagura.GetCharacterObjectByModel(player.Character)
	if not characterObj then
		return
	end
	local emoteController = characterObj:GetComponent("EmoteController")
	if not emoteController then
		return
	end

	emoteController:StopEmote()
end)

return EmoteController
