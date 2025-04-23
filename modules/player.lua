local util = require("modules/util")
local area_util = require("modules/area_util")
local tree_events = require("modules/tree_events")
local ents = require("modules/ent_generation")
local poltergeist = require("modules/poltergeist")

local M = {}

local function coro_next_stage(s)
	s.stage_idx = s.stage_idx + 1
	local stage = s.stage_list[s.stage_idx]
	if stage == nil then return end
	for n, v in pairs(stage[2]) do
		s[n] = v
	end
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

local stages = {
	-- Args: until_next
	flicker_light = function(s)
		s.until_next = s.until_next - 1
		if s.until_next <= 0 then
			s.player.disable_flashlight()
			coro_next_stage(s)
			return
		end
		if s.player.is_flashlight_enabled() then
			s.player.disable_flashlight()
		else
			s.player.enable_flashlight()
		end
	end,
	-- Args: until_next
	pause = function(s)
		s.until_next = s.until_next - 1
		if s.until_next <= 0 then coro_next_stage(s) end
	end,
	-- Args s.fire_radius, s.until_low, s.until_high, s.tree_count
	fire_ring = function(s)
		if s.tree_circle == nil then
			s.i = 1
			s.tree_circle = util.shuffle(s.tree_count)
		end
		if not fire_ring(s) then return end
		s.tree_circle = nil
		coro_next_stage(s)
	end,
	unflicker_light = function(s)
		s.player.enable_flashlight()
		coro_next_stage(s)
	end,
	biter_attack = function(s)
		tree_events.spawn_biters(s.surface, s.treepos, s.biter_count, s.biter_rate_table, s.target)
		coro_next_stage(s)
	end,
	spit = function(s)
		tree_events.spitter_projectile(s.surface, s.treepos, s.player)
		coro_next_stage(s)
	end,
	spit_fire = function(s)
		tree_events.fire_stream(s.surface, s.treepos, s.player)
		coro_next_stage(s)
	end,
	tree_event = function(s)
		if not tree_events.run_coro(s._coroutine) then
			s._coroutine = nil
			coro_next_stage(s)
		end
	end,
	turn_tree_into_ent = function(s)
		tree_events.turn_tree_into_ent(s.surface, s.tree)
		coro_next_stage(s)
	end,
	spawn_poltergeist = function(s)
		if s.target.valid and poltergeist.can_introduce() then
			poltergeist.throw_poltergeist(s.surface, s.treepos, s.target.position, math.random() * 2 + 4)
		end
		coro_next_stage(s)
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
			coro_next_stage(s)
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
			tree_events.spawn_biters(s.surface, tree.position, math.random(s.biter_low, s.biter_high), s.biter_rate_table, s.target)
		else
			tree_events.spit_at(s.surface, tree.position, s.player, s.projectiles)
		end
	end,

	exploding_hopper_projectile = function(s)
		if s.source.valid and s.target.valid and s.surface.valid then
			tree_events.send_homing_exploding_hopper_projectile(s.surface, s.source, s.target)
		end
		coro_next_stage(s)
		return
	end

	poison_cloud = function(s)
		tree_events.poison_cloud(s.surface, s.treepos)
		coro_next_stage(s)
		return
	end
}

function M.event_spooky_story(s)
	local stage = s.stage_list[s.stage_idx]
	if stage == nil then return false end
	if not s.player.valid or not s.surface.valid then return false end
	stages[stage[1]](s)
	return true
end

