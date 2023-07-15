--[[
	Set sprite properties for climbing, square takes properties from objects, objects from sprites.
	To prevent falling during climbing we make the custom sprites more persistent and able to pass their properties to the square.
	IDs used are in the range for fileNumber 100, used by mod SpearTraps
--]]

local Ladders = {}

Ladders.idW, Ladders.idN = 26476542, 26476543
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
	Ladders.chooseAnimVar(topSquare,topObject)
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

--topObject means we added custom ladder object, excluded tile list is smaller that included
function Ladders.chooseAnimVar(square,topObject)
	local doLadderAnim
	if topObject then
		doLadderAnim = true
		local objects = square:getObjects()
		for i = 0, objects:size() - 1 do
			local sprite = objects:get(i):getTextureName()
			if Ladders.excludeAnimTiles[sprite] then
				doLadderAnim = false
				break
			end
		end
	end
	if doLadderAnim then
		Ladders.player:setVariable("ClimbLadder", true)
	else
		Ladders.player:clearVariable("ClimbLadder")
	end
end

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

--- Generate Table for faster check during anim choice
--Ladders.ladderTiles = {}
--
--for each, name in ipairs(Ladders.westLadderTiles) do
--	Ladders.ladderTiles[name] = true
--end
--
--for each, name in ipairs(Ladders.northLadderTiles) do
--	Ladders.ladderTiles[name] = true
--end
Ladders.excludeAnimTiles = {}
for each, name in ipairs(Ladders.poleTiles) do
	Ladders.excludeAnimTiles[name] = true
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

	local spriteW = manager:AddSprite(Ladders.climbSheetTopW,Ladders.idW)
	spriteW:setName(Ladders.climbSheetTopW)
	local propsW = spriteW:getProperties()
	propsW:Set(IsoFlagType.climbSheetTopW)
	propsW:Set(IsoFlagType.HoppableW)
	propsW:CreateKeySet()

	local spriteN = manager:AddSprite(Ladders.climbSheetTopN,Ladders.idN)
	spriteN:setName(Ladders.climbSheetTopN)
	local propsN = spriteN:getProperties()
	propsN:Set(IsoFlagType.climbSheetTopN)
	propsN:Set(IsoFlagType.HoppableN)
	propsN:CreateKeySet()

end

Events.OnLoadedTileDefinitions.Add(Ladders.setLadderClimbingFlags)

return Ladders
