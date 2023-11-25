local util = require("modules/util")
local area_util = require("modules/area_util")
local tree_events = require("modules/tree_events")

script.on_nth_tick(30 * 60, function()
	global.tree_kill_count = 0
	global.tree_kill_locs = {}
	global.major_retaliation_threshold = 200	-- FIXME balance
	global.robot_tree_deconstruct_count = 0
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

local function find_tree_in_forested_area(surface, pos)
	for i = 1,6 do
		local random_area = util.box_around({
			x = pos.x - 24 + math.random(1, 48),
			y = pos.y - 24 + math.random(1, 48),
		}, 8)
		if area_util.count_trees(surface, random_area, 20) >= 20 then
			return area_util.get_random_tree(surface, random_area)
		end
	end
	return nil
end

local function find_close_tree(surface, pos)
	local close_by = util.box_around(pos, 16)
	local trees = area_util.get_trees(surface, close_by)
	if #trees == 0 then return nil end
	if #trees < 4 then return trees[math.random(1, #trees)] end
	local closest_trees = {
		{ 10000, nil },
		{ 10000, nil },
		{ 10000, nil },
		{ 10000, nil },
	}
	for _, tree in ipairs(trees) do
		local dist2 = util.dist2(pos, tree.position)
		for i = 1,4 do
			if closest_trees[i][1] > dist2 then
				closest_trees[i] = { dist2, tree }
				goto placed
			end
		end
		::placed::
	end
	return closest_trees[math.random(1, 4)][2]
end

local function entify_trees_in_cone(surface, pos, angle, radius, speed, target)
	local close_tree = find_close_tree(surface, pos)
	if close_tree == nil then return end

	local vec_to_tree = {
		x = close_tree.position.x - pos.x,
		y = close_tree.position.y - pos.y,
	}

	-- If we're really close, move the point further away.
	local len2 = math.sqrt(util.len2(vec_to_tree))
	if len2 == 0 then return end
	local multiplier = 1
	if len2 < radius * 0.75 then
		multiplier = radius * 0.75 / len2
	end

	local point_away = {
		x = pos.x - (vec_to_tree.x * multiplier),
		y = pos.y - (vec_to_tree.y * multiplier),
	}

	local vec_towards = {
		x = close_tree.position.x - point_away.x,
		y = close_tree.position.y - point_away.y,
	}

	local cone_base = math.sqrt(vec_towards.x * vec_towards.x + vec_towards.y * vec_towards.y)
	local cone_radius = cone_base + radius
	local cone_radius2 = cone_radius * cone_radius

	local vec_left = util.rotate(vec_towards, angle)
	local vec_right = util.rotate(vec_towards, -angle)

	if false then
		local dl = function(o)
			rendering.draw_line{
				time_to_live = 600,
				surface = surface,
				color = o.color,
				width = 10,
				from = o.from,
				to = o.to,
			}
		end
		dl{
			color = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},
			from = point_away,
			to = close_tree.position,
		}
		dl{
			color = {r = 1.0, g = 0.0, b = 0.0, a = 1.0},
			from = point_away,
			to = {
				x = point_away.x + (vec_left.x * cone_radius / cone_base),
				y = point_away.y + (vec_left.y * cone_radius / cone_base),
			}
		}
		dl{
			color = {r = 1.0, g = 0.0, b = 0.0, a = 1.0},
			from = point_away,
			to = {
				x = point_away.x + (vec_right.x * cone_radius / cone_base),
				y = point_away.y + (vec_right.y * cone_radius / cone_base),
			}
		}
	end

	local trees_around_close_tree = area_util.get_trees(surface, util.box_around(close_tree.position, radius * 1.5))

	local trees_in_cone = {}
	for _, tree in ipairs(trees_around_close_tree) do
		local tree_vec = {
			x = tree.position.x - point_away.x,
			y = tree.position.y - point_away.y,
		}
		if
			util.len2(tree_vec) <= cone_radius2
			and util.clockwise(vec_left, tree_vec)
			and util.clockwise(tree_vec, vec_right)
		then
			local tree_dist = math.sqrt(util.len2(tree_vec))
			local tree_frame
			if tree_dist < cone_base then
				tree_frame = 0
			else
				tree_frame = math.floor((tree_dist - cone_base) * 60 / speed)
			end
			trees_in_cone[#trees_in_cone + 1] = {
				tree,
				tree_frame
			}
		end
	end

	table.sort(trees_in_cone, function(a, b) return a[2] < b[2] end)

	if target == nil then
		target = surface.find_nearest_enemy_entity_with_owner{position=close_tree.position, max_distance=32, force="enemy"}
	end
	tree_events.add_ent_war_story(surface, trees_in_cone, target)
