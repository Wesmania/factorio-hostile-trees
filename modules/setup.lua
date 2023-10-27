local M = {}

M.config = {}

M.cache_players = function()
	global.players = {}

	for _, force in pairs(game.forces) do
		for _, player in pairs(force.players) do
			if player.character ~= nil then
				global.players[#global.players + 1] = player.character
			end
		end
	end
end

M.cache_tree_prototypes = function()
	local st = {}
	for _, p in pairs(game.get_filtered_entity_prototypes{{filter='type', type='tree'}}) do
		if p.emissions_per_second > 0 or p.emissions_per_second > -0.0005 then goto skip end
		table.insert(st, p.name)
	::skip:: end
	global.surface_trees = st
end

M.squares_to_check_per_tick_per_chunk = function(seconds_per_square)
	local ticks_per_square = seconds_per_square * 60
	local squares_per_chunk = 16
	return squares_per_chunk / ticks_per_square
end

M.initialize = function()
	global.players          = {}
	global.surface_trees    = {}
	global.tick_mod_10_s    = 0
	global.chunks           = 0
	global.accum            = 0
	global.stories          = {}
	global.tree_stories     = {}
	global.tree_kill_count  = 0
	global.tree_kill_locs   = {}
	global.major_retaliation_threshold = 200	-- FIXME balance

	M.config.factory_events = settings.global["hostile-trees-do-trees-hate-your-factory"].value
	local fe_intvl = settings.global["hostile-trees-how-often-do-trees-hate-your-factory"].value
	M.config.factory_events_per_tick_per_chunk = M.squares_to_check_per_tick_per_chunk(fe_intvl)

	M.cache_tree_prototypes()
	M.cache_players()
end

return M
