local function cache_tree_prototypes()
	local st = {}
	for _, p in pairs(game.get_filtered_entity_prototypes{{filter='type', type='tree'}}) do
		if p.emissions_per_second > 0 or p.emissions_per_second > -0.0005 then goto skip end
		table.insert(st, p.name)
	::skip:: end
	global.surface_trees = st
end

local function initialize()
	global.rng              = game.create_random_generator()
	global.surface_trees    = {}
	global.tick_mod_10_s    = 0
	global.chunks           = 0
	global.accum            = 0

	cache_tree_prototypes()
end

local function has_player_entities(surface, area)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			if surface.count_entities_filtered{area = area, force = force, limit = 1} > 0 then
				return true
			end
		end
	end
	return false
end

-- Only call it after we did an entity / tree check
local function has_buildings(surface, area)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			for _, e in ipairs(surface.find_entities_filtered{area = area, force = force}) do
				if e.prototype.is_building then return true end
			end
		end
	end
	return false
end


local function deal_damage_to_player_entities(surface, position, radius, amount)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			for _, item in ipairs(surface.find_entities_filtered{position = position, radius = radius, force = force}) do
				if item.is_entity_with_health then
					item.damage(amount, "enemy", "explosion")
				end
			end
		end
	end
end

local function has_trees(surface, area)
	local global = global
	return surface.count_entities_filtered{area = area, name = global.surface_trees, limit = 1} > 0
end

local function get_tree(surface, area)
	local global = global
	return surface.find_entities_filtered{area = area, name = global.surface_trees, limit = 1}
end

local function count_chunks(surface)
	local global = global
	global.chunks = 0
	for _ in surface.get_chunks() do
		global.chunks = global.chunks + 1
	end
end

local function squares_to_check_per_tick(seconds_per_square)
	local global = global
	local ticks_per_square = seconds_per_square * 60
	local squares_per_chunk = 16
	return (squares_per_chunk * global.chunks) / ticks_per_square
end

script.on_init(function()
	initialize()
end)

script.on_event({defines.events.on_tick}, function(event)
	local global = global
	local surface = game.get_surface(1)

	global.tick_mod_10_s = (global.tick_mod_10_s + 1) % 600
	if global.tick_mod_10_s == 0 then
		count_chunks(surface)
	end

	if not surface or not surface.valid then
		return
	end

	global.accum = global.accum + squares_to_check_per_tick(5)	-- TODO configure
	local tocheck = math.floor(global.accum)
	global.accum = global.accum - tocheck

	for i = 1,tocheck do
		-- TODO do we define these as globals to avoid allocation cost?
		local chunk = surface.get_random_chunk()
		local map_pos = {
			x = chunk.x * 32 + global.rng(0, 32),
			y = chunk.y * 32 + global.rng(0, 32),
		}
		local box = {
			left_top = {
				x = map_pos.x - 4,
				y = map_pos.y - 4,
			},
			right_bottom = {
				x = map_pos.x + 4,
				y = map_pos.y + 4,
			},
		}
		
		if has_player_entities(surface, box) and has_trees(surface, box) -- These two first, they remove most checks
		    and has_buildings(surface, box) then
			local some_trees = get_tree(surface, box)
			for _, e in ipairs(some_trees) do
				local box = e.bounding_box
				local at = {
					x = (box.left_top.x + box.right_bottom.x) / 2,
					y = (box.left_top.y + box.right_bottom.y) / 2,
				}
				e.destroy()
				surface.create_entity{
					name = 'fire-flame-on-tree',
					position = at,
				}
				if global.rng() > 0.9 then
					surface.create_entity{
						name = 'land-mine-explosion',
						position = at,
					}
					deal_damage_to_player_entities(surface, at, 5, 100)
				end
			end
		end
	end
end)
