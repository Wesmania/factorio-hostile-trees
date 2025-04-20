local util = require("modules/util")
local area_util = require("modules/area_util")
local tree_events = require("modules/tree_events")
local ents = require("modules/ent_generation")
local poltergeist = require("modules/poltergeist")
local chunks = require("modules/chunks")

-- Avoid find_nearest_enemy_entity_with_owner if possible for retaliation.
-- Large forest fires can trigger a lot of retaliations and this call is SLOW.

local M = {}

script.on_nth_tick(30 * 60, function()
	for _, surface in pairs(game.surfaces) do
		local data = chunks.get_tree_data(storage.chunks, surface)
		data = {
			kill_count = 0,
			robot_deconstruct_count = 0,
			kill_locs = {},
			major_retaliation_threshold = 200,
		}
	end
end)

local function pos_to_coords(pos)
	local chunk_x = math.floor(pos.x / 32)
	local chunk_y = math.floor(pos.x / 32)
	return {chunk_x, chunk_y}
end

local function register_tree_death_loc(event)
	local tree = event.entity
	local tree_data = chunks.get_tree_data(storage.chunks, tree.surface)
	local treepos = tree.position
	local chunk_x, chunk_y = table.unpack(pos_to_coords(treepos))

	local mx = tree_data.kill_locs[chunk_x]
	if mx == nil then
		mx = {}
		tree_data.kill_locs[chunk_x] = mx
	end
	if mx[chunk_y] == nil then
		mx[chunk_y] = 0
	end
	mx[chunk_y] = mx[chunk_y] + 1
end

local function find_forested_area(surface, pos)
	for i = 1,6 do
		local random_pos = {
			x = pos.x - 20 + math.random(1, 40),
			y = pos.y - 20 + math.random(1, 40),
		}
		local random_area = util.box_around(random_pos, 4)
		if area_util.count_trees(surface, random_area, 12) >= 12 then
			return random_pos
		end
	end
	return nil
end

local function find_close_tree_in(surface, pos, range)
	local close_by = util.box_around(pos, range)
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

local function find_close_tree(surface, pos)
	-- Check small radius first
	local ret = find_close_tree_in(surface, pos, 4)
	if ret ~= nil then
		return ret
	end
	return find_close_tree_in(surface, pos, 16)
end

local function get_valid_target(surface, event)
	local cause = event.cause
	if cause == nil or not cause.valid then
		-- Cluster grenades are invalid causes. Wow.
		if event.entity.valid then
			return area_util.find_closest_player(surface, event.entity.position, 100)
		else
			return nil
		end
	end
	if cause.is_entity_with_health then
		return cause
	end

	-- There are multiple reasons for no cause. Poison capsules have a
	-- cause that's the poison cloud. Drive-by shooting reports no cause.
	-- In that case, just find the closest cached player. Shouldn't be too
	-- expensive.
	return area_util.find_closest_player(surface, cause.position, 100)
end

local function check_for_minor_retaliation(surface, event)
	local tree = event.entity
	local treepos = tree.position

	local enemy = get_valid_target(surface, event)
	local edist2 = 0

	if enemy ~= nil then
		edist2 = util.dist2(enemy.position, treepos)
	end

	local rand = math.random()
	if rand < 0.3 then
		local maybe_enemy = enemy
		if enemy == nil or edist2 > 1600 then
			maybe_enemy = false
		end
		tree_events.spawn_biters(surface, treepos, math.random(1, 2), "retaliation", maybe_enemy)
	elseif rand < 0.35 and enemy and poltergeist.can_introduce() then
		poltergeist.throw_poltergeist(surface, treepos, enemy.position, math.random() * 4 + 7)
	elseif rand < 0.75 then
		if enemy ~= nil and edist2 < 1024 then
			local projectiles = tree_events.default_random_projectiles()
			for i = 1,math.random(1, 2) do
				local random_loc = util.random_offset(treepos, 2)
				tree_events.spit_at(surface, random_loc, enemy, projectiles)
			end
		end
	elseif rand < 0.85 then
		if enemy ~= nil and edist2 < 2500 then
			for i = 1,math.random(1, 3) do
				local pos = find_forested_area(surface, treepos)
				if pos == nil then return end
				local tree = area_util.get_random_tree(surface, util.box_around(pos, 4))
				if tree == nil then return end
				tree_events.send_homing_exploding_hopper_projectile(surface, tree.position, enemy)
			end
		end
	else
		tree_events.poison_cloud(surface, treepos)
	end
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
	tree_events.entify_trees_in_cone(surface, point_away, close_tree.position, angle, radius, speed, target)