local function surround_with_flicker(sl)
	-- First, flicker + pause.
	table.insert(sl, 1, { "pause", {until_next = math.random(60, 90)} })
	table.insert(sl, 1, { "flicker_light", {until_next = math.random(45, 75)} })

	-- Last, pause + unflicker.
	sl[#sl + 1] = { "pause", {until_next = math.random(120, 180)} }
	sl[#sl + 1] = { "unflicker_light", {}}
end

local function put_in_random_stage(sl, stage)
	table.insert(sl, math.random(1, #sl), stage)
end

local function complex_random_assault(player, sl, tree, add_flicker, spook_player, is_in_forest, duration, biter_assault)
	local surface = player.surface

	if spook_player then
		-- Spook and warn the player.
		sl[#sl + 1] = { "pause", {until_next = math.random(60, 90)} }
		sl[#sl + 1] = { "fire_ring", {fire_radius = 6 + math.random() * 4, until_low = 5, until_high = 9, tree_count = 16}}
		sl[#sl + 1] = { "pause", {until_next = math.random(60, 90)}}
	end

	local rand = math.random()
	if biter_assault and rand < 0.6 then
		local count
		if is_in_forest then
			count = math.random(20, 40)
		else
			count = math.random(10, 25)
		end
		sl[#sl + 1] = { "tree_event", {
			_coroutine = tree_events.spawn_biters_over_time(surface, tree.position, count, "retaliation", player)
		}}
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
			target = player,
		}}
	end

	if add_flicker then
		surround_with_flicker(sl)
	end

	if math.random() < 0.05 then
		put_in_random_stage(sl, { "spawn_poltergeist", {
			target = player,
			treepos = tree.position,
		}})
	end
end

function M.spooky_story(player_info, player_is_focused_on)
	local player = player_info.player
	local surface = player.surface

	if util.skip_planet(surface) then
		return
	end

	local ppos = player.position
	local box = util.box_around(ppos, 8)
	local tree_count = area_util.count_trees(surface, box, 40)

	if tree_count == 0 then
		-- Not near trees. Don't do a story, chance to reduce threat.
		if math.random() < 0.3 and not player_is_focused_on then
			if player_info.tree_threat > 0 then
				player_info.tree_threat = player_info.tree_threat - 1
			elseif player_info.big_tree_threat > 0 then
				player_info.big_tree_threat = player_info.big_tree_threat - 1
			end
		end
		return nil
	end

	local s = {}
	s.stage_list = {}
	local sl = s.stage_list

	local tree = area_util.get_random_tree(surface, box)	-- won't be nil
	local is_in_forest = tree_count >= 30
	local is_near_a_few_trees = tree_count >= 10
	local threat = player_info.tree_threat
	local is_night = surface.darkness >= 0.7

	-- Eternal TODO: add more events.
	if threat >= 5 and is_near_a_few_trees then
		-- Mid-sized event.
		local rand = math.random()

		-- Chance to immediately skip to large event if hatred is high enough.
		if threat >= 7 and math.random() < storage.hatred * 0.8 then
			goto large_event
		end

		-- If we make a mid event, make a major event more likely in the future.
		if rand > 0.8 - (player_info.big_tree_threat * 0.15) then
			if not player_is_focused_on then
				player_info.tree_threat = player_info.tree_threat + 1
			end
		else
			player_info.tree_threat = threat - 5
			if not player_is_focused_on then
				player_info.big_tree_threat = player_info.big_tree_threat + 1
			end

			local add_flicker = is_night and math.random() < 0.25
			local rand2 = math.random()
			if rand2 < 0.15 then
				sl[#sl + 1] = { "tree_event", {
					_coroutine = tree_events.entify_trees_in_cone_coro(surface, ppos, tree.position,
											   15, 2, 3, player)
				}}
			elseif rand2 < 0.95 then
				complex_random_assault(player, sl, tree, add_flicker, false, is_in_forest, math.random(180, 360))
			else
				sl[#sl + 1] = { "pause", {until_next = 20}}
				sl[#sl + 1] = { "tree_event", {
					_coroutine = tree_events.fake_biters(surface, player, 20, 10, 25)
				}}
				if add_flicker then
					surround_with_flicker(sl)
				end
			end
		end

		goto finish
	end

	::large_event::

	if threat >= 7 and is_near_a_few_trees then
		-- Large event. Happens about a fifth of the time a mid-sized event does.
		if not player_is_focused_on then
			player_info.tree_threat = player_info.tree_threat + 1
		end
		player_info.tree_threat = threat - 7
		player_info.big_tree_threat = 0

		local add_flicker = is_night and math.random() < 0.25
		local spook_player = is_in_forest and add_flicker and math.random() < 0.6
		local rand = math.random()
		if rand < 0.7 then
			complex_random_assault(player, sl, tree, add_flicker, spook_player, is_in_forest, math.random(420, 720), true)
		else
			sl[#sl + 1] = { "spit_assault", {
				duration = math.random(480, 660),
				until_low = 120,
				until_high = 240,
				biter_chance = false,
				projectiles = { "poison_cloud" },
				target = player,
			}}
		end
		goto finish
	end

	-- Small events.
	if is_in_forest then
		if not player_is_focused_on then
			player_info.tree_threat = player_info.tree_threat + 1
			if storage.hatred > 1 then
				local extra_max_threat = math.floor(math.sqrt(storage.hatred - 1))
				local extra_threat = math.random(1, extra_max_threat)
				player_info.tree_threat = player_info.tree_threat + extra_threat
			end
		end

		local rand = math.random()
		if rand < 0.05 then
			sl[#sl + 1] = { "spawn_poltergeist", {
				treepos = tree.position,
				target = player,
			}}
		elseif rand < 0.3 then
			local biter_rate_table = "default"
			if math.random() < 0.15 then
				biter_rate_table = "retaliation"
			end
			sl[#sl + 1] = { "biter_attack", {
				treepos = tree.position,
				biter_count = math.random(2, 4),
				biter_rate_table = biter_rate_table,
				target = player,
			}}
		elseif rand < 0.45 then
			sl[#sl + 1] = { "spit_fire", {treepos = tree.position}}
		elseif rand < 0.58 then
			sl[#sl + 1] = { "poison_cloud", {treepos = tree.position}}
		elseif rand < 0.65 and ents.can_make_ents() then
			sl[#sl + 1] = { "turn_tree_into_ent", {tree = tree}}
		else
			sl[#sl + 1] = { "spit", {treepos = tree.position}}
		end
	elseif is_near_a_few_trees then
		if math.random() < 0.3 and not player_is_focused_on then
			player_info.tree_threat = player_info.tree_threat + 1
			if storage.hatred > 1 then
				local extra_max_threat = math.floor(math.sqrt(storage.hatred - 1) / 2)
				local extra_threat = math.random(1, extra_max_threat)
				player_info.tree_threat = player_info.tree_threat + extra_threat
			end
		end
		local rand = math.random()

		if storage.hatred >= 10 and rand < storage.hatred / 3 then
			sl[#sl + 1] = { "exploding_hopper_projectile", {
				source = tree,
				target = player,
			}}
			goto finish
		end

		rand = math.random()

		if rand < 0.05 then
			sl[#sl + 1] = { "spawn_poltergeist", {
				treepos = tree.position,
				target = player,
			}}
		elseif rand < 0.15 then
			sl[#sl + 1] = { "biter_attack", {
				treepos = tree.position,
				biter_count = math.random(1, 2),
				biter_rate_table = "default",
				target = player,
			}}
		elseif rand < 0.2 then
			sl[#sl + 1] = { "spit_fire", {treepos = tree.position}}
		elseif rand < 0.3 and ents.can_make_ents() then
			sl[#sl + 1] = { "turn_tree_into_ent", {tree = tree}}
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
	s.event_name = "event_spooky_story"
	s.player = player
	s.surface = surface
	coro_next_stage(s)
	return s
end

function M.run_coro(s)
	return M[s.event_name](s)
end

return M
