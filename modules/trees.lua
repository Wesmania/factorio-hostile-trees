local area_util = require("modules/area_util")
local util = require("modules/util")
local tree_events = require("modules/tree_events")
local ents = require("modules/ent_generation")
local electricity = require("modules/electricity")
local belttrees = require("modules/belttrees")
local poltergeist = require("modules/poltergeist")
local seed_mortar = require("modules/seed_mortar")
local oil = require("modules/oil")

local M = {}

local function pick_building(s)
	if #s.buildings == 0 then return nil end
	local bi = math.random(1, #s.buildings)
	local building = s.buildings[bi]
	if not building.valid then
		util.list_remove(s.buildings, bi)
		return nil
	else
		return building
	end
end

function M.event_building_spit_assault(s)
	if not s.surface.valid then return false end
	s.total_ticks = s.total_ticks + 1
	if s.total_ticks >= 600 then return false end
	if s.next_event > s.total_ticks then return true end

	local new_min = 999
	for _, tree in pairs(s.trees) do
		if not tree[2].valid then goto continue end

		if s.total_ticks >= tree[1] then
			tree[1] = tree[1] + math.random(60, 90)
			local building = pick_building(s)
			if building ~= nil then
				tree_events.spit_at(s.surface, tree[2].position, building, s.tree_projectiles)
			end
		end
		if tree[1] < new_min then new_min = tree[1] end
		::continue::
	end
	s.next_event = new_min
	return true
end

M.building_spit_assault = function(surface, area, tree_projectiles)
	local s = {}
	s.trees = {}
	for i, tree in ipairs(util.pick_random(area_util.get_trees(surface, area), 10)) do
		s.trees[i] = {math.random(60, 90), tree}
	end
	s.surface = surface
	s.area = area
	s.buildings = area_util.get_buildings(surface, area)
	s.total_ticks = 0
	s.next_event = 0
	s.tree_projectiles = tree_projectiles
	s.event_name = "event_building_spit_assault"
	return s
end

local _events = nil
local function events()
	if _events ~= nil then
		return _events
	end
	_events = {
		sum = 1001.5,
		e = {
			{ 1000.75, function(a)
				if area_util.is_pipe(a.b) and oil.pipe_can_spawn_oil_tree(a.b) then
					oil.spawn_oil_tree(a.t, a.b)
				end
				if true then return end
				if area_util.is_belt(a.b) then
					belttrees.spit_on_belt(a.t, a.b)
				elseif area_util.is_electric_pole(a.b) then
					electricity.try_to_hook_up_electricity(a.t, a.b)
				elseif area_util.is_turret(a.b) then
					tree_events.take_over_turret(a.b)
				else
					return "resume_next"
				end
			end },
			{ 0.75, {
				sum = 105,
				e = {
					{ 18 - storage.hatred / 10, function(a) tree_events.spread_trees_towards_buildings(a.s, a.t, a.b) end },
					{ 7 +  storage.hatred / 10, function(a) tree_events.spit_trees_towards_buildings(a.s, a.t, a.b) end },
					{ 10 - storage.hatred / 20, function(a) tree_events.set_tree_on_fire(a.s, a.t) end },
					{ 10 + storage.hatred / 20, function(a) tree_events.small_tree_explosion(a.s, a.t) end },
					{ 10, function(a) tree_events.spawn_biters(a.s, a.t.position, math.random(3, 5)) end},
					{ 10, function(a)
						if not ents.can_make_ents() then
							return "resume_next"
						end
						tree_events.turn_tree_into_ent(a.s, a.t)
					end },
					{ 10, function(a) tree_events.fire_stream(a.s, a.t.position, a.b.position) end },
					{ 5 + storage.hatred / 10, function(a)
						if not ents.can_make_ents() then
							return "resume_next"
						end
						tree_events.entify_trees_in_cone(a.s, a.b.position, a.t.position, 36, 3, 3, a.b)
					end },
					{ 20 - storage.hatred / 10, function(a) tree_events.spitter_projectile(a.s, a.t.position, a.b.position) end },
					{ 5, function(a)
						local projectile_kinds = {
							{ "spitter_projectile" },
							{ "fire_stream" },
							{ "spitter_projectile", "fire_stream" },
						}
						local pk = projectile_kinds[math.random(1, #projectile_kinds)]
						storage.tree_stories[#storage.tree_stories + 1] = M.building_spit_assault(a.s, a.a, pk)
					end },
				}
			} }
		}
	}
	return _events
end

function pick_event(e, args)
	if type(e) == "function" then
		return e(args)
	else
		local rand = math.random() * e.sum
		local tot = 0.0
		for _, entry in ipairs(e.e) do
			tot = tot + entry[1]
			if rand <= tot then
				local ret = pick_event(entry[2], args)
				if ret ~= "resume_next" then return end
			end
		end
	end
end

function M.event(surface, area)
	local random = math.random()
	local tree = area_util.get_random_tree(surface, area)
	local building = area_util.get_random_building(surface, area)

	if tree == nil or building == nil then return end

	pick_event(events(), {
		s = surface,
		a = area,
		t = tree,
		b = building,
	})
end

-- Events from tree_events that we want available as tree stories.
-- TODO separate file for tree stories?

-- For tree_events.spawn_biters_over_time
function M.event_spawn_biters(s)
	return tree_events.event_spawn_biters(s)
end

-- For tree_events.gradual_tree_transform_story
function M.event_spawn_trees_on_timer(s)
	return tree_events.event_spawn_trees_on_timer(s)
end

-- Poltergeists
function M.throw_a_bunch_of_fast_poltergeists(s)
	return poltergeist.throw_a_bunch_of_fast_poltergeists_coro(s)
end

function M.event_wait_then_burst_electric_tree(s)
	return electricity.event_wait_then_burst_electric_tree(s)
end

function M.event_artillery_strike(s)
	return seed_mortar.artillery_strike_frame(s)
end

function M.run_coro(s)
	return M[s.event_name](s)
end

return M
