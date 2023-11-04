local util = require("modules/util")
local area_util = require("modules/area_util")

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

function M.small_tree_explosion(surface, tree)
	if tree == nil then return end
	local at = tree.position
	tree.destroy()
	surface.create_entity{
		name = 'land-mine-explosion',
		position = at,
	}
	deal_damage_to_player_entities(surface, at, 5, 100)
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

return M
