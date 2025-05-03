-- There's seemingly a limit of one callback per event, so we collect them here.

local retaliation = require("modules/retaliation")
local electricity = require("modules/electricity")
local oil = require("modules/oil")

script.on_event(defines.events.on_entity_died, function(event)
	if event.entity.type == "tree" then
		retaliation.tree_died(event)
	elseif event.entity.type == "electric-pole" then
		electricity.pole_died(event)
	elseif  event.entity.name == "hostile-trees-pipe-roots" or
		event.entity.name == "hostile-trees-pump-roots" or
		event.entity.name == "hostile-trees-pipe-roots-vertex" then
		oil.root_pipe_died(event)
	end
end, {
	{ filter = "type", type = "tree", },
	{ filter = "type", type = "electric-pole", },
	{ filter = "name", name = "hostile-trees-pipe-roots" },
	{ filter = "name", name = "hostile-trees-pump-roots" },
	{ filter = "name", name = "hostile-trees-pipe-roots-vertex" },
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
