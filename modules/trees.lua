local area_util = require("modules/area_util")
local util = require("modules/util")
local tree_events = require("modules/tree_events")

local M = {}

local function spit_at(tree, s)
	if #s.buildings == 0 then return end
	local bi = math.random(1, #s.buildings)
	local building = s.buildings[bi]
	if not tree.valid then return end
	if not building.valid then
		util.list_remove(s.buildings, bi)
		return
	end
	tree_events.spitter_projectile(s.surface, tree, building)
end

local SpitAssaultPrototype = {
	run = function(s)
		if not s.surface.valid then return false end
		s.total_ticks = s.total_ticks + 1
		if s.total_ticks == 600 then return false end

		if s.next_event <= s.total_ticks then
			if #s.buildings == 0 then return false end
			local new_min = 999
			for _, tree in pairs(s.trees) do
				if s.total_ticks >= tree[1] then
					spit_at(tree[2], s)
					tree[1] = tree[1] + math.random(60, 90)
				end
				if tree[1] < new_min then new_min = tree[1] end
			end
			s.next_event = new_min
		end

		return true
	end,
}

M.spit_assault = function(surface, area)
	local s = {}
	setmetatable(s, {__index = SpitAssaultPrototype})
	s.trees = {}
	for i, tree in ipairs(util.pick_random(area_util.get_trees(surface, area), 10)) do
		s.trees[i] = {math.random(60, 90), tree}
	end
	s.surface = surface
	s.area = area
	s.buildings = area_util.get_buildings(surface, area)
	s.total_ticks = 0
	s.next_event = 0
	return s
end

function M.event(surface, area)
	local random = math.random()
	do	-- FIXME for testing
		local tree = area_util.get_tree(surface, area)
		if tree == nil then return end
		tree_events.spawn_biters(surface, tree, math.random(3, 5))
		return
	end
	if random < 0.3 then
		tree_events.spread_trees_towards_buildings(surface, area)
	elseif random < 0.85 then
		tree_events.set_tree_on_fire(surface, area)
	elseif random < 0.95 then
		global.tree_stories[#global.tree_stories + 1] = M.spit_assault(surface, area)
	else
		tree_events.small_tree_explosion(surface, area)
	end
end

return M