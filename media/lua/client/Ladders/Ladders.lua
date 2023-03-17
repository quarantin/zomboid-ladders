local Ladders = {}

--unused invisible sprites for better stability during climb (prev version lost the flags)
Ladders.climbSheetTopW = "crafted_01_6"
Ladders.climbSheetTopN = "crafted_01_7"

function Ladders.getLadderObject(square)
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		local sprite = object:getSprite()
		if sprite then
			local prop = sprite:getProperties()
			local name = sprite:getName()
			if prop:Is(IsoFlagType.climbSheetN) or prop:Is(IsoFlagType.climbSheetS) or prop:Is(IsoFlagType.climbSheetE) or prop:Is(IsoFlagType.climbSheetW) then
            	--if Ladders.player then
				--	if Ladders.ladderTiles[name] then
				--		Ladders.player:setVariable("ClimbLadder", true)
				--	else
				--		Ladders.player:clearVariable("ClimbLadder")
				--	end
				--end
				return object
			end
		end
	end
end

function Ladders.getTopOfLadder(square, north)
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local obj = objects:get(i)
		local sprite = obj:getTextureName()
		if north and sprite == Ladders.climbSheetTopN or not north and sprite == Ladders.climbSheetTopW then
			return obj
		end
	end
end

function Ladders.addTopOfLadder(square, north)

	local props = square:getProperties()
	if north then
		if props:Is(IsoFlagType.climbSheetTopN) then
			return Ladders.getTopOfLadder(square, north)
		elseif props:Is(IsoFlagType.WallN) then
			return
		end
	else
		if props:Is(IsoFlagType.climbSheetTopW) then
			return Ladders.getTopOfLadder(square, north)
		elseif props:Is(IsoFlagType.WallW) then
			return
		end
	end
	if props:Is(IsoFlagType.WallNW) or square:TreatAsSolidFloor() then return end

	local object = IsoObject.new(getCell(), square, north and Ladders.climbSheetTopN or Ladders.climbSheetTopW)
	square:transmitAddObjectToSquare(object, -1)

	return object
end

function Ladders.removeTopOfLadder(square)
	local x = square:getX()
	local y = square:getY()
	local z = square:getZ() + 1
	local aboveSquare = getSquare(x, y, z)
	if not aboveSquare then
		return
	end
	local objects = aboveSquare:getObjects()
	for i = objects:size() - 1, 0, - 1  do
		local object = objects:get(i)
		local sprite = object:getTextureName()
		if sprite == Ladders.climbSheetTopN or sprite == Ladders.climbSheetTopW then
			aboveSquare:transmitRemoveItemFromSquare(object)
			return
		end
	end
end

function Ladders.makeLadderClimbable(square, north)

	local x, y, z = square:getX(), square:getY(), square:getZ()

	local topObject
	--local topSquare = square
	while true do
		z = z + 1
		local aboveSquare = getSquare(x, y, z)
		if not aboveSquare then return end

		if not Ladders.getLadderObject(aboveSquare) then
			topObject = Ladders.addTopOfLadder(aboveSquare, north)
			break
		end
	end

	if topObject then
		Ladders.player:setVariable("ClimbLadder", true)
	else
		Ladders.player:clearVariable("ClimbLadder")
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
		Ladders.removeTopOfLadder(self.square)
	--elseif self.mode == 'place' then
	--	Ladders.makeLadderClimbableFromBottom(self.square)
	end
end

-- Animations

--
-- Some tiles for ladders are missing the proper flags to
-- make them climbable so we add the missing flags here.
--
-- We actually attempt to list all vanilla ladders in order
-- to flag them all using mod data; this allows us to base
-- our animation on whether the object is a ladder, rather than
-- simply climbable.
--
-- I also include many ladder tiles from mods.
--

-- This new technique for loading tiles is courtesy of Poltergeist.

Ladders.westLadderTiles = { 
	"industry_02_86", "location_sewer_01_32", "industry_railroad_05_20", "industry_railroad_05_36", "walls_commercial_03_0",
	"edit_ddd_RUS_decor_house_01_16", "edit_ddd_RUS_decor_house_01_19", "edit_ddd_RUS_industry_crane_01_72", 
	"edit_ddd_RUS_industry_crane_01_73", "rus_industry_crane_ddd_01_24", "rus_industry_crane_ddd_01_25", 
	"A1 Wall_48", "A1 Wall_80", "A1_CULT_36", "aaa_RC_6", "trelai_tiles_01_30", "trelai_tiles_01_38",
	"industry_crane_rus_72", "industry_crane_rus_73"
}

Ladders.northLadderTiles = { 
	"location_sewer_01_33", "industry_railroad_05_21", "industry_railroad_05_37",
	"edit_ddd_RUS_decor_house_01_17", "edit_ddd_RUS_decor_house_01_18", 
	"edit_ddd_RUS_industry_crane_01_76", "edit_ddd_RUS_industry_crane_01_77", 
	"A1 Wall_49", "A1 Wall_81", "A1_CULT_37", "aaa_RC_14", "trelai_tiles_01_31",
	"trelai_tiles_01_39", "industry_crane_rus_76", "industry_crane_rus_77",
}

for index = 1, 62 do
	local name = "basement_objects_02_" .. index
    if index % 2 == 0 then
        Ladders.westLadderTiles[#Ladders.westLadderTiles + 1] = name
    else
        Ladders.northLadderTiles[#Ladders.northLadderTiles + 1] = name
    end
end

Ladders.holeTiles = { 
	"floors_interior_carpet_01_24" 
}

Ladders.poleTiles = { 
	"recreational_sports_01_32", "recreational_sports_01_33" 
}

Ladders.ladderTiles = {}

for each, name in ipairs(Ladders.westLadderTiles) do
	Ladders.ladderTiles[name] = true
end

for each, name in ipairs(Ladders.northLadderTiles) do
	Ladders.ladderTiles[name] = true
end

Ladders.setLadderClimbingFlags = function(manager)
	local IsoFlagType, ipairs = IsoFlagType, ipairs

	for each, name in ipairs(Ladders.westLadderTiles) do
		manager:getSprite(name):getProperties():Set(IsoFlagType.climbSheetW)
	end

	for each, name in ipairs(Ladders.northLadderTiles) do
		manager:getSprite(name):getProperties():Set(IsoFlagType.climbSheetN)
	end

	for each, name in ipairs(Ladders.holeTiles) do
		local properties = manager:getSprite(name):getProperties()
		properties:Set(IsoFlagType.climbSheetTopW)
		properties:Set(IsoFlagType.HoppableW)
		properties:UnSet(IsoFlagType.solidfloor)
	end

	for each, name in ipairs(Ladders.poleTiles) do
		manager:getSprite(name):getProperties():Set(IsoFlagType.climbSheetW)
	end

	local topW = manager:getSprite(Ladders.climbSheetTopW):getProperties()
	topW:Set(IsoFlagType.climbSheetTopW)
	topW:Set(IsoFlagType.HoppableW)

	local topN = manager:getSprite(Ladders.climbSheetTopN):getProperties()
	topN:Set(IsoFlagType.climbSheetTopN)
	topN:Set(IsoFlagType.HoppableN)

end

Events.OnLoadedTileDefinitions.Add(Ladders.setLadderClimbingFlags)

return Ladders
