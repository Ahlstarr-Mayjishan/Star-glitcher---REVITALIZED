--!strict

local PlaceProfiles = {}

local ULTRAHELL_PLACE_IDS = table.freeze({
	[17370343253] = true, -- Reality#012-1
})

local MAIN_PROFILE = table.freeze({
	Name = "Main",
	EnableGamemodeTools = false,
})

local ULTRAHELL_PROFILE = table.freeze({
	Name = "UltraHell",
	EnableGamemodeTools = true,
})

function PlaceProfiles.IsUltraHell(placeId: number): boolean
	return ULTRAHELL_PLACE_IDS[placeId] == true
end

function PlaceProfiles.Get(placeId: number)
	if PlaceProfiles.IsUltraHell(placeId) then
		return ULTRAHELL_PROFILE
	end

	return MAIN_PROFILE
end

return table.freeze(PlaceProfiles)
