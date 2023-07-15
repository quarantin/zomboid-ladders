-- Gamepad Support via Context-Sensitive Gamepad Prompt Activation

local Ladders = require('Ladders/Ladders')

local GamePad = {}
GamePad.testedSq = {}

GamePad.validGamepadInput = function(playerIndex, button)
	playerIndex = (playerIndex or 0)
	local player = getSpecificPlayer(playerIndex)
	if not (player and player:isAlive()) then return end
	if button ~= Joypad.BButton then return end
	return player
end

GamePad.triggerGamepadClimbing = function(buttonPromptData, button, square, down)
	local playerIndex = buttonPromptData.player
	local player = GamePad.validGamepadInput(playerIndex, button)
	local location = player:getSquare()
	
	if (MainScreen.instance and MainScreen.instance:isVisible()) or not (player and location) then return end

	-- Used for setting animatio state.
    -- Will store last player to attempt to climb a ladder.
    --Ladders.player = player

	if down then -- Am I serious? Unfortunately . . . Yes.

		local window = location:getWindowTo(square)
		local thumpable = location:getWindowThumpableTo(square)

		if window or thumpable then
			if window and not window:IsOpen() then
				window:ToggleWindow(player)
			end

			-- The 4 below seems hardcoded in Java; its meaning is not obvious to me
			-- because I had to port this algorithm from decompiled Java code. :(
			if window and window:canClimbThrough(player) then
				player:climbThroughWindow(window, 4)
			elseif thumpable and thumpable:canClimbThrough(player) then
				player:climbThroughWindow(thumpable, 4)
			else
				player:climbDownSheetRope()
			end

			return
		end
		
		local hoppable = location:getHoppableThumpableTo(square)
		local wall = location:getWallHoppableTo(square)

		if hoppable or wall then
			local direction = player:getDir()
			-- Correction to prevent errors from being thrown when player isn't facing a ladder well enough.
			if direction == IsoDirections.NE then
				direction = IsoDirections.E
			elseif direction == IsoDirections.SW then
				direction = IsoDirections.S
			elseif direction == IsoDirections.SE then
				local option = location:getAdjacentSquare(IsoDirections.S)
				if option and IsoWindow.isTopOfSheetRopeHere(option) and player:canClimbDownSheetRope(option) then
					direction = IsoDirections.S
				else -- There must be a ladder here, or the prompt wouldn't be visible in the first place.
					direction = IsoDirections.E
				end
			end
			if IsoWindow.canClimbThroughHelper(player, location, square, direction == IsoDirections.N or direction == IsoDirections.S) then
				player:climbOverFence(direction)
			else
				player:climbDownSheetRope()
			end
			return
		end

		local frame = location:getWindowFrameTo(square)

		if frame then
			if (IsoWindowFrame.canClimbThrough(frame, player)) then
				player:climbThroughWindowFrame(frame)
			else
				player:climbDownSheetRope()
			end
			return
		end

		-- Otherwise something is wonky, but we're still getting to that damn rope somehow.
		player:setX(square:getX())
		player:setY(square:getY())
		player:setZ(square:getZ())
		player:climbDownSheetRope()
	else -- Everything is immeasurably easier.
		GamePad.enRoute = true
		-- Walks to AND climbs the rope, rather than sort of teleporting to it
		-- (which is what happens if you use player:climbSheetRope() below).
		ISWorldObjectContextMenu.onClimbSheetRope(nil, square, false, playerIndex)
	end
end

GamePad.patchBestBButtonAction = function()

	GamePad["ISButtonPrompt.testBButtonAction"] = GamePad["ISButtonPrompt.testBButtonAction"] or ISButtonPrompt.testBButtonAction
	ISButtonPrompt.testBButtonAction = function(self,dir)
		if not self.bPrompt then

			local player = getSpecificPlayer(self.player)
			local square = player:getSquare()

			if GamePad.testedSq[self] ~= square then
				GamePad.testedSq[self] = square
				Ladders.player = player
				Ladders.makeLadderClimbableFromTop(square)
				Ladders.makeLadderClimbableFromBottom(square)
			end

			local hasClimbFlag
			if dir == IsoDirections.W and square:getProperties():Is(IsoFlagType.climbSheetW)
			or dir == IsoDirections.N and square:getProperties():Is(IsoFlagType.climbSheetN)
			or dir == IsoDirections.E and square:getProperties():Is(IsoFlagType.climbSheetE)
			or dir == IsoDirections.S and square:getProperties():Is(IsoFlagType.climbSheetS)
			then hasClimbFlag = true
			end
			if hasClimbFlag and player:canClimbSheetRope(square) then
				self:setBPrompt(getText("UI_Ladders_Climb"), GamePad.triggerGamepadClimbing, Joypad.BButton, square, false)
			else
				square = square:getAdjacentSquare(dir)
				if square and IsoWindow.isTopOfSheetRopeHere(square) and player:canClimbDownSheetRope(square) then
					self:setBPrompt(getText("UI_Ladders_Climb"), GamePad.triggerGamepadClimbing, Joypad.BButton, square, true)
				end
			end
		end

		return GamePad["ISButtonPrompt.testBButtonAction"](self,dir)
	end
end

function GamePad.OnObjectAdded()
	table.wipe(GamePad.testedSq)
end

Events.OnGameStart.Add(GamePad.patchBestBButtonAction)
Events.OnObjectAdded.Add(GamePad.OnObjectAdded)

-- Hide the progress bar for walking to the ladder because having one is beyond pointless.

GamePad.ISBaseTimedAction = {
	create = ISBaseTimedAction.create
}

function ISBaseTimedAction:create()
	GamePad.ISBaseTimedAction.create(self)
	if GamePad.enRoute then
		self.action:setUseProgressBar(false)
		GamePad.enRoute = nil
	end
end

return GamePad
