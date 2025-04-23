local util = require("modules/util")
local area_util = require("modules/area_util")
local ents = require("modules/ent_generation")
local evolution = require("modules/cache_evolution")

local M = {}

local function deal_damage_to_player_entities(surface, position, radius, amount)
	for _, force in pairs(storage.game_forces) do
		for _, item in ipairs(surface.find_entities_filtered{position = position, radius = radius, force = force}) do
			if item.is_entity_with_health then
				item.damage(amount, "enemy", "explosion")
			end
		end
	end
end

-- FIXME move
function M.set_tree_on_fire(surface, tree)
	if tree == nil then return end
	local at = tree.position
	tree.destroy()
	surface.create_entity{
		name = 'fire-flame-on-tree',
		position = at,
	}
end

function M.spread_trees_towards_buildings(surface, tree, building)
	if tree == nil then return end
	if building == nil then return end
	local treepos = tree.position
	local buildingpos = building.position
	-- Spread 3 to 5 trees two thirds of the way between the building and the tree.
	treepos.x = (treepos.x * 2 + buildingpos.x) / 3
	treepos.y = (treepos.y * 2 + buildingpos.y) / 3
	for i = 1,math.random(3, 5) do
		buildingpos.x = treepos.x + (math.random() * 3)
		buildingpos.y = treepos.y + (math.random() * 3)
		surface.create_entity{name = tree.name, position = buildingpos}
	end
end

local function make_tree_spawner_projectile(surface, source, target, tree_name, generation)
	local s = surface.create_entity{
		name = 'tree-spawner-projectile',
		position = source,
		source = source,
		target = target,
	}
	if s ~= nil then
		local rid = script.register_on_object_destroyed(s)
		storage.entity_destroyed_script_events[rid] = {
			action = "on_spawning_spit_landed",
			surface = surface,
			tree_name = tree_name,
			generation = generation,
			source = source,
			target = target,
		}
	end
end

function M.spit_trees_towards_buildings(surface, tree, building)
	if tree == nil then return end
	if building == nil then return end
	local treepos = tree.position
	local buildingpos = building.position

	local dx = (buildingpos.x - treepos.x)
	local dy = (buildingpos.y - treepos.y)

	local dist = math.sqrt(dx * dx + dy * dy)

	if dist < 0.1 then return end

	if dist < 8 then
		local mult = 8 / dist * (1 + math.random() * 0.3) - 1
		buildingpos.x = buildingpos.x + dx * mult
		buildingpos.y = buildingpos.y + dy * mult
	end

	make_tree_spawner_projectile(surface, treepos, buildingpos, tree.name, 1)
end

-- I tried to do it purely with data, couldn't. Can't change projectile source
-- and keep orientation at the same time. Hopefully performance will be okay.
function M.on_spawning_spit_landed(event)
	local source = event.source
	local target = event.target
	local tree_name = event.tree_name
	local generation = event.generation
	local surface = event.surface

	if not surface.valid then
		return
	end
	if area_util.is_water(surface, target) then
		return
	end

	for i = 1,math.random(1, 3) do
		local pos = {
			x = target.x - 2.0 + math.random() * 4.0,
			y = target.y - 2.0 + math.random() * 4.0,
		}
		if not area_util.is_water(surface, pos) then
			surface.create_entity{
				name = tree_name,
				position = pos,
			}
		end
	end

	local rand = math.random()
	local ts
	local spread
	if generation == 1 then
		spread = 15
		if rand < 0.75 then
			ts = { 1 }
		elseif rand < 0.90 then
			ts = {}
		else
			ts = { 2 }
		end
	elseif generation == 2 then
		spread = 60
		if rand < 0.25 then
			ts = { 3 }
		elseif rand < 0.65 then
			ts = { 3, 3 }
		elseif rand < 0.9 then
			ts = { 3, 3, 3}
		else
			ts = {2, 2}
		end
	elseif generation == 3 then
		spread = 20
		if rand < 0.55 then
			ts = { }
		elseif rand < 0.8 then
			ts = { 3 }
		else
			ts = {3, 3}
		end
	end

	for _, gen in pairs(ts) do
		local dp = {
			x = target.x - source.x,
			y = target.y - source.y,
		}

		local rot = math.random(-spread, spread) / 60
		local dp = util.rotate(dp, rot)

		local dist_c = 0.8 + math.random() * 0.4
		dp.x = dp.x * dist_c
		dp.y = dp.y * dist_c

		local new_target = {
			x = target.x + dp.x,
			y = target.y + dp.y,
		}
		make_tree_spawner_projectile(surface, target, new_target, tree_name, gen)
	end
end