end

local function check_for_minor_retaliation(surface, event)
	local tree = event.entity
	local treepos = tree.position

	local enemy = surface.find_nearest_enemy_entity_with_owner{position=treepos, max_distance=32, force="enemy"}

	local rand = math.random()
	if rand < 0.3 then
		tree_events.spawn_biters(surface, treepos, math.random(1, 2), "retaliation")
	elseif rand < 0.75 and enemy ~= nil then
		local projectiles = tree_events.default_random_projectiles()
		for i = 1,math.random(1, 2) do
			local random_loc = util.random_offset(treepos, 2)
			tree_events.spit_at(surface, random_loc, enemy, projectiles)
		end
	elseif rand < 0.85 and enemy ~= nil then
		for i = 1,math.random(1, 3) do
			local tree = find_tree_in_forested_area(surface, treepos)
			if tree ~= nil then
				tree_events.send_homing_exploding_hopper_projectile(tree.position, enemy)
			end
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

	local rand = math.random()

	local maybe_nearby_player = nil
	local maybe_character = event.cause
	if maybe_character ~= nil and maybe_character.name == "character" then
		maybe_nearby_player = maybe_character
	end

	if rand < 0.2 or true then
		local enemy = surface.find_nearest_enemy_entity_with_owner{position=treepos, max_distance=32, force="enemy"}
		if enemy == nil then
			enemy = maybe_nearby_player
		end
		entify_trees_in_cone(surface,
		                     treepos,
				     0.8, -- ~48 degrees
				     8,
				     4,
				     enemy)
		return
        end

	-- Chance for forest to just focus on player
	if rand < 0.55 and maybe_nearby_player ~= nil then
		tree_events.focus_on_player(maybe_nearby_player.unit_number, 15)
	end

	local spawn_tree = find_tree_in_forested_area(surface, treepos)

	local biter_count
	if spawn_tree == nil then
		spawn_tree = tree
		biter_count = math.random(10, 15)
	else
		biter_count = math.random(25, 40)
	end

	global.tree_stories[#global.tree_stories + 1] = tree_events.spawn_biters_over_time(surface, spawn_tree.position, biter_count, "retaliation")

	-- Clear counts in neighbouring chunks
	for i = chunk_x - 2,chunk_x + 2 do
		local mx = global.tree_kill_locs[i]
		if mx ~= nil then
			for j = chunk_y - 2,chunk_y + 2 do
				mx[j] = nil
			end
		end
	end

	global.major_retaliation_threshold = global.tree_kill_count + 200
end

script.on_event(defines.events.on_entity_died, function(event)
	global.tree_kill_count = global.tree_kill_count + 1
	if global.tree_kill_count % 40 == 0 and global.config.retaliation_enabled then
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

script.on_event(defines.events.on_robot_mined_entity, function(event)
	global.robot_tree_deconstruct_count = global.robot_tree_deconstruct_count + 1
	if global.robot_tree_deconstruct_count % 20 == 0 and global.config.retaliation_enabled then
		if math.random() < 0.05 then	-- TODO balance. Maybe too rare?
			tree_events.turn_construction_bot_hostile(game.get_surface(1), event.robot)
		end
	end
end, {{
filter = "type",
type = "tree",
}})
