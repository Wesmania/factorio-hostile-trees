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
				else
					global.players[id] = {
						player = player.character,
						story = nil,
						tree_threat = 0,
					}
				end
				global.players_array[#global.players_array + 1] = global.players[id]
			end
		end
	end
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

	local res = {}
	-- Now normalize rates and set values.
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

M.cache_evolution_rates = function()
	local evolution = game.forces["enemy"].evolution_factor
	global.spawntable = {
		default = cache_evolution_for(evolution),
		retaliation = cache_evolution_for(evolution + 0.1),
	}
end

M.squares_to_check_per_tick_per_chunk = function(seconds_per_square)
	local ticks_per_square = seconds_per_square * 60
	local squares_per_chunk = 16
	return squares_per_chunk / ticks_per_square
end

M.initialize = function()
	global.players          = {}
	global.players_array    = {}
	global.tick_mod_10_s    = 0
	global.chunks           = 0
	global.accum            = 0
	global.tree_stories     = {}
	global.tree_kill_count  = 0
	global.tree_kill_locs   = {}
	global.major_retaliation_threshold = 200	-- FIXME balance

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
end

return M