local function make_exploding_hopper_projectile(surface, source, target, target_entity, generation)
	local s = surface.create_entity{
		name = 'tree-spawner-projectile',
		position = source,
		source = source,
		target = target,
	}
	if s ~= nil then
		local rid = script.register_on_object_destroyed(s)
		storage.entity_destroyed_script_events[rid] = {
			action = "on_exploding_hopper_landed",
			surface = surface,
			generation = generation,
			target = target,
			target_entity = target_entity,
		}
	end
end

local function calculate_hopper_target(source, target, min_dist)
	local dp = {
		x = target.x - source.x,
		y = target.y - source.y,
	}

	local dist = math.sqrt(dp.x * dp.x + dp.y * dp.y)
	if dist < min_dist then return end

	local new_dist = 5.5 + math.random() * 3
	if new_dist > dist + 2.5 then
		new_dist = dist + 2.5
	end
	local rot = math.random(-15, 15) / 60

	dp.x = dp.x * new_dist / dist
	dp.y = dp.y * new_dist / dist
	dp = util.rotate(dp, rot)
	return {
		x = source.x + dp.x,
		y = source.y + dp.y,
	}
end

function M.on_exploding_hopper_landed(event)
	local source = event.target
	local target_entity = event.target_entity
	local generation = event.generation
	local surface = event.surface

	if not surface.valid then
		return
	end

	M.small_explosion(surface, source, 3, 75)
	generation = generation - 1
	if generation <= 0 then return end
	-- Check here because explosion could've killed our target
	if not target_entity.valid then return end

	local target = target_entity.position
	local new_target = calculate_hopper_target(source, target, 2.5)
	if new_target ~= nil then
		make_exploding_hopper_projectile(surface, source, new_target, target_entity, generation)
	end
end

function M.send_homing_exploding_hopper_projectile(surface, source, target_entity)
	local tp = target_entity.position
	local dx = tp.x - source.x
	local dy = tp.y - source.y
	local dist = math.sqrt(dx * dx + dy * dy)
	local number_of_hops = math.floor(dist / 6) + math.random(1, 2)

	local new_target = calculate_hopper_target(source, target_entity.position, 2.5)
	if new_target ~= nil then
		make_exploding_hopper_projectile(surface, source, new_target, target_entity, number_of_hops)
	end
end

function M.small_explosion(surface, at, radius, damage)
	surface.create_entity{
		name = 'land-mine-explosion',
		position = at,
	}
	deal_damage_to_player_entities(surface, at, radius, damage)
end

function M.small_tree_explosion(surface, tree)
	if tree == nil then return end
	local at = tree.position
	tree.destroy()
	M.small_explosion(surface, at, 5, 100)
end

function M.spitter_projectile(surface, treepos, building)
	surface.create_entity{
		name = 'tree-spitter-projectile',
		position = treepos,
		source = treepos,
		target = building,
	}
end

-- This produces a very short fire stream. It looks nice enough to not really need a coroutine.
function M.fire_stream(surface, treepos, building)
	surface.create_entity{
		name = 'flamethrower-fire-stream',
		position = treepos,
		source = treepos,
		target = building,
	}
end

function M.poison_cloud(surface, treepos)
	surface.create_entity{
		name = "tree-poison-cloud",
		position = treepos,
	}
end

