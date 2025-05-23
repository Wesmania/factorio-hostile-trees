local stdlib_util = require("__core__/lualib/util")

local chunks = require("modules/chunks")
local area_util = require("modules/area_util")
local util = require("modules/util")
local tree_images = require("modules/tree_images")

local tree_events
if data == nil then
	tree_events = require("modules/tree_events")
end


local M = {}

function M.fresh_setup()
	storage.electric_tree_state = {
		all = {},
		growing = {
			dict = {},
			list = {},
		},
		mature = {
			dict = {},
			list = {},
		},
		tick = 0,
	}
end

function M.try_to_hook_up_electricity(tree, electric)
	local surface = tree.surface
	local treepos = tree.position

	local pole = M.electrify_tree(tree)
	if pole == nil then return end

	-- Get current power production.
	-- Hopefully this isn't too costly.
	local stats = electric.electric_network_statistics
	local total_power = 0
	for name, _ in pairs(stats.output_counts) do
		local pn = prototypes.entity[name]
		if not pn or pn.type ~= "electric-energy-interface" then
			local fc = stats.get_flow_count{
				name = name,
				category = "output",
				precision_index = defines.flow_precision_index.five_seconds
				}
			-- Reports usage per tick.
			total_power = total_power + fc
		end
	end

	-- Every point is 60 W. This is 250 kW.
	local power_usage = 250 * 1000 / 60
	-- Scale initial cost at 36/72 MW thresholds
	if total_power > 600000 then
		power_usage = power_usage * 2
	end
	if total_power > 1200000 then
		power_usage = power_usage * 2
	end

	if M.register_new_electric_tree(pole, electric, power_usage) ~= nil then
		tree.destroy()
	else
		pole.destroy()
	end
end

function M.get_copper_connector(thing)
	for _, c in ipairs(thing.get_wire_connectors(true)) do
		if c.wire_type == defines.wire_type.copper then
			return c
		end
	end
	return nil
end

function M.register_new_electric_tree(tree, other_pole, power_usage)
	-- connect_neighbour returns false if we're already connected and
	-- there's no way to find out connection status (?????)
	local tree_connector = M.get_copper_connector(tree)
	local pole_connector = M.get_copper_connector(other_pole)

	if tree_connector == nil or pole_connector == nil then
		return nil
	end

	if not tree_connector.is_connected_to(pole_connector) then
		if not tree_connector.connect_to(pole_connector) then
			return nil
		end
	end

	local electric = tree.surface.create_entity{
		name = "electric-tree-consumption",
		position = tree.position,
	}

	-- Are we connected to something producing?
	if not electric.is_connected_to_electric_network() then
		electric.destroy()
		return nil
	end

	-- We can hack around input_flow_limit being wacky by tweaking
	-- electric_buffer_size.
	electric.power_usage = power_usage
	electric.electric_buffer_size = power_usage

	-- FIXME assuming that electric will never be destroyed, it has 1M health.
	local tree_data = M.new_electrified_tree(tree, electric)
	if tree_data == nil then
		electric.destroy()
		return nil
	end

	local rid = script.register_on_object_destroyed(tree)
	storage.entity_destroyed_script_events[rid] = {
		action = "on_electric_tree_destroyed",
		pos = tree.position,
		id = tree.unit_number,
	}
	chunks.add_area_mask(tree.surface, tree.position)
	return tree_data
end

function M.on_electric_tree_destroyed(e)
	chunks.remove_area_mask(e.surface, e.pos)
	M.destroy_electrified_tree(e.id)
end

function M.electrify_tree(tree)
	if storage.electric_trees[tree.name] == nil then return nil end
	local ent = tree.surface.create_entity{
		name = M.make_electric_tree_name{
			name = tree.name,
			variation = tree.graphics_variation,
		},
		position = tree.position,
	}
	return ent
end

function M.new_electrified_tree(etree, power_entity)
	local tree = {
		e = etree,
		power = power_entity,
		gen = 0,
		state = "growing",
		spawned_trees = 0,
		expansions = 0,
		expansion_attempts = 0,
		starvation = 2,
		gaggle = {},
	}
	local et = storage.electric_tree_state
	local id = etree.unit_number
	if et.all[id] == nil then
		et.all[id] = tree
		util.ldict_add(et.growing, id, tree)
		tree.gaggle[id] = true
		return tree
	else
		return nil
	end
end

function M.destroy_electrified_tree(id)
	local et = storage.electric_tree_state
	if et.all[id] == nil then return end
	local tree = et.all[id]
	et.all[id] = nil
	util.ldict_remove(et[tree.state], id)
	if tree.power.valid then
		tree.power.destroy()
	end
	if tree.e.valid then
		tree.e.destroy()
	end
