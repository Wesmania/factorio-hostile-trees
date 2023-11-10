local area_util = require("modules/area_util")
local util = require("modules/util")
local tree_events = require("modules/tree_events")

local M = {}

local function pick_building(s)
	if #s.buildings == 0 then return nil end
	local bi = math.random(1, #s.buildings)
	local building = s.buildings[bi]
	if not building.valid then
		util.list_remove(s.buildings, bi)
		return nil
	else
		return building
	end
end

function M.event_building_spit_assault(s)
	if not s.surface.valid then return false end
	s.total_ticks = s.total_ticks + 1
	if s.total_ticks >= 600 then return false end
	if s.next_event > s.total_ticks then return true end

	local new_min = 999
	for _, tree in pairs(s.trees) do
		if not tree[2].valid then break end

		if s.total_ticks >= tree[1] then
			tree[1] = tree[1] + math.random(60, 90)
			local building = pick_building(s)
			if building ~= nil then
				tree_events.spit_at(s.surface, tree[2].position, building, s.tree_projectiles)
			end
		end
		if tree[1] < new_min then new_min = tree[1] end
	end
	s.next_event = new_min
	return true
end

M.building_spit_assault = function(surface, area, tree_projectiles)
	local s = {}
	s.trees = {}
	for i, tree in ipairs(util.pick_random(area_util.get_trees(surface, area), 10)) do
		s.trees[i] = {math.random(60, 90), tree}
	end
	s.surface = surface
	s.area = area
	s.buildings = area_util.get_buildings(surface, area)
	s.total_ticks = 0
	s.next_event = 0
	s.tree_projectiles = tree_projectiles
	s.event_name = "event_building_spit_assault"
	return s
end

function M.event(surface, area)
	local random = math.random()
	local tree = area_util.get_random_tree(surface, area)
	local building = area_util.get_random_building(surface, area)

	-- Small chance to take over enemy turrets.
	if math.random() < 0.15 then
		local turret = area_util.get_random_turret(surface, area)
		if turret ~= nil then
			tree_events.take_over_turret(turret)
			return
		end
	end

	if random < 0.07 then
		tree_events.spit_trees_towards_buildings(surface, tree, building)
	elseif random < 0.25 then
		tree_events.spread_trees_towards_buildings(surface, tree, building)
	elseif random < 0.4 then
		tree_events.set_tree_on_fire(surface, tree)
	elseif random < 0.5 then
		tree_events.small_tree_explosion(surface, tree)
	elseif random < 0.6 then
		if tree ~= nil then
			tree_events.spawn_biters(surface, tree.position, math.random(3, 5))
		end
	elseif random < 0.85 then
		if tree ~= nil and building ~= nil then
			tree_events.spitter_projectile(surface, tree.position, building.position)
		end
	elseif random < 0.95 then
		if tree ~= nil and building ~= nil then
			tree_events.fire_stream(surface, tree.position, building.position)
		end
	else
		local projectile_kinds = {
			{ "spitter_projectile" },
			{ "fire_stream" },
			{ "spitter_projectile", "fire_stream" },
		}
		global.tree_stories[#global.tree_stories + 1] = M.building_spit_assault(surface, area, projectile_kinds[math.random(1, #projectile_kinds)])
	end
end

-- Events from tree_events that we want available as tree stories.

-- For tree_events.spawn_biters_over_time
function M.event_spawn_biters(s)
	return tree_events.event_spawn_biters(s)
end

function M.run_coro(s)
	return M[s.event_name](s)
end

return M
