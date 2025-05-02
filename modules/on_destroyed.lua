local M = {}
local tree_events = require("modules/tree_events")
local belttrees = require("modules/belttrees")
local car = require("modules/car")
local electricity = require("modules/electricity")
local seed_mortar = require("modules/seed_mortar")
local oil = require("modules/oil")

script.on_event(defines.events.on_object_destroyed, function(data)
	local event = storage.entity_destroyed_script_events[data.registration_number]
	if event ~= nil and event.action ~= nil and M[event.action] ~= nil then
		M[event.action](event)
	end
	storage.entity_destroyed_script_events[data.registration_number] = nil
end)

function M.on_spawning_spit_landed(e)
	tree_events.on_spawning_spit_landed(e)
end

function M.on_belttree_spawning_spit_landed(e)
	belttrees.on_belttree_spawning_spit_landed(e)
end

function M.on_belttree_final_spit_landed(e)
	belttrees.on_belttree_final_spit_landed(e)
end

function M.on_exploding_hopper_landed(e)
	tree_events.on_exploding_hopper_landed(e)
end

function M.on_car_destroyed(e)
	car.on_car_destroyed(e)
end

function M.on_electric_tree_destroyed(e)
	electricity.on_electric_tree_destroyed(e)
end

function M.on_seed_mortar_landed(e)
	seed_mortar.on_seed_mortar_landed(e)
end
