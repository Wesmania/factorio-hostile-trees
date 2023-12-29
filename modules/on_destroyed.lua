local M = {}
local tree_events = require("modules/tree_events")
local car = require("modules/car")

script.on_event(defines.events.on_entity_destroyed, function(data)
	local event = global.entity_destroyed_script_events[data.registration_number]
	if event ~= nil then
		M[event.action](event)
	end
	global.entity_destroyed_script_events[data.registration_number] = nil
end)

function M.on_spawning_spit_landed(e)
	tree_events.on_spawning_spit_landed(e)
end

function M.on_exploding_hopper_landed(e)
	tree_events.on_exploding_hopper_landed(e)
end

function M.on_car_destroyed(e)
	car.on_car_destroyed(e)
end
