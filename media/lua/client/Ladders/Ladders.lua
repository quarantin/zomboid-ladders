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

function Ladders.setFlags(square, sprite, flag)
	sprite:getProperties():Set(flag)
	square:getProperties():Set(flag)
end

function Ladders.unsetFlags(square, sprite, flag)
	sprite:getProperties():UnSet(flag)
	square:getProperties():UnSet(flag)
end

function Ladders.setTopOfLadderFlags(square, sprite, north)

	if north then
		Ladders.setFlags(square, sprite, IsoFlagType.climbSheetTopN)
		Ladders.setFlags(square, sprite, IsoFlagType.HoppableN)
	else
		Ladders.setFlags(square, sprite, IsoFlagType.climbSheetTopW)
		Ladders.setFlags(square, sprite, IsoFlagType.HoppableW)
	end
end

function Ladders.addTopOfLadder(square, north)

	local props = square:getProperties()
	if props:Is(IsoFlagType.WallN) or props:Is(IsoFlagType.WallW) or props:Is(IsoFlagType.WallNW) then
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
		if not aboveSquare then
			return
		end
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

-- The wookiee says to use getCore():getKey("Interact")
-- because then it respects their vanilla rebindings.
function Ladders.OnKeyPressed(key)
	if key == getCore():getKey("Interact") then
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

Ladders.holeTiles = {}
Ladders.holeTiles.floors_interior_carpet_01_24 = true

Ladders.poleTiles = {}
Ladders.poleTiles.recreational_sports_01_32 = true
Ladders.poleTiles.recreational_sports_01_33 = true

function Ladders.LoadGridsquare(square)

	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do

		local sprite = objects:get(i):getSprite()
		if sprite then
			local name = sprite:getName()
			if Ladders.tileFlags[name] then
				Ladders.setFlags(square, sprite, Ladders.tileFlags[name])
			elseif Ladders.holeTiles[name] then
				Ladders.setFlags(square, sprite, IsoFlagType.HoppableW)
				Ladders.setFlags(square, sprite, IsoFlagType.climbSheetTopW)
				Ladders.unsetFlags(square, sprite, IsoFlagType.solidfloor)
			elseif Ladders.poleTiles[name] and square:getZ() == 0 then
				Ladders.setFlags(square, sprite, IsoFlagType.climbSheetW)
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

-- Compatibility: Adding a backup for anyone who needs it.

Ladders.ISMoveablesAction = {
	perform = ISMoveablesAction.perform
}

local ISMoveablesAction_perform = ISMoveablesAction.perform

local ISMoveablesAction_perform = ISMoveablesAction.perform
function ISMoveablesAction:perform()

	ISMoveablesAction_perform(self)

	if self.mode == 'pickup' then
		Ladders.removeTopOfLadder(self.square)

	elseif self.mode == 'place' then
		Ladders.LoadGridsquare(self.square)
		Ladders.makeLadderClimbableFromBottom(self.square)
	end
end

return Ladders
