local Ladders = {}

Ladders.topOfLadder = 'TopOfLadder'

function Ladders.getLadderObject(square)
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		local sprite = object:getSprite()
		if sprite then
			local prop = sprite:getProperties()
			if prop:Is(IsoFlagType.climbSheetN) or prop:Is(IsoFlagType.climbSheetS) or prop:Is(IsoFlagType.climbSheetE) or prop:Is(IsoFlagType.climbSheetW) then
				return object
			end
		end
	end
end

function Ladders.setTopOfLadderFlags(square, sprite, north)

	if north then

		sprite:getProperties():Set(IsoFlagType.climbSheetTopN)
		square:getProperties():Set(IsoFlagType.climbSheetTopN)

		sprite:getProperties():Set(IsoFlagType.HoppableN)
		square:getProperties():Set(IsoFlagType.HoppableN)

	else
		sprite:getProperties():Set(IsoFlagType.climbSheetTopW)
		square:getProperties():Set(IsoFlagType.climbSheetTopW)

		sprite:getProperties():Set(IsoFlagType.HoppableW)
		square:getProperties():Set(IsoFlagType.HoppableW)
	end
end

function Ladders.addTopOfLadder(square, north)

	if square:getProperties():Is(IsoFlagType.WallN) or square:getProperties():Is(IsoFlagType.WallW) then
		return
	end

	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		local name = object:getName()
		if name == Ladders.topOfLadder then
			Ladders.setTopOfLadderFlags(square, object:getSprite(), north)
			return
		end
	end

	local sprite = IsoSprite.new()
	Ladders.setTopOfLadderFlags(square, sprite, north)
	object = IsoObject.new(getCell(), square, sprite)
	object:setName(Ladders.topOfLadder)
	square:transmitAddObjectToSquare(object, -1)
end

function Ladders.removeTopOfLadder(square)

	local x = square:getX()
	local y = square:getY()

	for z = square:getZ() + 1, 8 do
		local aboveSquare = getSquare(x, y, z)
		if not aboveSquare then
			return
		end
		local objects = aboveSquare:getObjects()
		for i = 0, objects:size() - 1 do
			local object = objects:get(i)
			local name = object:getName()
			if name == Ladders.topOfLadder then
				aboveSquare:transmitRemoveItemFromSquare(object)
				return
			end
		end
	end
end

function Ladders.makeLadderClimbable(square, north)

	local x, y = square:getX(), square:getY()

	local topObject = nil
	local topSquare = square
	for z = square:getZ(), 8 do

		local aboveSquare = getSquare(x, y, z + 1)
		local object = Ladders.getLadderObject(aboveSquare)
		if not object then
			Ladders.addTopOfLadder(aboveSquare, north)
			break
		end
	end
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

	if not square then
		return
	end

	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		local sprite = object:getSprite()
		if sprite then
			local prop = sprite:getProperties()
			if prop:Is(IsoFlagType.climbSheetN) then
				Ladders.makeLadderClimbable(square, true)
				break
			elseif prop:Is(IsoFlagType.climbSheetW) then
				Ladders.makeLadderClimbable(square, false)
				break
			end
		end
	end
end

function Ladders.OnKeyPressed(key)
    if key == Keyboard.KEY_E then
		local square = getPlayer():getSquare()
		Ladders.makeLadderClimbableFromTop(square)
		Ladders.makeLadderClimbableFromBottom(square)
	end
end

Events.OnKeyPressed.Add(Ladders.OnKeyPressed)

--
-- Some tiles for ladders are missing the proper flags to
-- make them climbable so we add the missing flags here.
--

Ladders.tileFlags = {}

Ladders.tileFlags.location_sewer_01_32    = IsoFlagType.climbSheetW
Ladders.tileFlags.location_sewer_01_33    = IsoFlagType.climbSheetN

Ladders.tileFlags.industry_railroad_05_20 = IsoFlagType.climbSheetW
Ladders.tileFlags.industry_railroad_05_21 = IsoFlagType.climbSheetN

Ladders.tileFlags.industry_railroad_05_36 = IsoFlagType.climbSheetW
Ladders.tileFlags.industry_railroad_05_37 = IsoFlagType.climbSheetN

function Ladders.LoadGridsquare(square)

	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do

		local sprite = objects:get(i):getSprite()
		if sprite then
			local name = sprite:getName()
			if Ladders.tileFlags[name] then
				sprite:getProperties():Set(Ladders.tileFlags[name])
				square:getProperties():Set(Ladders.tileFlags[name])
			end
		end
	end
end

Events.LoadGridsquare.Add(Ladders.LoadGridsquare)

--
-- When a player places a crafted ladder, he won't be able to climb it unless:
-- - the ladder sprite has the proper flags set
-- - the player moves to another chunk and comes back
-- - the player quit and load the saved game
-- - the same sprite was already spawned and went through the LoadGridsquare event
--
-- We add the missing flags here to work around the issue.
--

local ISMoveablesAction_perform = ISMoveablesAction.perform
function ISMoveablesAction:perform()

	ISMoveablesAction_perform(self)

	if self.mode == 'pickup' then
		Ladders.removeTopOfLadder(self.square)

	elseif self.mode == 'place' then
		Ladders.makeLadderClimbableFromBottom(self.square)
	end
end
