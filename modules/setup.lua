local util = require("modules/util")
local ents = require("modules/ent_generation")

local M = {}

M.config = {}

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

local function interpolate_evolution_rates(evolution, rates, new_entries, rate_adjust)
	for _, entry in ipairs(rates) do
		local unit = entry.unit
		local unit_rates = entry.spawn_points
		local probability = nil
		if unit_rates[1].evolution_factor >= evolution then
			probability = unit_rates[1].weight
		end
		if unit_rates[#unit_rates].evolution_factor <= evolution then
			probability = unit_rates[#unit_rates].weight
		end
		for i = 1,#unit_rates - 1 do
			-- Linear interpolation, rates are ascending by evolution_factor
			if unit_rates[i].evolution_factor <= evolution and evolution < unit_rates[i + 1].evolution_factor then
				local range = unit_rates[i + 1].evolution_factor - unit_rates[i].evolution_factor
				local r1 = (evolution - unit_rates[i].evolution_factor) / range
				probability = unit_rates[i].weight * r1 + unit_rates[i + 1].weight * (1 - r1)
			end
		end
		if probability == nil then
			probability = 0
		end
		if probability ~= 0 then
			new_entries[#new_entries + 1] = { unit, probability * rate_adjust}
		end
	end
end

local function normalize_rates(new_entries)
	local res = {}
	local total_prob = 0
	for _, entry in ipairs(new_entries) do
		total_prob = total_prob + entry[2]
	end

	local sum = 0
	for _, entry in ipairs(new_entries) do
		res[#res+ 1] = {entry[1], sum}
		sum = sum + entry[2] / total_prob
	end
	return res
end

local function cache_evolution_for(evolution)
	local new_entries = {}
	local enemy_rates = {
		biters = 0.75,
		spitters = 0.25,
	}

	-- Collect spawn rates from saved spawner tables.
	for enemy_kind, rates in pairs(global.spawnrates) do
		local rate_adjust = enemy_rates[enemy_kind]
		interpolate_evolution_rates(evolution, rates, new_entries, rate_adjust)
	end

	return normalize_rates(new_entries)
end

local function cache_evolution_for_ents(evolution)
	local new_entries = {}
	interpolate_evolution_rates(evolution, ents.spawnrates, new_entries, 1.0)
	return normalize_rates(new_entries)
end

M.cache_evolution_rates = function()
	local evolution = game.forces["enemy"].evolution_factor
	global.spawntable = {
		default = cache_evolution_for(evolution),
		retaliation = cache_evolution_for(evolution + 0.1),
		ents = cache_evolution_for_ents(evolution)
	}
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

function M.cache_squares_to_check_per_tick()
	global.squares_to_check_per_tick = #global.chunks.list * global.config.factory_events_per_tick_per_chunk
end

function M.cache_game_forces()
	global.game_forces = {}
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			global.game_forces[#global.game_forces + 1] = force
		end
	end
end

local function collect_chunks()
	local global = global
	global.chunks = {
		list = {},
		dict = {},
	}
	for c in global.surface.get_chunks() do
		util.ldict2_add(global.chunks, c.x, c.y, {
			x = c.x,
			y = c.y,
		})
	end
end

script.on_event(defines.events.on_chunk_generated, function(args)
	local p = args.position
	util.ldict2_add(global.chunks, p.x, p.y, {
		x = p.x,
		y = p.y,
	})
	M.cache_squares_to_check_per_tick()
end)

script.on_event(defines.events.on_chunk_deleted, function(args)
	for _, p in ipairs(args.positions) do
		util.ldict2_remove(global.chunks, p.x, p.y)
	end
	M.cache_squares_to_check_per_tick()
end)

-- This is also called when configuration changes. We don't have any long-term
-- state we need to preserve except grace period, so it's okay.
-- Also, Factorio deletes unknown entities for us, which is nice.
M.initialize = function()
	global.players          = {}
	global.players_array    = {}
	global.tick_mod_10_s    = 0
	global.accum            = 0
	global.tree_stories     = {}
	global.tree_kill_count  = 0
	global.robot_tree_deconstruct_count = 0
	global.tree_kill_locs   = {}
	global.major_retaliation_threshold = 200	-- FIXME balance
	global.surface          = game.get_surface("nauvis")
	global.players_focused_on = {
		list = {},
		dict = {},
	}
	global.entity_destroyed_script_events = {}

	collect_chunks()

	global.spawnrates = {}
	local biter_spawner = game.get_filtered_entity_prototypes{{filter="name", name="biter-spawner"}}["biter-spawner"]
	global.spawnrates.biters = biter_spawner.result_units
	local spitter_spawner = game.get_filtered_entity_prototypes{{filter="name", name="spitter-spawner"}}["spitter-spawner"]
	global.spawnrates.spitters = spitter_spawner.result_units
	global.spawn_table = {}

	M.config.factory_events = settings.global["hostile-trees-do-trees-hate-your-factory"].value
	local fe_intvl = settings.global["hostile-trees-how-often-do-trees-hate-your-factory"].value
	M.config.factory_events_per_tick_per_chunk = M.squares_to_check_per_tick_per_chunk(fe_intvl)

	M.config.player_events = settings.global["hostile-trees-do-trees-hate-you"].value
	M.config.player_event_frequency = settings.global["hostile-trees-how-often-do-trees-hate-you"].value
	M.config.retaliation_enabled = settings.global["hostile-trees-do-trees-retaliate"].value
	M.config.grace_period = settings.global["hostile-trees-how-long-do-trees-withhold-their-hate"].value * 60
	global.config = M.config
	M.cache_players()
	M.cache_evolution_rates()
	M.cache_trees_that_can_turn_into_ents()
	M.cache_squares_to_check_per_tick()
	M.cache_game_forces()
end

return M
