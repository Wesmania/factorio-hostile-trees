local util = require("modules/util")
local area_util = require("modules/area_util")
local tree_events = require("modules/tree_events")

local M = {}

local function flicker_light(s)
	s.until_next = s.until_next - 1
	if s.until_next == 0 then
		s.player.disable_flashlight()
		return true
	end
	if s.player.is_flashlight_enabled() then
		s.player.disable_flashlight()
	else
		s.player.enable_flashlight()
	end
	return false
end

local function pause(s)
	s.until_next = s.until_next - 1
	return s.until_next <= 0
end

local function fire_ring(s)
	s.until_next = s.until_next - 1
	if s.until_next > 0 then return false end

	if s.i > 16 then
		return true
	end

	local ppos = s.player.position
	local search_pos = {
		x = ppos.x + math.sin(math.pi / 8 * s.tree_circle[s.i]) * s.fire_radius,
		y = ppos.y + math.cos(math.pi / 8 * s.tree_circle[s.i]) * s.fire_radius,
	}
	local box = util.box_around(search_pos, 2)
	local tree = area_util.get_tree(s.surface, box)
	tree_events.set_tree_on_fire(s.surface, tree)
	s.i = s.i + 1
	s.until_next = math.random(s.until_low, s.until_high)
	return false
end

local SpookyStoryPrototype = {
	stages = {
		-- Args: until_next
		flicker_light = function(s)
			if not flicker_light(s) then return end
			s.next_stage(s)
		end,
		-- Args: until_next
		pause = function(s)
			if not pause(s) then return end
			s.next_stage(s)
		end,
		-- Args s.fire_radius, s.until_low, s.until_high, s.tree_count
		fire_ring = function(s)
			if s.tree_circle == nil then
				s.i = 1
				s.tree_circle = util.shuffle(s.tree_count)
			end
			if not fire_ring(s) then return end
			s.tree_circle = nil
			s.next_stage(s)
		end,
		unflicker_light = function(s)
			s.player.enable_flashlight()
			s.next_stage(s)
		end,
		biter_attack = function(s)
			tree_events.spawn_biters(s.surface, s.treepos, s.biter_count, s.biter_rate_table)
			s.next_stage(s)
		end,
		spit = function(s)
			tree_events.spitter_projectile(s.surface, s.treepos, s.player)
			s.next_stage(s)
		end,
		spit_fire = function(s)
			tree_events.fire_stream(s.surface, s.treepos, s.player)
			s.next_stage(s)
		end,
		_do_coroutine = function(s)
			if not s._coroutine.run(s._coroutine) then
				s._coroutine = nil
				s.next_stage(s)
			end
		end,
		fake_biters = function(s)
			if s._coroutine == nil then
				s._coroutine = tree_events.fake_biters(s.surface, s.player, s.count, s.wait_low, s.wait_high)
			else
				s.stages._do_coroutine(s)
			end
		end,
		biter_onslaught = function(s)
			if s._coroutine == nil then
				s._coroutine = tree_events.spawn_biters_over_time(s.surface, s.treepos, s.count, s.biter_rate_table)
			else
				s.stages._do_coroutine(s)
			end
		end,

		-- FIXME duplication with building spit assault
		-- Args s.duration, s.until_low, s.until_high, s.projectiles
		-- Optional args: s.biter_chance, s.biter_low, s.biter_high, s.biter_rate_table
		spit_assault = function(s)
			if s.total_ticks == nil then
				s.total_ticks = 0
				s.next_event = 0
			end

			s.total_ticks = s.total_ticks + 1
			if s.total_ticks >= s.duration then
				s.total_ticks = nil
				s.next_event = nil
				s.next_stage(s)
				return
			end

			if s.next_event > 0 then
				s.next_event = s.next_event - 1
				return
			end
			s.next_event = math.random(s.until_low, s.until_high)

			local ppos = s.player.position
			local box = util.box_around(ppos, 6)
			local tree = area_util.get_random_tree(s.surface, box)
			if tree == nil then return end

			if s.biter_chance ~= false and math.random() < s.biter_chance then
				tree_events.spawn_biters(s.surface, tree.position, math.random(s.biter_low, s.biter_high), s.biter_rate_table)
			else
				tree_events.spit_at(s.surface, tree.position, s.player, s.projectiles)
			end
		end,

		poison_cloud = function(s)
			tree_events.poison_cloud(s.surface, s.treepos)
			s.next_stage(s)
			return
		end
	},

	next_stage = function(s)
		s.stage_idx = s.stage_idx + 1
		local stage = s.stage_list[s.stage_idx]
		if stage == nil then return end
		for n, v in pairs(stage[2]) do
			s[n] = v
		end
	end,

	finish = function(s)
		s.stage_idx = nil
	end,

	run = function(s)
		local stage = s.stage_list[s.stage_idx]
		if stage == nil then return false end
		if not s.player.valid or not s.surface.valid then return false end
		s.stages[stage[1]](s)
		return true
	end,
}