end

function M.mature_electrified_tree(tree)
	if tree.state ~= "growing" then return end
	local et = storage.electric_tree_state
	local id = tree.e.unit_number
	util.ldict_remove(et[tree.state], id)
	tree.state = "mature"
	util.ldict_add(et[tree.state], id, tree)
end

function M.get_random_growing_tree()
	local et = storage.electric_tree_state
	return util.ldict_get_random(et.growing)
end

function M.get_random_mature_tree()
	local et = storage.electric_tree_state
	return util.ldict_get_random(et.mature)
end

local function can_expand(etree)
	return etree.gen < 5 and etree.expansion_attempts < 5 and etree.expansions < 2
end

local function can_spawn_trees(etree)
	return etree.spawned_trees < 50
end

local function check_starvation(etree)
	local p = etree.power.energy / etree.power.electric_buffer_size
	if p < 0.99 then
		etree.starvation = etree.starvation - (1 - p)
		if etree.starvation <= 0 then
			M.burst_electric_tree_gaggle(etree.gaggle)
		end
	else
		etree.starvation = 2
	end
end

-- Called once per second.
function M.check_electrified_trees()
	-- Mature trees increase power consumption once every 5 minutes on average.
	local et = storage.electric_tree_state
	local gcount = #et.mature.list / 300

	et.tick = (et.tick + 1) % 10

	-- Be careful, check if their trees are valid!
	-- We could've destroyed a tree before the on_destroy call went through!

	while gcount > 1 or (gcount > 0 and math.random() < gcount) do
		gcount = gcount - 1
		local tree = M.get_random_mature_tree()
		if tree == nil or not tree.e.valid then goto continue_mature end
		local more = 1.3 + math.random() * 0.4
		tree.power.power_usage = tree.power.power_usage * more
		tree.power.electric_buffer_size = tree.power.electric_buffer_size * more
		::continue_mature::
	end

	-- Growing trees:
	-- spread trees once every 15 seconds on average if they haven't spread 50 already,
	-- have a 1/6 chance of spreading another electrified tree (with some limits),
	-- mature when they can't do either.
	gcount = #et.growing.list / 15
	
	while gcount > 1 or (gcount > 0 and math.random() < gcount) do
		gcount = gcount - 1
		local tree = M.get_random_growing_tree()
		if tree == nil or not tree.e.valid then goto continue end

		local pos = {}
		local treepos = tree.e.position

		if can_spawn_trees(tree) then
			local newtrees = math.random(3, 5)
			local tname = M.split_electric_tree_name(tree.e.name).name
			for i = 1,math.random(3, 5) do
				local dst = math.sqrt(math.random() * 64)
				local angle = math.random() * math.pi * 2
				pos.x = treepos.x + math.sin(angle) * dst
				pos.y = treepos.y + math.cos(angle) * dst
				tree.e.surface.create_entity{
					name = tname,
					position = pos
				}
			end
			tree.spawned_trees = tree.spawned_trees + newtrees
		end

		if math.random() < 0.166 and can_expand(tree) then
			tree.expansion_attempts = tree.expansion_attempts + 1
			-- Pick random direction and distance.
			local angle = math.random() * math.pi * 2
			local dist = 9 + math.random() * 4
			local newpos = {
				x = treepos.x + math.sin(angle) * dist,
				y = treepos.y + math.cos(angle) * dist,
			}

			-- Are there few trees in this direction? And is it land?
			if not area_util.is_water(tree.e.surface, newpos)
			   and area_util.count_trees(tree.e.surface, util.box_around(newpos, 4), 12) < 12
			then
				-- Yes! Expand here then!
				local newetree = tree.e.surface.create_entity{
					name = tree.e.name,
					position = newpos,
				}
				if newetree ~= nil then
					local newetree_data = M.register_new_electric_tree(newetree, tree.e, tree.power.power_usage)
					if newetree_data ~= nil then
						tree.expansions = tree.expansions + 1
						newetree_data.gen = tree.gen + 1
						newetree_data.gaggle = tree.gaggle
						tree.gaggle[newetree_data.e.unit_number] = true
					else
						newetree.destroy()
					end
				end
			end
		end

		if not can_spawn_trees(tree) and not can_expand(tree) then
			M.mature_electrified_tree(tree)
		end
		::continue::
	end

	-- Update starvation status for trees.
	if et.tick % 10 == 0 then
		for _, t in pairs(et.growing.dict) do
			check_starvation(t)
		end
		for _, t in pairs(et.mature.dict) do
			check_starvation(t)
		end
	end
