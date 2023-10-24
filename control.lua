local setup = require("modules/setup")

local config = setup.config

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


local function get_building(surface, area)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			for _, e in ipairs(surface.find_entities_filtered{area = area, force = force}) do
				if e.prototype.is_building then return e end
			end
		end
	end
	return nil
end

-- Only call it after we did an entity / tree check
local function has_buildings(surface, area)
	return get_building(surface, area) ~= nil
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

local function get_trees(surface, area)
	return surface.find_entities_filtered{area = area, name = global.surface_trees}
end

local function get_tree(surface, area)
	local global = global
	return surface.find_entities_filtered{area = area, name = global.surface_trees, limit = 1}[1]
end

local function count_chunks(surface)
	local global = global
	global.chunks = 0
	for _ in surface.get_chunks() do
		global.chunks = global.chunks + 1
	end
end

local function squares_to_check_per_tick()
	return global.chunks * config.factory_events_per_tick_per_chunk
end

-- TODO consider passing an argument by reference and using blocals to avoid allocation. Might be premature optimization?
local function position(entity)
	local bb = entity.bounding_box
	return {
		x = (bb.left_top.x + bb.right_bottom.x) / 2,
		y = (bb.left_top.y + bb.right_bottom.y) / 2,
	}
end

-- Tree-factory interactions

local function factory_event_spread_trees(surface, area)
	-- TODO select tree and building randomly instead of first from the list?
	local tree = get_tree(surface, area)
	if tree == nil then return end
	local building = get_building(surface, area)
	if building == nil then return end
	local treepos = position(tree)
	local buildingpos = position(building)
	-- Spread 3 to 5 trees two thirds of the way between the building and the tree.
	treepos.x = (treepos.x * 2 + buildingpos.x) / 3
	treepos.y = (treepos.y * 2 + buildingpos.y) / 3
	for i = 1,global.rng(3, 5) do
		buildingpos.x = treepos.x + (global.rng() * 3)
		buildingpos.y = treepos.y + (global.rng() * 3)
		surface.create_entity{name = tree.name, position = buildingpos}
	end
end

local function factory_event_set_tree_on_fire(surface, area)
	local tree = get_tree(surface, area)
	if tree == nil then return end
	local at = position(tree)
	tree.destroy()
	surface.create_entity{
		name = 'fire-flame-on-tree',
		position = at,
	}
end

local function factory_event_small_tree_explosion(surface, area)
	local tree = get_tree(surface, area)
	if tree == nil then return end
	local at = position(tree)
	tree.destroy()
	surface.create_entity{
		name = 'land-mine-explosion',
		position = at,
	}
	deal_damage_to_player_entities(surface, at, 5, 100)
end

local function factory_event(surface, area)
	local random = global.rng()
	if random < 0.3 then
		factory_event_spread_trees(surface, area)
	elseif random < 0.9 then
		factory_event_set_tree_on_fire(surface, area)
	else
		factory_event_small_tree_explosion(surface, area)
	end
end

script.on_init(function()
	setup.initialize()
end)

script.on_event({defines.events.on_tick}, function(event)
	local global = global
	local surface = game.get_surface(1)

	global.tick_mod_10_s = (global.tick_mod_10_s + 1) % 600
	if global.tick_mod_10_s == 0 then
		count_chunks(surface)
	end

	-- FIXME replace with TODO when we add player events
	if not config.factory_events then return end

	if not surface or not surface.valid then
		return
	end

	global.accum = global.accum + squares_to_check_per_tick()
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
		    	factory_event(surface, box)
		end
	end
end)