end

local function check_for_major_retaliation(surface, event)
	local tree = event.entity
	local tree_data = chunks.get_tree_data(storage.chunks, tree.surface)
	local treepos = tree.position
	local chunk_x, chunk_y = table.unpack(pos_to_coords(treepos))

	-- Check neighbouring chunks
	local counts = 0
	for i = chunk_x - 2,chunk_x + 2 do
		local mx = tree_data.kill_locs[i]
		if mx ~= nil then
			for j = chunk_y - 2,chunk_y + 2 do
				if mx[j] ~= nil then
					counts = counts + mx[j]
				end
			end
		end
	end

	if counts < 5 then return end

	-- Clear counts in neighbouring chunks
	for i = chunk_x - 2,chunk_x + 2 do
		local mx = tree_data.kill_locs[i]
		if mx ~= nil then
			for j = chunk_y - 2,chunk_y + 2 do
				mx[j] = nil
			end
		end
	end
	tree_data.major_retaliation_threshold = tree_data.kill_count + 200

	local enemy = get_valid_target(surface, event)
	local edist2 = 0
	if enemy ~= nil then
		edist2 = util.dist2(enemy.position, treepos)
	end

	local rand = math.random()

	if rand < 0.2 and ents.can_make_ents() then
		if enemy == nil or edist2 > 3600 then
			enemy = false
		end
		entify_trees_in_cone(surface,
		                     treepos,
		                     48, -- ~48 degrees each direction
		                     8,
		                     4,
		                     enemy)
		return
        end

	if rand < 1.1 and enemy ~= nil and poltergeist.can_introduce() then
		poltergeist.throw_a_bunch_of_fast_poltergeists(surface, enemy, treepos, math.random(7, 12), 10, 25)
		return
	end

        local maybe_nearby_player = nil
        if enemy ~= nil and enemy.name == "character" and edist2 < 3600 then
		maybe_nearby_player = enemy
        end

	-- Chance for forest to just focus on player
	if rand < 0.55 and maybe_nearby_player ~= nil then
		tree_events.focus_on_player(maybe_nearby_player.unit_number, 15)
	end

	local spawn_pos = find_forested_area(surface, treepos)
	local biter_count
	if spawn_pos == nil then
		spawn_pos = tree.position
		biter_count = math.random(10, 15)
	else
		biter_count = math.random(25, 40)
	end
	if enemy == nil or edist2 > 3600 then
		enemy = false
	end
	storage.tree_stories[#storage.tree_stories + 1] = tree_events.spawn_biters_over_time(surface, spawn_pos, biter_count, "retaliation", enemy)
end

function M.tree_died(event)
	local tree = event.entity
	local tree_data = chunks.get_tree_data(storage.chunks, tree.surface)

	tree_data.kill_count = tree_data.kill_count + 1
	if tree_data.kill_count% 40 == 0 and storage.config.retaliation_enabled then
		local surface = tree.surface
		register_tree_death_loc(event)
		if math.random() < 0.65 then
			check_for_minor_retaliation(surface, event)
		end

		if tree_data.kill_count >= tree_data.major_retaliation_threshold then
			check_for_major_retaliation(surface, event)
		end
	end
end

function M.tree_bot_deconstructed(event)
	local tree = event.entity
	local tree_data = chunks.get_tree_data(storage.chunks, tree.surface)

	tree_data.robot_deconstruct_count = tree_data.robot_deconstruct_count + 1
	if tree_data.robot_deconstruct_count % 20 == 0 and storage.config.retaliation_enabled then
		if math.random() < 0.05 then	-- TODO balance. Maybe too rare?
			tree_events.turn_construction_bot_hostile(tree.surface, event.robot)
		end
	end
end

return M
