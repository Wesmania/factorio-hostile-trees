local setup = require("modules/setup")
local util = require("modules/util")
local area_util = require("modules/area_util")
local tree_events = require("modules/tree_events")

local config = setup.config

script.on_nth_tick(30 * 60, function()
	global.tree_kill_count = 0
	global.tree_kill_locs = {}
	global.major_retaliation_threshold = 250	-- FIXME balance
end)

local function pos_to_coords(pos)
	local chunk_x = math.floor(pos.x / 32)
	local chunk_y = math.floor(pos.x / 32)
	return {chunk_x, chunk_y}
end

local function register_tree_death_loc(event)
	local tree = event.entity
	local treepos = tree.position
	local chunk_x, chunk_y = table.unpack(pos_to_coords(treepos))
	local mx = global.tree_kill_locs[chunk_x]
	if mx == nil then
		mx = {}
		global.tree_kill_locs[chunk_x] = mx
	end
	if mx[chunk_y] == nil then
		mx[chunk_y] = 0
	end
	mx[chunk_y] = mx[chunk_y] + 1
end

local function check_for_minor_retaliation(surface, event)
	local tree = event.entity
	local treepos = tree.position

	local enemy = surface.find_nearest_enemy_entity_with_owner{position=treepos, max_distance=32, force="enemy"}

	local rand = math.random()
	if rand < 0.3 then
		tree_events.spawn_biters(surface, treepos, math.random(1, 2), "retaliation")
	elseif rand < 0.85 and enemy ~= nil then
		local projectiles = tree_events.default_random_projectiles()
		for i = 1,math.random(1, 2) do
			local random_loc = util.random_offset(treepos, 2)
			tree_events.spit_at(surface, treepos, enemy, projectiles)
		end
	else
		tree_events.poison_cloud(surface, treepos)
	end
end

local function check_for_major_retaliation(surface, event)
	local tree = event.entity
	local treepos = tree.position
	local chunk_x, chunk_y = table.unpack(pos_to_coords(treepos))

	-- Check neighbouring chunks
	local counts = 0
	for i = chunk_x - 2,chunk_x + 2 do
		local mx = global.tree_kill_locs[i]
		if mx ~= nil then
			for j = chunk_y - 2,chunk_y + 2 do
				if mx[j] ~= nil then
					counts = counts + mx[j]
				end
			end
		end
	end

	if counts < 5 then return end
	-- Try to find a forested place to spawn from
	local spawn_tree = nil
	local biter_count = nil
	for i = 1,6 do
		local random_area = util.box_around({
			x = treepos.x - 12 + math.random(1, 24),
			y = treepos.y - 12 + math.random(1, 24),
		}, 4)
		if area_util.count_trees(surface, random_area, 20) >= 20 then
			spawn_tree = area_util.get_random_tree(surface, random_area)
			break
		end
	end

	if spawn_tree == nil then
		spawn_tree = tree
		biter_count = math.random(10, 15)
	else
		biter_count = math.random(30, 50)
	end

	global.tree_stories[#global.tree_stories + 1] = tree_events.spawn_biters_over_time(surface, spawn_tree.position, biter_count, "retaliation")

	-- Clear counts in neighbouring chunks
	local counts = 0
	for i = chunk_x - 2,chunk_x + 2 do
		local mx = global.tree_kill_locs[i]
		if mx ~= nil then
			for j = chunk_y - 2,chunk_y + 2 do
				mx[j] = nil
			end
		end
	end

	global.major_retaliation_threshold = global.tree_kill_count + 250
end

script.on_event(defines.events.on_entity_died, function(event)
	global.tree_kill_count = global.tree_kill_count + 1
	if global.tree_kill_count % 50 == 0 and config.retaliation_enabled then
		local surface = game.get_surface(1)
		register_tree_death_loc(event)
		if math.random() < 0.65 then
			check_for_minor_retaliation(surface, event)
		end

		if global.tree_kill_count >= global.major_retaliation_threshold then
			check_for_major_retaliation(surface, event)
		end
	end
end, {{
	filter = "type",
	type = "tree",
}})
