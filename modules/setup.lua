local util = require("modules/util")
local chunks = require("modules/chunks")
local ents = require("modules/ent_generation")
local electricity = require("modules/electricity")
local cache_evolution = require("modules/cache_evolution")
local car = require("modules/car")

local M = {}

M.cache_players = function()
	local old_players = global.players
	global.players = {}
	global.players_array = {}

	for _, force in pairs(game.forces) do
		for _, player in pairs(force.players) do
			if player.character ~= nil then
				local id = player.character.unit_number
				if old_players[id] ~= nil then
					global.players[id] = old_players[id]
					global.players[id].player = player.character
				else
					global.players[id] = {
						player = player.character,
						story = nil,
						tree_threat = 0,
						big_tree_threat = 0,
					}
				end
				global.players_array[#global.players_array + 1] = global.players[id]
			end
		end
	end
end

M.squares_to_check_per_tick_per_chunk = function(seconds_per_square)
	local ticks_per_square = seconds_per_square * 60
	local squares_per_chunk = 16
	return squares_per_chunk / ticks_per_square
end

function M.cache_trees_that_can_turn_into_ents()
	local names = {}
	for name, _ in pairs(game.entity_prototypes) do
		local parts = ents.split_ent_entity_name(name)
		if parts ~= nil then
			names[parts.name] = true
		end
	end
	global.entable_trees = names
end

function M.cache_electric_trees()
	local names = {}
	for name, _ in pairs(game.entity_prototypes) do
		local parts = electricity.split_electric_tree_name(name)
		if parts ~= nil then
			names[parts.name] = true
		end
	end
	global.electric_trees = names
end


function M.cache_game_forces()
	global.game_forces = {}
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			global.game_forces[#global.game_forces + 1] = force
		end
	end
end

script.on_event(defines.events.on_chunk_generated, function(e)
	chunks.on_chunk_generated(global.chunks, e.position)
end)
script.on_event(defines.events.on_chunk_deleted, function(e)
	chunks.on_chunk_deleted(global.chunk, e.position)
end)

function M.refresh_caches()
	M.cache_players()
	cache_evolution.cache_evolution_rates()
	M.cache_game_forces()
end

-- All things that can be safely initialized again without losing important state.
function M.reinitialize()
	local config = {}
	config.factory_events = settings.global["hostile-trees-do-trees-hate-your-factory"].value
	local fe_intvl = settings.global["hostile-trees-how-often-do-trees-hate-your-factory"].value
	config.factory_events_per_tick_per_chunk = M.squares_to_check_per_tick_per_chunk(fe_intvl)
	config.player_events = settings.global["hostile-trees-do-trees-hate-you"].value
	config.player_event_frequency = settings.global["hostile-trees-how-often-do-trees-hate-you"].value
	config.retaliation_enabled = settings.global["hostile-trees-do-trees-retaliate"].value
	config.grace_period = settings.global["hostile-trees-how-long-do-trees-withhold-their-hate"].value * 60
	global.config = config

	global.players          = {}
	global.players_array    = {}

	-- Used by main on-tick tree loop.
	global.tick_mod_10_s    = 0
	global.accum            = 0

	-- Used by tree events. Nothing here should affect long-lasting state.
	global.tree_stories  = {}

	-- Used by retaliation, not important.
	global.tree_kill_count  = 0
	global.robot_tree_deconstruct_count = 0
	global.tree_kill_locs   = {}
	global.major_retaliation_threshold = 200	-- FIXME balance
	
	global.surface          = game.get_surface("nauvis")

	-- Players temporarily focused on as retaliation, not important
	global.players_focused_on = {
		list = {},
		dict = {},
	}

	-- Spawn rates
	global.spawnrates = {}
	local biter_spawner = game.get_filtered_entity_prototypes{{filter="name", name="biter-spawner"}}["biter-spawner"]
	global.spawnrates.biters = biter_spawner.result_units
	local spitter_spawner = game.get_filtered_entity_prototypes{{filter="name", name="spitter-spawner"}}["spitter-spawner"]
	global.spawnrates.spitters = spitter_spawner.result_units

	M.refresh_caches()

	-- One time caches
	M.cache_trees_that_can_turn_into_ents()
	M.cache_electric_trees()
end

-- Set things up to *some* defaults like we used to.
local function before_0_2_1()
	if global.entity_destroyed_script_events == nil then
		global.entity_destroyed_script_events = {}
	end

	-- No cars before 0.2.1
	car.fresh_setup()

	-- New chunk format in 0.2.1
	chunks.fresh_setup()
end

-- Any version fixups will come here. First version with info is 0.2.1.
local version_changes = {
	-- 0.2.1: car bombs, electricity sapping
	{201, before_0_2_1}
}

local function version_to_number(s)
	a, b, c = string.find(s, "(%d+).(%d+).(%d+)")
	return a * 10000 + b * 100 + c
end

-- Reinitialize new and stateful features.
-- TODO
function M.port_state(old_version, new_version)
	local old_version = version_to_number(old_version)
	local new_version = version_to_number(new_version)

	for _, v in ipairs(version_changes) do
		local vv = v[1]
		local fn = v[2]
		if old_version < vv and vv <= new_version then
			fn()
		end
	end
end

function M.initialize(mod_info)
	M.reinitialize()

	if mod_info.mod_changes["hostile-trees"] ~= nil then
		local mi = mod_info.mod_changes["hostile-trees"]
		M.port_state(mi.old_version, mi.new_version)
	end
end

function M.initialize_fresh()
	M.reinitialize()

	-- Stateful, keeps track of existing entities.
	global.entity_destroyed_script_events = {}

	-- Stateful, keeps track of cars.
	car.fresh_setup()

	-- Stateful, holds active chunk mask info.
	chunks.fresh_setup()
end

return M
