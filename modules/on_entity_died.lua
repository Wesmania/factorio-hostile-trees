-- There's seemingly a limit of one callback per event, so we collect them here.

local retaliation = require("modules/retaliation")
local electricity = require("modules/electricity")

script.on_event(defines.events.on_entity_died, function(event)
	if event.entity.type == "tree" then
		retaliation.tree_died(event)
	else
		electricity.pole_died(event)
	end
end, {
	{ filter = "type", type = "tree", },
	{ filter = "type", type = "electric-pole", }
})

script.on_event(defines.events.on_robot_mined_entity, function(event)
	if event.entity.type == "tree" then
		retaliation.tree_bot_deconstructed(event)
	else
		electricity.pole_bot_deconstructed(event)
	end
end, {
	{ filter = "type", type = "tree", },
	{ filter = "type", type = "electric-pole", }
})

script.on_event(defines.events.on_player_mined_entity, function(event)
	electricity.pole_mined(event)
end, {
	{ filter = "type", type = "electric-pole", }
})