end

function M.burst_electric_tree_gaggle(gaggle)
	local et = storage.electric_tree_state.all
	for tid, _ in pairs(gaggle) do
		local g_etree = et[tid]
		if g_etree ~= nil then
			-- Safeguard against triggering it again too soon
			g_etree.starvation = 2
			local event = M.burst_electric_tree_story(g_etree)
			storage.tree_stories[#storage.tree_stories + 1] = event
		end
	end
end

function M.burst_electric_tree_story(etree)
	local story = {
		etree = etree,
		wait = math.random(15, 60),
		event_name = "event_wait_then_burst_electric_tree",
	}
	return story
end

function M.event_wait_then_burst_electric_tree(s)
	if s.wait > 0 then
		s.wait = s.wait - 1
		return true
	end
	if not s.etree.e.valid then return false end

	local surface = s.etree.e.surface
	local pos = s.etree.e.position
	tree_events.set_tree_on_fire(surface, s.etree.e)

	-- Okay, now collect trees in a radius.
	local speed = 3
	local trees_around = area_util.get_trees_radius(surface, pos, 8)
	local timed_trees = {}

	for _, tree in ipairs(trees_around) do
		local tree_vec = {
			x = tree.position.x - pos.x,
			y = tree.position.y - pos.y,
		}
		local tree_dist = math.sqrt(util.len2(tree_vec))
		local tree_frame = math.floor(tree_dist * 60 / speed)
		timed_trees[#timed_trees + 1] = {
			tree,
			tree_frame
		}
	end
	table.sort(timed_trees, function(a, b) return a[2] < b[2] end)
	if s.etree.state == "growing" then
		while #timed_trees > s.etree.spawned_trees do
			timed_trees[#timed_trees] = nil
		end
	end

	local target = surface.find_nearest_enemy_entity_with_owner{position=pos, max_distance=32, force="enemy"}

	local tstory = tree_events.gradual_tree_transform_story(surface, timed_trees, target, "turn_tree_into_ent_or_biter")
	for k, v in pairs(tstory) do
		s[k] = v
	end
	return true
end

-- One last check: trigger bursting when one of trees dies.
function M.pole_died(e)
	if not M.is_electric_tree_name(e.entity.name) then return end
	local etree = storage.electric_tree_state.all[e.entity.unit_number]
	if etree ~= nil then
		M.burst_electric_tree_gaggle(etree.gaggle)
	end
end

function M.pole_bot_deconstructed(event)
	M.pole_died(event)
end

function M.pole_mined(event)
	M.pole_died(event)
end

-- Below is data stage.

function M.make_electric_tree_name(params)
		return "tree-electric-pole-" .. params.name .. "-" .. string.format("%03d", params.variation)
end

function M.is_electric_tree_name(name)
	return string.sub(name, 1, 19) == "tree-electric-pole-"
end

function M.split_electric_tree_name(name)
		if string.sub(name, 1, 19) ~= "tree-electric-pole-" then return nil end
		local l = string.len(name)
		return {
			name = string.sub(name, 20, l - 4),
			variation = tonumber(string.sub(name, l - 3, l)),
		}
end

function M.generate_electric_tree(tree_data)
	for i, variation in ipairs(tree_data.variations) do
		local unit = {
			type = "electric-pole",
			name = M.make_electric_tree_name{
				name = tree_data.name,
				variation = i,
			},
			localised_name = {"entity-name.hostile-trees-electrified-tree"},
			hidden = true,
			flags = {
				"breaths-air",
				"hide-alt-info",
				"not-upgradable",
				"not-in-made-in"
			},
			max_health = 25,
			corpse = tree_data.corpse,
			--dying_explosion = "big-electric-pole-explosion",
			collision_box = tree_data.collision_box,
			selection_box = tree_data.selection_box,
			drawing_box = tree_data.drawing_box,
			maximum_wire_distance = 30,
			supply_area_distance = 1,
			pictures = tree_images.generate_tree_image(tree_data, variation, tree_data.colors[i]) ,
			connection_points = {	-- FIXME
				{
					shadow = { copper = stdlib_util.by_pixel_hr(245.0, -34.0), },
					wire = { copper = stdlib_util.by_pixel_hr(0, -246.0), }
				},
			},
			water_reflection = tree_data.water_reflection,
			light = {
				intensity = 1,
				size = 10,
			}
		}
		data:extend({unit})
	end
end

return M
