local Ladders = {}

local instanceof = instanceof
local climbrope_instance = ClimbSheetRopeState.instance()
local climbdownrope_instance = ClimbDownSheetRopeState.instance()

Ladders.climbSheetTopW = "TopOfLadderW"
Ladders.climbSheetTopN = "TopOfLadderN"

---@return IsoObject topOfLadder
function Ladders.getTopOfLadder(square, north)
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local obj = objects:get(i)
		local name = obj:getTextureName()
		if name == ( north and Ladders.climbSheetTopN or Ladders.climbSheetTopW ) then
			return obj
		end
	end
	return nil
end

---@return IsoObject topOfLadder
function Ladders.addTopOfLadder(square, north)
	local props = square:getProperties()
	if props:Is(north and IsoFlagType.WallN or IsoFlagType.WallW) or props:Is(IsoFlagType.WallNW) then
		Ladders.removeTopOfLadder(square)
		return nil
	end

	if props:Is(north and IsoFlagType.climbSheetTopN or IsoFlagType.climbSheetTopW) then
		return Ladders.getTopOfLadder(square, north)
	else
		local object = IsoObject.new(getCell(), square, north and Ladders.climbSheetTopN or Ladders.climbSheetTopW)
		square:transmitAddObjectToSquare(object, -1)
		return object
	end
end

function Ladders.removeTopOfLadder(square)
	if not square then return end
	local objects = square:getObjects()
	for i = objects:size() - 1, 0, - 1  do
		local object = objects:get(i)
		local sprite = object:getTextureName()
		if sprite == Ladders.climbSheetTopN or sprite == Ladders.climbSheetTopW then
			square:transmitRemoveItemFromSquare(object)
		end
	end
end

function Ladders.makeLadderClimbable(square, north)
	local x, y, z = square:getX(), square:getY(), square:getZ()
	local flags = north and { climbSheet = IsoFlagType.climbSheetN, climbSheetTop = IsoFlagType.climbSheetTopN, Wall = IsoFlagType.WallN }
		or { climbSheet = IsoFlagType.climbSheetW, climbSheetTop = IsoFlagType.climbSheetTopW, Wall = IsoFlagType.WallW }
	local topSquare = square
	local topObject

	while true do
		topObject = topSquare:Is(flags.climbSheetTop) and Ladders.getTopOfLadder(topSquare,north)
		z = z + 1
		local aboveSquare = getSquare(x, y, z)
		if not aboveSquare or aboveSquare:TreatAsSolidFloor() or aboveSquare:Is("RoofGroup") then break end
		if aboveSquare:Is(flags.climbSheet) then
			if topObject then topSquare:transmitRemoveItemFromSquare(topObject) end
			topSquare = aboveSquare
		elseif not (aboveSquare:Is(flags.Wall) or aboveSquare:Is(IsoFlagType.WallNW)) then
			if topObject then topSquare:transmitRemoveItemFromSquare(topObject) end
			topSquare = aboveSquare
			break
		else
			Ladders.removeTopOfLadder(aboveSquare)
			break
		end
	end

	-- if topSquare == square then return end
	topObject = Ladders.addTopOfLadder(topSquare, north)
end

function Ladders.makeLadderClimbableFromTop(square)

	local x = square:getX()
	local y = square:getY()
	local z = square:getZ() - 1

	local belowSquare = getSquare(x, y, z)
	if belowSquare then
		Ladders.makeLadderClimbableFromBottom(getSquare(x - 1, y,     z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x + 1, y,     z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x,     y - 1, z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x,     y + 1, z))
	end
end

function Ladders.makeLadderClimbableFromBottom(square)

	if not square then return end

	local props = square:getProperties()
	if props:Is(IsoFlagType.climbSheetN) then
		Ladders.makeLadderClimbable(square, true)
	elseif props:Is(IsoFlagType.climbSheetW) then
		Ladders.makeLadderClimbable(square, false)
	end
end

-- The wookiee says to use getCore():getKey("Interact")
-- because then it respects their vanilla rebindings.
function Ladders.OnKeyPressed(key)
	if key == getCore():getKey("Interact") then
		local player = getPlayer()
		if not player or player:isDead() then return end
		if MainScreen.instance:isVisible() then return end

		-- Will store last player to attempt to climb a ladder.
		Ladders.player = player

		local square = player:getSquare()
		Ladders.makeLadderClimbableFromTop(square)
		Ladders.makeLadderClimbableFromBottom(square)
	end
end

Events.OnKeyPressed.Add(Ladders.OnKeyPressed)

--
-- When a player places a crafted ladder, he won't be able to climb it unless:
-- - the ladder sprite has the proper flags set
-- - the player moves to another chunk and comes back
-- - the player quit and load the saved game
-- - the same sprite was already spawned and went through the LoadGridsquare event
--
-- We add the missing flags here to work around the issue.
--

-- Compatibility: Adding a backup for anyone who needs it.

Ladders.ISMoveablesAction = {
	perform = ISMoveablesAction.perform
}

local ISMoveablesAction_perform = ISMoveablesAction.perform

function ISMoveablesAction:perform()

	ISMoveablesAction_perform(self)

	if self.mode == 'pickup' then
		Ladders.removeTopOfLadder(getSquare(self.square:getX(),self.square:getY(),self.square:getZ()+1))
	end
end

require "TimedActions/ISDestroyStuffAction"
Ladders.ISDestroyStuffAction = {
	perform = ISDestroyStuffAction.perform,
 }

function ISDestroyStuffAction:perform()
	if self.item:haveSheetRope() then
		Ladders.removeTopOfLadder(self.item:getSquare())
	end
	return Ladders.ISDestroyStuffAction.perform(self)
end

---Changes player variables when climb starts.
---@param character IsoGameCharacter
---@param square IsoGridSquare | nil
function Ladders.chooseAnimVar_climbStart(character,square)
	if not instanceof(character,"IsoPlayer") or square == nil then return end
	local isLadderStart
	if square:Is(IsoFlagType.climbSheetE) then
		-- isLadderStart = square:getProperties():Val("Climbable") == "LadderE"
	elseif square:Is(IsoFlagType.climbSheetW) then
		isLadderStart = square:getProperties():Val("ClimbableW") == "Ladder"
	elseif square:Is(IsoFlagType.climbSheetS) then
		-- isLadderStart = square:getProperties():Val("Climbable") == "LadderS"
	elseif square:Is(IsoFlagType.climbSheetN) then
		isLadderStart = square:getProperties():Val("ClimbableN") == "Ladder"
	end
	if isLadderStart then
		character:setVariable("ClimbLadder", true)
	else
		character:clearVariable("ClimbLadder")
	end
end

---Find when state changes to climb sheet. This is better in performance than OnPlayerUpdate unless there are a ton of zombies.
---
---Triggers for remote players too, removing need to transmit changes.
---@param character IsoGameCharacter
---@param currentState State
---@param previousState State
function Ladders.OnAiStateChange(character, currentState, previousState)
	if currentState == climbrope_instance then
		Ladders.chooseAnimVar_climbStart(character,character:getSquare())
	elseif currentState == climbdownrope_instance then
		local sq = character:getSquare()
		if sq ~= nil then
			Ladders.chooseAnimVar_climbStart(character,getSquare(sq:getX(),sq:getY(),sq:getZ()-1))
		end
	end
end

Events.OnAIStateChange.Add(Ladders.OnAiStateChange)

return Ladders
