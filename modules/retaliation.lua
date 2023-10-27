local util = require("modules/util")
local tree_events = require("modules/tree_events")

script.on_nth_tick(30 * 60, function()
	global.tree_kill_count = 0
	global.tree_kill_locs = {}
	global.major_retaliation_threshold = 200	-- FIXME balance
end)

local function pos_to_coords(pos)
	local chunk_x = math.floor(pos.x / 32)
	local chunk_y = math.floor(pos.x / 32)
	return {chunk_x, chunk_y}
end

local function register_tree_death_loc(event)
	local tree = event.entity
	local treepos = util.position(tree)
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

local function check_for_major_retaliation(surface, event)
	local tree = event.entity
	local treepos = util.position(tree)
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
	global.tree_stories[#global.tree_stories + 1] = tree_events.spawn_biters_over_time(surface, util.position(tree), math.random(30, 50), "retaliation")

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

	global.major_retaliation_threshold = global.tree_kill_count + global.major_retaliation_threshold
end

script.on_event(defines.events.on_entity_died, function(event)
	global.tree_kill_count = global.tree_kill_count + 1
	if global.tree_kill_count % 50 == 0 then
		register_tree_death_loc(event)
		
		if global.tree_kill_count >= global.major_retaliation_threshold then
			local surface = game.get_surface(1)
			check_for_major_retaliation(surface, event)
		end
	end
end, {{
	filter = "type",
	type = "tree",
}})
