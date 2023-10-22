local function cache_forces()
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			global.forces[#global.forces + 1] = force.name
		end
	end
end

local function cache_surfaces()
	if game then
		global.surfaces = {}
		for s in string.gmatch(config.surfaces, '([^,;]+)') do
			local su = game.get_surface(s)
			if not su then
				if tonumber(s) then
					su = game.get_surface(tonumber(s))
				end
			end
			if su and su.valid then
				table.insert(global.surfaces, su.index)
			end
		end
		if (#global.surfaces < 1) then
			global.surfaces = {1}
		end
	end
end

local function cache_tree_prototypes()
	local st = {}
	for _, p in pairs(game.get_filtered_entity_prototypes{{filter='type', type='tree'}}) do
		if p.emissions_per_second > 0 or p.emissions_per_second > -0.0005 then goto skip end
		table.insert(st, p.name)
	::skip:: end
	global.surface_trees = st
end

local function initialize()
	global.surfaces         = {}
	global.last_surface     = nil
	global.forces           = {}
	global.rng              = game.create_random_generator()
	global.surface_trees    = {}

	cache_surfaces()
	cache_forces()
	cache_tree_prototypes()
end

local function has_player_entities(surface, position, radius)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then goto continue end
		if surface.count_entities_filtered{position = position, radius = radius, force = force, limit = 1} > 0 then
			return true
		end
		::continue::
	end
	return false
end

local function has_trees(surface, position, radius)
	return surface.count_entities_filtered(position = position, radius = radius, name = global.surface_trees, limit = 1) > 0
end

local function get_tree(surface, position, radius)
	return surface.find_entities_filtered(position = position, radius = radius, name = global.surface_trees, limit = 1)
end

script.on_event({defines.events.on_forces_merging, defines.events.on_player_changed_force}, cache_forces)

script.on_event({defines.events.on_tick}, function(event)
	local global = global
	local last_surface, surface_index = next(global.surfaces, global.last_surface)
	if surface_index then
		local surface = game.get_surface(surface_index)
		if not surface or not surface valid then
			return
		end
		local chunk = surface.get_random_chunk()
		local map_pos = {
			x: chunk.x * 32 + global.rng(0, 32),
			y: chunk.y * 32 + global.rng(0, 32),
		}
		
		if has_player_entities(surface, map_pos, 5) and has_trees(surface, map_pos, 5) then
			local some_trees = get_tree(surface, map_pos, 5)
			for _, e in ipair(trees) do
				e.destroy()
			end
		end
	end
	global.last_surface = last_surface
end)
