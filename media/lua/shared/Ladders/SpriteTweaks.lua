
local Ladders = {}
Ladders.idW, Ladders.idN = 26476542, 26476543
Ladders.climbSheetTopW = "TopOfLadderW"
Ladders.climbSheetTopN = "TopOfLadderN"

--
-- Burryaga tile list
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

Ladders.westLadderTiles = {
	"industry_02_86", "location_sewer_01_32", "industry_railroad_05_20", "industry_railroad_05_36", "walls_commercial_03_0",
	"edit_ddd_RUS_decor_house_01_16", "edit_ddd_RUS_decor_house_01_19", "edit_ddd_RUS_industry_crane_01_72",
	"edit_ddd_RUS_industry_crane_01_73", "rus_industry_crane_ddd_01_24", "rus_industry_crane_ddd_01_25",
	"A1 Wall_48", "A1 Wall_80", "A1_CULT_36", "aaa_RC_6", "trelai_tiles_01_30", "trelai_tiles_01_38",
	"industry_crane_rus_72", "industry_crane_rus_73",

    "basement_objects_02_2", "basement_objects_02_4", "basement_objects_02_6",
    "basement_objects_02_8", "basement_objects_02_10", "basement_objects_02_12",
    "basement_objects_02_14", "basement_objects_02_16", "basement_objects_02_18",
    "basement_objects_02_20", "basement_objects_02_22", "basement_objects_02_24",
    "basement_objects_02_26", "basement_objects_02_28", "basement_objects_02_30",
    "basement_objects_02_32", "basement_objects_02_34", "basement_objects_02_36",
    "basement_objects_02_38", "basement_objects_02_40", "basement_objects_02_42",
    "basement_objects_02_44", "basement_objects_02_46", "basement_objects_02_48",
    "basement_objects_02_50", "basement_objects_02_52", "basement_objects_02_54",
    "basement_objects_02_56", "basement_objects_02_58", "basement_objects_02_60",
    "basement_objects_02_62"
}

Ladders.northLadderTiles = {
	"location_sewer_01_33", "industry_railroad_05_21", "industry_railroad_05_37",
	"edit_ddd_RUS_decor_house_01_17", "edit_ddd_RUS_decor_house_01_18",
	"edit_ddd_RUS_industry_crane_01_76", "edit_ddd_RUS_industry_crane_01_77",
	"A1 Wall_49", "A1 Wall_81", "A1_CULT_37", "aaa_RC_14", "trelai_tiles_01_31",
	"trelai_tiles_01_39", "industry_crane_rus_76", "industry_crane_rus_77",

    "basement_objects_02_1", "basement_objects_02_3", "basement_objects_02_5",
    "basement_objects_02_7", "basement_objects_02_9", "basement_objects_02_11",
    "basement_objects_02_13", "basement_objects_02_15", "basement_objects_02_17",
    "basement_objects_02_19", "basement_objects_02_21", "basement_objects_02_23",
    "basement_objects_02_25", "basement_objects_02_27", "basement_objects_02_29",
    "basement_objects_02_31", "basement_objects_02_33", "basement_objects_02_35",
    "basement_objects_02_37", "basement_objects_02_39", "basement_objects_02_41",
    "basement_objects_02_43", "basement_objects_02_45", "basement_objects_02_47",
    "basement_objects_02_49", "basement_objects_02_51", "basement_objects_02_53",
    "basement_objects_02_55", "basement_objects_02_57", "basement_objects_02_59",
    "basement_objects_02_61"
}

Ladders.holeTiles = {
	"floors_interior_carpet_01_24"
}

Ladders.poleTiles = {
	"recreational_sports_01_32", "recreational_sports_01_33"
}

------------------------------------------------------------------------------------------------------------------------
-- register possible properties

do
    for _,dir in ipairs({"W","N","S","E"}) do
        local values = IsoWorld.PropertyValueMap:get("Climbable"..dir) or ArrayList.new()
        for _,val in ipairs({"Ladder","Pole"}) do
            if not values:contains(val) then values:add(val) end
        end
        IsoWorld.PropertyValueMap:put("Climbable"..dir,values)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- change sprite properties

Events.OnLoadedTileDefinitions.Add(function (spriteManager)
    local IsoFlagType, ipairs = IsoFlagType, ipairs
	local getSprite = getSprite
	local sprite, properties

	for each, name in ipairs(Ladders.westLadderTiles) do
		properties = getSprite(name):getProperties()
		properties:Set(IsoFlagType.climbSheetW)
		properties:Set("ClimbableW","Ladder")
		properties:CreateKeySet()
	end

	for each, name in ipairs(Ladders.northLadderTiles) do
		properties = getSprite(name):getProperties()
		properties:Set(IsoFlagType.climbSheetN)
		properties:Set("ClimbableN","Ladder")
		properties:CreateKeySet()
	end

	for each, name in ipairs(Ladders.poleTiles) do
		properties = getSprite(name):getProperties()
		properties:Set(IsoFlagType.climbSheetW)
		properties:Set("ClimbableW","Pole")
		-- properties:Set("ClimbableN","Pole")
		-- properties:Set("ClimbableE","Pole")
		-- properties:Set("ClimbableS","Pole")
		properties:CreateKeySet()
	end

	for each, name in ipairs(Ladders.holeTiles) do
		properties = getSprite(name):getProperties()
		properties:Set(IsoFlagType.climbSheetTopW)
		properties:Set(IsoFlagType.HoppableW)
		properties:UnSet(IsoFlagType.solidfloor)
		properties:CreateKeySet()
	end

	sprite = spriteManager:AddSprite(Ladders.climbSheetTopW,Ladders.idW)
	sprite:setName(Ladders.climbSheetTopW)
	properties = sprite:getProperties()
	properties:Set(IsoFlagType.climbSheetTopW)
	properties:Set(IsoFlagType.HoppableW)
    -- properties:Set("Climbable","LadderW")
	properties:CreateKeySet()

	sprite = spriteManager:AddSprite(Ladders.climbSheetTopN,Ladders.idN)
	sprite:setName(Ladders.climbSheetTopN)
	properties = sprite:getProperties()
	properties:Set(IsoFlagType.climbSheetTopN)
	properties:Set(IsoFlagType.HoppableN)
    -- properties:Set("Climbable","LadderN")
	properties:CreateKeySet()

end)

return Ladders