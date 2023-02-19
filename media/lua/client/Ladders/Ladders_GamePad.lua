-- Gamepad Support via Context-Sensitive Gamepad Prompt Activation

local Ladders = require('Ladders/Ladders')

Ladders.validGamepadInput = function(playerIndex, button)
	playerIndex = (playerIndex or 0)
	local player = getSpecificPlayer(playerIndex)
	if not (player and player:isAlive()) then return end
	if button ~= Joypad.BButton then return end
	return player
end

Ladders.triggerGamepadClimbing = function(buttonPromptData, button, square, down)
	local playerIndex = buttonPromptData.player
	local player = Ladders.validGamepadInput(playerIndex, button)
	local location = player:getSquare()

	if (MainScreen.instance and MainScreen.instance:isVisible()) or not (player and location) then return end

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
			end

			player:climbDownSheetRope()

			return
		end

		local hoppable = location:getHoppableThumpableTo(square)
		local wall = location:getWallHoppableTo(square)

		if hoppable or wall then
			local direction = player:getDir()
			if IsoWindow.canClimbThroughHelper(player, location, square, direction == IsoDirections.N or direction == IsoDirections.S) then
				player:climbOverFence(player:getDir())
			end

			player:climbDownSheetRope()

			return
		end

		local frame = location:getWindowFrameTo(square)

		if frame then
			if (IsoWindowFrame.canClimbThrough(frame, player)) then
				player:climbThroughWindowFrame(frame)
			end

			player:climbDownSheetRope()

			return
		end

		-- Otherwise something is wonky, but we're still getting to that damn rope somehow.
		player:setX(square:getX())
		player:setY(square:getY())
		player:setZ(square:getZ())
		player:climbDownSheetRope()
	else -- Everything is immeasurably easier.
		Ladders.enRoute = true
		-- Walks to AND climbs the rope, rather than sort of teleporting to it
		-- (which is what happens if you use player:climbSheetRope() below).
		ISWorldObjectContextMenu.onClimbSheetRope(nil, square, false, playerIndex)
	end
end

Ladders.patchBestBButtonAction = function()

	-- Safe back-up in your module for others who may need this!
	Ladders.ISButtonPrompt = Ladders.ISButtonPrompt or {
		getBestBButtonAction = ISButtonPrompt.getBestBButtonAction
	}

	function ISButtonPrompt:getBestBButtonAction(direction)

		-- Calling getBestBButtonAction back-up in the module created above.
		Ladders.ISButtonPrompt.getBestBButtonAction(self, original)

		if self.bPrompt and self.bPrompt ~= getText("ContextMenu_Climb_through") and self.bPrompt ~= getText("ContextMenu_Climb_over") then return end

		local playerIndex = self.player
		local player = getSpecificPlayer(playerIndex)
		local square = player:getSquare()

		-- This will prevent exceptions when you teleport and either
		--  your target location or its objects have not yet spawned.
		local ladder = (square and square:getObjects() and Ladders.getLadderObject(square))

		if ladder then
			Ladders.makeLadderClimbableFromTop(square)
			Ladders.makeLadderClimbableFromBottom(square)
			self:setBPrompt(getText("UI_Ladders_Climb"), Ladders.triggerGamepadClimbing, Joypad.BButton, square, false)
			return
		end

		local original = direction

		direction = direction or player:getDir()

		if square then
			if direction == IsoDirections.NE then
				square = square:getAdjacentSquare(IsoDirections.N) or square:getAdjacentSquare(IsoDirections.E)
			elseif direction == IsoDirections.NW then
				square = square:getAdjacentSquare(IsoDirections.N) or square:getAdjacentSquare(IsoDirections.W)
			elseif direction == IsoDirections.SE then
				square = square:getAdjacentSquare(IsoDirections.S) or square:getAdjacentSquare(IsoDirections.E)
			elseif direction == IsoDirections.SW then
				square = square:getAdjacentSquare(IsoDirections.S) or square:getAdjacentSquare(IsoDirections.W)
			else -- Direction is N, S, E, or W
				square = square:getAdjacentSquare(direction)
			end
		end

		below = square and getSquare(math.floor(square:getX()), math.floor(square:getY()), math.floor(square:getZ() - 1))

		-- ladder = (square and square:getObjects() and Ladders.getLadderObject(square))

		ladder = (square and player:canClimbDownSheetRope(square))

		ladderBelow = (below and below:getObjects() and Ladders.getLadderObject(below))

		if ladder then
			self:setBPrompt(getText("UI_Ladders_Climb"), Ladders.triggerGamepadClimbing, Joypad.BButton, square, true)
			return
		elseif ladderBelow then -- Controller testing suggests need to do this from the bottom of a ladder to work properly.
			Ladders.makeLadderClimbableFromTop(below)
			Ladders.makeLadderClimbableFromBottom(below)
			self:setBPrompt(getText("UI_Ladders_Climb"), Ladders.triggerGamepadClimbing, Joypad.BButton, square, true)
			return
		end

	end

end

Events.OnGameStart.Add(Ladders.patchBestBButtonAction)

-- Hide the progress bar for walking to the ladder because having one is beyond pointless.

Ladders.ISBaseTimedAction = {
	create = ISBaseTimedAction.create
}

function ISBaseTimedAction:create()
	Ladders.ISBaseTimedAction.create(self)
	if Ladders.enRoute then
		self.action:setUseProgressBar(false)
		Ladders.enRoute = nil
	end
end
