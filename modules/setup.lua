local util = require("modules/util")
local chunks = require("modules/chunks")
local ents = require("modules/ent_generation")
local electricity = require("modules/electricity")
local cache_evolution = require("modules/cache_evolution")
local car = require("modules/car")
local belttrees = require("modules/belttrees")

local M = {}

M.cache_players = function()
	local old_players = storage.players
	storage.players = {}
	storage.players_array = {}

	for _, force in pairs(game.forces) do
		for _, player in pairs(force.players) do
			if player.character ~= nil then
				local id = player.character.unit_number
				if old_players[id] ~= nil then
					storage.players[id] = old_players[id]
					storage.players[id].player = player.character
				else
					storage.players[id] = {
						player = player.character,
						story = nil,
						tree_threat = 0,
						big_tree_threat = 0,
					}
				end
				storage.players_array[#storage.players_array + 1] = storage.players[id]
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
	for name, _ in pairs(prototypes.entity) do
		local parts = ents.split_ent_entity_name(name)
		if parts ~= nil then
			names[parts.name] = true
		end
	end
	storage.entable_trees = names
end

function M.cache_electric_trees()
	local names = {}
	for name, _ in pairs(prototypes.entity) do
		local parts = electricity.split_electric_tree_name(name)
		if parts ~= nil then
			names[parts.name] = true
		end
	end
	storage.electric_trees = names
end


function M.cache_game_forces()
	storage.game_forces = {}
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			storage.game_forces[#storage.game_forces + 1] = force
		end
	end
end

script.on_event(defines.events.on_chunk_generated, function(e)
	chunks.on_chunk_generated(storage.chunks, e.position, e.surface)
end)
script.on_event(defines.events.on_chunk_deleted, function(e)
	local surface = game.get_surface(e.surface_index)
	chunks.on_chunk_deleted(storage.chunk, e.position, surface)
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
	storage.config = config

	storage.players          = {}
	storage.players_array    = {}

	-- Used by main on-tick tree loop.
	storage.tick_mod_10_s    = 0
	storage.accum            = 0

	-- Used by tree events. Nothing here should affect long-lasting state.
	storage.tree_stories  = {}

	-- Players temporarily focused on as retaliation, not important
	storage.players_focused_on = {
		list = {},
		dict = {},
	}

	-- Spawn rates
	storage.spawnrates = {}
	local biter_spawner = prototypes.get_entity_filtered{{filter="name", name="biter-spawner"}}["biter-spawner"]
	storage.spawnrates.biters = biter_spawner.result_units
	local spitter_spawner = prototypes.get_entity_filtered{{filter="name", name="spitter-spawner"}}["spitter-spawner"]
	storage.spawnrates.spitters = spitter_spawner.result_units

	M.refresh_caches()

	-- One time caches
	M.cache_trees_that_can_turn_into_ents()
	M.cache_electric_trees()
end

-- Set things up to *some* defaults like we used to.
local function before_0_2_1()
	if storage.entity_destroyed_script_events == nil then
		storage.entity_destroyed_script_events = {}
	end

	-- No cars before 0.2.1
	car.fresh_setup()

	-- New chunk format in 0.2.1
	chunks.fresh_setup()

	-- Electrified trees, new in 0.2.1
	electricity.fresh_setup()
end

local function on_0_2_3()
	belttrees.fresh_setup()
end

-- Any version fixups will come here. First version with info is 0.2.1.
local version_changes = {
	-- 0.2.1: car bombs, electricity sapping
	{201, before_0_2_1},
	{203, on_0_2_3},
}

local function version_to_number(s)
	_, _, a, b, c = string.find(s, "(%d+).(%d+).(%d+)")
	return tonumber(a) * 10000 + tonumber(b) * 100 + tonumber(c)
end

-- Reinitialize new and stateful features.
function M.port_state(old_version, new_version)
	if old_version == nil then
		return
	end
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
	storage.entity_destroyed_script_events = {}

	-- Stateful, keeps track of cars.
	car.fresh_setup()

	-- Stateful, holds active chunk mask info.
	chunks.fresh_setup()

	-- Stateful, keeps electrified tree state.
	electricity.fresh_setup()

	belttrees.fresh_setup()
end

return M