local function surround_with_flicker(sl)
	-- First, flicker + pause.
	table.insert(sl, 1, { "pause", {until_next = math.random(60, 90)} })
	table.insert(sl, 1, { "flicker_light", {until_next = math.random(45, 75)} })

	-- Last, pause + unflicker.
	sl[#sl + 1] = { "pause", {until_next = math.random(120, 180)} }
	sl[#sl + 1] = { "unflicker_light", {}}
end

local function complex_random_assault(sl, tree, add_flicker, spook_player, duration, biter_assault)
	if spook_player then
		-- Spook and warn the player.
		sl[#sl + 1] = { "pause", {until_next = math.random(60, 90)} }
		sl[#sl + 1] = { "fire_ring", {fire_radius = 6 + math.random() * 4, until_low = 5, until_high = 9, tree_count = 16}}
		sl[#sl + 1] = { "pause", {until_next = math.random(60, 90)}}
	end

	local rand = math.random()
	if biter_assault and rand < 0.3
	then
		local count = nil
		if is_in_forest then
			count = math.random(20, 40)
		else
			count = math.random(10, 25)
		end
		sl[#sl + 1] = { "biter_onslaught", {treepos = tree.position, count = count, biter_rate_table = "retaliation"}}
	else
		local projectiles = tree_events.default_random_projectiles()
		local biter_stats = {}

		if rand < 0.3 then
			biter_stats.biter_chance = false
		else
			biter_stats.biter_chance = 0.15 + math.random() * 0.1
			biter_stats.biter_low = math.random(1, 3)
			biter_stats.biter_high = biter_stats.biter_low + math.random(1, 3)
			if math.random() < 0.3 then
				biter_stats.biter_rate_table = "default"
			else
				biter_stats.biter_rate_table = "retaliation"
			end
		end

		sl[#sl + 1] = { "spit_assault", {
			duration = duration,
			until_low = 20,
			until_high = 40,
			projectiles = projectiles,
			biter_chance = biter_stats.biter_chance,
			biter_low = biter_stats.biter_low,
			biter_high = biter_stats.biter_high,
			biter_rate_table = biter_stats.biter_rate_table,
		}}
	end

	if add_flicker then
		surround_with_flicker(sl)
	end
end

M.spooky_story = function(player_info, surface)
	local player = player_info.player

	local ppos = player.position
	local box = util.box_around(ppos, 8)
	local tree_count = area_util.count_trees(surface, box, 40)

	if tree_count == 0 then
		-- Not near trees. Don't do a story, chance to reduce threat.
		if player_info.tree_threat > 0 and math.random() < 0.2 then
			player_info.tree_threat = player_info.tree_threat - 1
		end
		return nil
	end

	local s = {}
	setmetatable(s, {__index = SpookyStoryPrototype})
	s.stage_list = {}
	local sl = s.stage_list

	local tree = area_util.get_random_tree(surface, box)	-- won't be nil
	local is_in_forest = tree_count >= 40
	local is_near_a_few_trees = tree_count >= 10
	local threat = player_info.tree_threat
	local is_night = surface.darkness >= 0.7

	-- Eternal TODO: add more events.

	if threat >= 6 and is_near_a_few_trees then
		-- Large event. Happens about a fifth of the time a mid-sized event does.
		if math.random() < 0.8 then
			player_info.tree_threat = player_info.tree_threat + 1
		else
			player_info.tree_threat = threat - 6

			local add_flicker = is_night and math.random() < 0.25
			local spook_player = is_in_forest and add_flicker and math.random() < 0.6
			complex_random_assault(sl, tree, add_flicker, spook_player, math.random(420, 720), true)

			goto finish
		end
	end

	if threat >= 4 then
		-- Mid-sized event.
		local rand = math.random()
		if rand < 0.5 then
			player_info.tree_threat = player_info.tree_threat + 1
		else
			player_info.tree_threat = threat - 4

			local add_flicker = is_night and math.random() < 0.25
			local rand = math.random()
			if rand < 0.85 then
				complex_random_assault(sl, tree, add_flicker, spook_player, math.random(180, 360))
			elseif rand < 0.9 then
				sl[#sl + 1] = { "spit_assault", {
					duration = math.random(480, 660),
					until_low = 120,
					until_high = 240,
					biter_chance = false,
					projectiles = { "poison_cloud" },
				}}
			else
				sl[#sl + 1] = { "pause", {until_next = 20}}
				sl[#sl + 1] = { "fake_biters", {count = 20, wait_low = 10, wait_high = 25}}
				if add_flicker then
					surround_with_flicker(sl)
				end
			end

			goto finish
		end
	end

	-- Small events.
	if is_in_forest then
		player_info.tree_threat = player_info.tree_threat + 1

		local rand = math.random()
		if rand < 0.3 then
			local biter_rate_table = "default"
			if math.random() < 0.15 then
				biter_rate_table = "retaliation"
			end
			sl[#sl + 1] = { "biter_attack", {
				treepos = tree.position,
				biter_count = math.random(2, 4),
				biter_rate_table = biter_rate_table,
			}}
		elseif rand < 0.45 then
			sl[#sl + 1] = { "spit_fire", {treepos = tree.position}}
		elseif rand < 0.5 then
			sl[#sl + 1] = { "poison_cloud", {treepos = tree.position}}
		else
			sl[#sl + 1] = { "spit", {treepos = tree.position}}
		end
	elseif is_near_a_few_trees then
		if math.random() < 0.3 then
			player_info.tree_threat = player_info.tree_threat + 1
		end
		local rand = math.random()
		if rand < 0.15 then
			sl[#sl + 1] = { "biter_attack", {
				treepos = tree.position,
				biter_count = math.random(1, 2),
				biter_rate_table = "default",
			}}
		elseif rand < 0.2 then
			sl[#sl + 1] = { "spit_fire", {treepos = tree.position}}
		elseif rand < 0.65 then
			sl[#sl + 1] = { "spit", {treepos = tree.position}}
		end
	else
		local rand = math.random()
		if rand < 0.05 then
			sl[#sl + 1] = { "spit_fire", {treepos = tree.position}}
		elseif rand < 0.20 then
			sl[#sl + 1] = { "spit", {treepos = tree.position}}
		end
	end

	::finish::

	s.stage_idx = 0
	s.player = player
	s.surface = surface
	s.next_stage(s)
	return s
end

return M