function M.spit_at(surface, treepos, building, projectiles)
	local projectile = projectiles[math.random(1, #projectiles)]
	M[projectile](surface, treepos, building)
end

local random_projectiles = {
	{ "spitter_projectile" },
	{ "spitter_projectile", "fire_stream" },
	{ "fire_stream" },
}

function M.default_random_projectiles()
		local rand = math.random()
		if rand < 0.6 then
			return random_projectiles[1]
		elseif rand < 0.85 then
			return random_projectiles[2]
		else
			return random_projectiles[3]
		end
end

function M.pick_random_enemy_type(surface, rate_tree, default)
	if rate_tree == nil then rate_tree = "default" end

	local rand = math.random()
	local res = nil
	local spawntable = evolution.surface_spawntable(surface)
	local nxt = spawntable[rate_tree]
	for i = 1,#nxt do
		local entry = nxt[i]
		if rand < entry[2] then break end
		res = entry[1]
	end
	if res == nil then
		res = default
	end
	return res
end

function M.spawn_biters(surface, treepos, count, rate_table, enemy)
	local actual_pos = {
		x = treepos.x,
		y = treepos.y,
	}

	for i = 1,count do
		local biter = M.pick_random_enemy_type(surface, rate_table, evolution.surface_default_enemy(surface))
		actual_pos.x = treepos.x + math.random() * 5 - 2.5
		actual_pos.y = treepos.y + math.random() * 5 - 2.5
		surface.create_entity{
			name = biter,
			position = actual_pos,
		}
	end

	-- Use provided target, or no target if explicitly disabled.
	-- find_nearest_enemy_entity_with_owner is EXPENSIVE!
	if enemy == nil then
		enemy = surface.find_nearest_enemy_entity_with_owner{position=treepos, max_distance=50, force="enemy"}
	elseif enemy == false then
		enemy = nil
	end

	if enemy ~= nil and enemy.valid then
		surface.set_multi_command{
			command = {
				type = defines.command.attack,
				target = enemy,
			},
			unit_count = count,
			unit_search_distance=10,
		}
	end
end

function M.event_spawn_biters(s)
	s.wait_interval = s.wait_interval - 1
	if s.wait_interval > 0 then return true end
	s.wait_interval = math.random(4, 6)
	if not s.surface.valid then return false end	-- unlikely
	s.spawned = s.spawned + 1
	local biter = M.pick_random_enemy_type(s.surface, s.rate_table, evolution.surface_default_enemy(s.surface))
	local spos = s.position
	s.actual_pos.x = spos.x + math.random() * 5 - 2.5
	s.actual_pos.y = spos.y + math.random() * 5 - 2.5
	s.surface.create_entity{
		name = biter,
		position = s.actual_pos,
	}
	if s.spawned % 12 == 0 or s.spawned == s.count then
		local enemy
		if s.enemy == nil then
			enemy = s.surface.find_nearest_enemy_entity_with_owner{position=spos, max_distance=50, force="enemy"}
		elseif s.enemy == false then
			enemy = nil
		else
			enemy = s.enemy
		end

		if enemy ~= nil and enemy.valid then
			s.surface.set_multi_command{
				command = {
					type = defines.command.attack,
					target = enemy,
				},
				unit_count = s.spawned,
				unit_search_distance=10,
			}
		end
	end
	return s.spawned < s.count
end

function M.spawn_biters_over_time(surface, position, count, rate_table, enemy)
	local s = {}
	s.surface = surface
	s.position = position
	s.actual_pos = {
		x = position.x,
		y = position.y,
	}
	s.count = count
	s.spawned = 0
	s.rate_table = rate_table
	s.enemy = enemy
	s.wait_interval = math.random(4, 6)
	s.event_name = "event_spawn_biters"
	return s
end

local function player_is_unhurt(player)
	if player.get_health_ratio() ~= 1 then return false end
	if player.grid ~= nil then
		if player.grid.shield ~= player.grid.max_shield then return false end
	end
	return true
end

local function player_restore_health(player)
	player.health = player.prototype.max_health
end

function M.event_fake_biters(s)
	if not s.player.valid then return false end
	if not s.surface.valid then return false end

	s.wait_interval = s.wait_interval - 1
	if s.wait_interval > 0 then return true end
	s.wait_interval = math.random(s.wait_low, s.wait_high)

	s.spawned = s.spawned + 1
	local pos = s.player.position
	s.surface.create_entity{
		name = "fake-biter",
		position = pos,
	}
	if s.deal_damage then
		s.player.damage(5, "enemy")
	end
	if s.spawned == s.count then
		player_restore_health(s.player)
		return false
	else
		return true
	end
end

function M.fake_biters(surface, player, count, wait_low, wait_high)
	local s = {}
	s.surface = surface
	s.player = player
	s.deal_damage = player_is_unhurt(player)
	s.wait_interval = 0
	s.count = count
	s.spawned = 0
	s.wait_low = wait_low
	s.wait_high = wait_high
	s.event_name = "event_fake_biters"
	return s
end

function M.take_over_turret(turret)
	turret.force = "enemy"
end

function M.run_coro(s)
	return M[s.event_name](s)
end

function M.focus_on_player(player_id, seconds)
	local l = storage.players_focused_on.list
	local d = storage.players_focused_on.dict

	if d[player_id] == nil then
		l[#l + 1] = player_id
	end
	d[player_id] = {
		seconds = seconds
	}
end

local function unfocus_players()
	storage.players_focused_on.list = {}
	local l = storage.players_focused_on.list
	local d = storage.players_focused_on.dict

	for id, info in pairs(d) do
		info.seconds = info.seconds - 1
		if info.seconds <= 0 then
			d[id] = nil
		else
			l[#l + 1] = id
		end
	end
end

function M.turn_construction_bot_hostile(surface, bot)
	local pos = bot.position
	bot.destroy()
	local newbot = surface.create_entity({
		name = "destroyer",
		position = pos
	})
	if newbot == nil then return end
	-- We can't make bots hostile, but we can make them follow the closest enemy until they die.
	-- It's good enough and looks really cool.
	local enemy = surface.find_nearest_enemy_entity_with_owner{position=pos, max_distance=50, force="enemy"}
	newbot.combat_robot_owner = enemy
end

function M.turn_tree_into_ent(surface, tree)
	if storage.entable_trees[tree.name] == nil then return nil end
	local rand_ent = M.pick_random_enemy_type(surface,"ents", "ent")
	local ent = surface.create_entity{
		name = ents.make_ent_entity_name{
			name = tree.name,
			variation = tree.graphics_variation,
			unit_variant = rand_ent,
		},
		position = tree.position,
	}
	tree.destroy()
	return ent
end

function M.turn_tree_into_ent_or_biter(surface, tree)
	if math.random() < 0.5 then
		local maybe_ent = M.turn_tree_into_ent(surface, tree) 
		if maybe_ent ~= nil then
			return maybe_ent
		end
	end
	local rand_ent = M.pick_random_enemy_type(surface, "half_retaliation", evolution.surface_default_enemy(surface))
	local biter = surface.create_entity{
		name = rand_ent,
		position = tree.position,
	}
	tree.destroy()
	return biter
end

function M.event_spawn_trees_on_timer(s)
	local twt = s.trees_with_times
	if s.idx > #twt or s.frame > 1200 then
		return false
	end
	s.frame = s.frame + 1
	while s.idx <= #twt and twt[s.idx][2] < s.frame do
		local t = twt[s.idx][1]
		s.idx = s.idx + 1
		if not t.valid then goto continue end

		local ent = M[s.spawn_fn](s.surface, t)
		if not ent then goto continue end

		if s.target ~= nil and s.target ~= false and s.target.valid and ent.commandable ~= nil then
			ent.commandable.set_command({
				type = defines.command.attack,
				target = s.target,
			})
		end
		::continue::
	end
	return true
end

function M.gradual_tree_transform_story(surface, trees_with_times, target, spawn_fn)
	local s = {}
	s.surface = surface
	s.trees_with_times = trees_with_times
	s.target = target
	s.frame = 0
	s.idx = 1
	s.event_name = "event_spawn_trees_on_timer"
	s.spawn_fn = spawn_fn
	return s
end

function M.entify_trees_in_cone(surface, from, to, angle, radius, speed, target)
	local coro = M.entify_trees_in_cone_coro(surface, from, to, angle, radius, speed, target)
	storage.tree_stories[#storage.tree_stories + 1] = coro
end
-- Radius is *extra* radius on top of distance from "from" to "to"!

function M.entify_trees_in_cone_coro(surface, from, to, angle, radius, speed, target)
	angle = angle / 360 * 6.28
	local vec_towards = {
		x = to.x - from.x,
		y = to.y - from.y,
	}

	local cone_base = math.sqrt(vec_towards.x * vec_towards.x + vec_towards.y * vec_towards.y)
	local cone_radius = cone_base + radius
	local cone_radius2 = cone_radius * cone_radius

	local vec_left = util.rotate(vec_towards, angle)
	local vec_right = util.rotate(vec_towards, -angle)

	local trees_around_to = area_util.get_trees(surface, util.box_around(to, radius * 1.5))

	local trees_in_cone = {}
	for _, tree in ipairs(trees_around_to) do
		local tree_vec = {
			x = tree.position.x - from.x,
			y = tree.position.y - from.y,
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
		target = surface.find_nearest_enemy_entity_with_owner{position=to, max_distance=32, force="enemy"}
	end
	return M.gradual_tree_transform_story(surface, trees_in_cone, target, "turn_tree_into_ent")
end

function M.artillery_strike_story(surface, sources_targets, projectile, speed)
	local s = {}
	s.surface = surface
	s.sources_targets = sources_targets
	s.projectile = projectile
	s.per_frame = speed / 60.0
	s.frame = 0
	s.idx = 1
	s.event_name = "event_artillery_strike"
	return s
end

function M.tree_artillery(surface, source_rect, target, target_radius, projectile, count, speed)
	local coro = M.tree_artillery_coro(surface, source_rect, target, target_radius, projectile, count, speed)
	storage.tree_stories[#storage.tree_stories + 1] = coro
end

function M.tree_artillery_coro(surface, source_rect, target, target_radius, projectile, count, speed)
	local trees = area_util.get_trees(surface, source_rect)
	if count * 2 > #trees then
		count = math.floor(trees / 2)
	end

	local sources = {}
	for i = 0, count do
		local r = math.random(#trees)
		local tree = trees[r]
		local random_target = util.random_offset(target, target_radius)
		if tree.valid then
			sources[#sources + 1] = {
				source = tree.position,
				target = random_target
			}
		end
	end
	return M.artillery_strike_story(surface, sources, projectile, speed)
end

function M.artillery_strike_frame(s)
	local st = s.sources_targets
	if s.idx > #st or s.frame > 1200 then return false end

	s.frame = s.frame + 1
	if s.idx >= s.frame * s.per_frame then return true end

	if not s.surface.valid then return false end

	local sti = st[s.idx]
	s.idx = s.idx + 1

	s.projectile(s.surface, sti.source, sti.target)
	return true
end

script.on_nth_tick(60, unfocus_players)


return M
