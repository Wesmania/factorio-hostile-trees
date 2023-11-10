local util = require("modules/util")

local M = {}

local function deal_damage_to_player_entities(surface, position, radius, amount)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			for _, item in ipairs(surface.find_entities_filtered{position = position, radius = radius, force = force}) do
				if item.is_entity_with_health then
					item.damage(amount, "enemy", "explosion")
				end
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
		local rid = script.register_on_entity_destroyed(s)
		global.entity_destroyed_script_events[rid] = {
			action = "on_spawning_spit_landed",
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
	local surface = global.surface

	for i = 1,math.random(1, 3) do
		surface.create_entity{
			name = tree_name,
			position = {
				target.x - 2.0 + math.random() * 4.0,
				target.y - 2.0 + math.random() * 4.0
			},
		}
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
		make_tree_spawner_projectile(global.surface, target, new_target, tree_name, gen)
	end
end

script.on_event(defines.events.on_entity_destroyed, function(data)
	local event = global.entity_destroyed_script_events[data.registration_number]
	if event ~= nil then
		M[event.action](event)
	end
end)

local function make_exploding_hopper_projectile(surface, source, target, target_entity, generation)
	local s = surface.create_entity{
		name = 'tree-spawner-projectile',
		position = source,
		source = source,
		target = target,
	}
	if s ~= nil then
		local rid = script.register_on_entity_destroyed(s)
		global.entity_destroyed_script_events[rid] = {
			action = "on_exploding_hopper_landed",
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
	local surface = global.surface

	M.small_explosion(surface, source, 3, 75)
	generation = generation - 1
	if generation <= 0 then return end
	-- Check here because explosion could've killed our target
	if not target_entity.valid then return end

	local target = target_entity.position
	local new_target = calculate_hopper_target(source, target, 2.5)
	if new_target ~= nil then
		make_exploding_hopper_projectile(global.surface, source, new_target, target_entity, generation)
	end
end

function M.send_homing_exploding_hopper_projectile(source, target_entity)
	local tp = target_entity.position
	local dx = tp.x - source.x
	local dy = tp.y - source.y
	local dist = math.sqrt(dx * dx + dy * dy)
	local number_of_hops = math.floor(dist / 6) + math.random(1, 2)

	local new_target = calculate_hopper_target(source, target_entity.position, 2.5)
	make_exploding_hopper_projectile(global.surface, source, new_target, target_entity, number_of_hops)
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

function M.pick_random_enemy_type(rate_tree)
	if rate_tree == nil then rate_tree = "default" end

	local rand = math.random()
	local res = nil
	for _, entry in ipairs(global.spawntable[rate_tree]) do
		if rand < entry[2] then break end
		res = entry[1]
	end
	if res == nil then
		res = 'small-biter'
	end
	return res
end

function M.spawn_biters(surface, treepos, count, rate_table)
	local actual_pos = {
		x = treepos.x,
		y = treepos.y,
	}

	for i = 1,count do
		local biter = M.pick_random_enemy_type(rate_table)
		actual_pos.x = treepos.x + math.random() * 5 - 2.5
		actual_pos.y = treepos.y + math.random() * 5 - 2.5
		surface.create_entity{
			name = biter,
			position = actual_pos,
		}
	end

	local enemy = surface.find_nearest_enemy_entity_with_owner{position=treepos, max_distance=50, force="enemy"}
	if enemy ~= nil then
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
	if not s.surface.valid then return false end
	s.wait_interval = s.wait_interval - 1
	if s.wait_interval > 0 then return true end
	s.spawned = s.spawned + 1
	local biter = M.pick_random_enemy_type(s.rate_table)
	s.actual_pos.x = s.position.x + math.random() * 5 - 2.5
	s.actual_pos.y = s.position.y + math.random() * 5 - 2.5
	s.surface.create_entity{
		name = biter,
		position = s.actual_pos,
	}
	if s.spawned % 12 == 0 or s.spawned == s.count then
		local enemy = s.surface.find_nearest_enemy_entity_with_owner{position=s.position, max_distance=50}
		if enemy ~= nil then
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

function M.spawn_biters_over_time(surface, position, count, rate_table)
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
	local l = global.players_focused_on.list
	local d = global.players_focused_on.dict

	if d[player_id] == nil then
		l[#l + 1] = player_id
	end
	d[player_id] = {
		seconds = seconds
	}
end

local function unfocus_players()
	global.players_focused_on.list = {}
	local l = global.players_focused_on.list
	local d = global.players_focused_on.dict

	for id, info in pairs(d) do
		info.seconds = info.seconds - 1
		if info.seconds <= 0 then
			d[id] = nil
		else
			l[#l + 1] = id
		end
	end
end

script.on_nth_tick(60, unfocus_players)

return M
