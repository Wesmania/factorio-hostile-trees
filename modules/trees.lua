local area_util = require("modules/area_util")
local util = require("modules/util")
local tree_events = require("modules/tree_events")

local M = {}

local BuildingSpitAssaultPrototype = {
	pick_building = function(s)
		local bi = math.random(1, #s.buildings)
		local building = s.buildings[bi]
		if not building.valid then
			util.list_remove(s.buildings, bi)
			return nil
		else
			return building
		end
	end,
	run = function(s)
		if not s.surface.valid then return false end

		s.total_ticks = s.total_ticks + 1
		if s.total_ticks == 600 then return false end

		if s.next_event > s.total_ticks then return true end
		if #s.buildings == 0 then return false end

		local new_min = 999
		for _, tree in pairs(s.trees) do
			if not tree[2].valid then break end

			if s.total_ticks >= tree[1] then
				tree[1] = tree[1] + math.random(60, 90)
				local building = s.pick_building(s)
				if building ~= nil then
					tree_events.spit_at(s.surface, tree[2].position, building, s.tree_projectiles)
				end
			end
			if tree[1] < new_min then new_min = tree[1] end
		end
		s.next_event = new_min
		return true
	end,
}

M.building_spit_assault = function(surface, area, tree_projectiles)
	local s = {}
	setmetatable(s, {__index = BuildingSpitAssaultPrototype})
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
	return s
end

function M.event(surface, area)
	local random = math.random()
	local tree = area_util.get_random_tree(surface, area)
	local building = area_util.get_building(surface, area)

	if random < 0.25 then
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

return M
