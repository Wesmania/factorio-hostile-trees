local util = require("modules/util")
local area_util = require("modules/area_util")
local chunks = require("modules/chunks")
local tree_images = require("modules/tree_images")

local M = {}

-- Randomly selected from between 3 to 4 billion. Let's hope it doesn't collide.
local SPECIAL_OUTPUT_PIPE = 3521853045
local OIL_EATER = 10
local ROOT_PUMP_INPUT = 20
local MAX_OIL_EATER = 40

local MAX_BREED_COUNT = 4
local MAX_BREED_ATTEMPT = 6
local REGROWTH_TICKS = 4
local EXPAND_TICKS = 2
local EATER_LEVEL_TICKS = 5

local OIL_HIGH_LEVEL = 0.8
local OIL_LOW_LEVEL = 0.2

local function add_special_fluidbox(box)
	local c = box.pipe_connections
	c[#c + 1] = { connection_type = "linked", linked_connection_id = SPECIAL_OUTPUT_PIPE }
end

function M.data_updates_stage()
	for _, item in pairs(data.raw["pipe"]) do
		add_special_fluidbox(item.fluid_box)
	end
	for _, item in pairs(data.raw["pipe-to-ground"]) do
		add_special_fluidbox(item.fluid_box)
	end
end

function M.fresh_setup()
	storage.oil_tree_state = {
		trees = {
			dict = {},
			list = {},
		},
	}
end

function M.pipe_can_spawn_oil_tree(pipe)
	local f = pipe.fluidbox
	if f == nil then return false end
	local fluid = f[1]
	if fluid == nil then return false end
	if fluid.name ~= "crude-oil" then return false end

	local ptypes = f.get_prototype(1)
	local volume = 0
	if ptypes.volume ~= nil then
		volume = ptypes.volume
	else
		for _, p in ipairs(ptypes) do
			volume = volume + p.volume
		end
	end

	if fluid.amount / volume < 0.2 then return false end
	return true
end


local function check_killable_pipe(p)
	local n = p.name
	if      n ~= "hostile-trees-pipe-roots" and
		n ~= "hostile-trees-pump-roots" and
		n ~= "hostile-trees-pipe-roots-vertex" then
		return
	end
	local conns = p.fluidbox.get_linked_connections()
	-- One of the ends is the pipe that died, so die with 2 or less.
	if #conns > 2 then return end

	for _, c in ipairs(conns) do
		local n = c.other_entity.name
		if      n ~= "hostile-trees-pipe-roots" and
			n ~= "hostile-trees-pump-roots" and
			n ~= "hostile-trees-pipe-roots-vertex" and
			c.this_linked_connection_id ~= ROOT_PUMP_INPUT then -- Ignore root pump's pipe connection.
			return
		end
	end
	p.die()
end

function M.root_pipe_died(e)
	local pipe = e.entity
	local conns = pipe.fluidbox.get_linked_connections()
	for _, other in ipairs(conns) do
		check_killable_pipe(other.other_entity)
	end
end

function M.on_oil_tree_destroyed(e)
	-- Don't kill roots when tree dies, it will be able to regrow.
	-- Let eater live for the same reason.
	local tree = e.item
	if not tree.roots.valid then
		M.kill_and_deregister_tree(tree)
	elseif not tree.tree.valid then
		-- If tree is dead and we are not connected to anything else, die as well.
		local c = tree.roots.fluidbox.get_linked_connections()
		if #c == 0 then
			tree.roots.die()
		end
	end
end

function M.register_tree(tree)
	util.ldict_add(storage.oil_tree_state.trees, tree.id, tree)
end

function M.kill_and_deregister_tree(tree)
	if tree.roots.valid then
		tree.roots.die()
	end
	if tree.tree.valid then
		tree.tree.die()
	end
	if tree.eater.valid then
		tree.eater.destroy()
	end
	util.ldict_remove(storage.oil_tree_state.trees, tree.id)
end

-- FIXME copypasted from electricity.lua
function M.make_oil_tree_name(params)
	return "hostile-trees-oil-tree-" .. params.name .. "-" .. string.format("%03d", params.variation)
end

function M.is_oil_tree_name(name)
	return string.sub(name, 1, 23) == "hostile-trees-oil-tree-"
end

function M.split_oil_tree_name(name)
		if string.sub(name, 1,23) ~= "hostile-trees-oil-tree-" then return nil end
		local l = string.len(name)
		return {
			name = string.sub(name, 24, l - 4),
			variation = tonumber(string.sub(name, l - 3, l)),
		}
end

function M.oil_eater_name(level)
	return "hostile-trees-oil-eater-" .. string.format("%02d", level)
end

function M.get_oil_trees(surface, area)
	 return surface.find_entities_filtered{area = area, name = "hostile-trees-pipe-roots-vertex"}
end

function M.get_free_connection(root, j)
	local box = root.fluidbox
	if j ~= nil then
		local e = box.get_linked_connection(j)
		if e == nil then
			return j
		else
			return nil
		end
	end
	for i=1,4 do
		local e = box.get_linked_connection(i)
		if e == nil then
			return i
		end
	end
	return nil
end

function M.try_connect(one, two, one_connection, two_connection)
	if one == nil or two == nil then return false end
	local pc = M.get_free_connection(one, one_connection)
	local cc = M.get_free_connection(two, two_connection)
	if cc == nil or pc == nil then return false end
	one.fluidbox.add_linked_connection(pc, two, cc)
	return true
end

local function free(d)
	for _, item in pairs(d) do
		if item.valid then
			item.destroy()
		end
	end
end

function M.make_oil_tree(tree_info)
	local d = {}

	if storage.oil_trees[tree_info.name] == nil then return nil end
	local name = M.make_oil_tree_name(tree_info)
	local oil_tree = tree_info.surface.create_entity{
		name = name,
		position = tree_info.position,
		force = "enemy",
	}
	if oil_tree == nil then free(d) ; return nil end
	d[#d + 1] = oil_tree
	local oil_eater = tree_info.surface.create_entity{
		name = M.oil_eater_name(1),
		position = tree_info.position,
		force = "enemy",
	}
	if oil_eater == nil then free(d) ; return nil end
	d[#d + 1] = oil_eater
	local base_roots = tree_info.surface.create_entity{
		name = "hostile-trees-pipe-roots-vertex",
		position = tree_info.position,
		force = "enemy",
	}
	if base_roots == nil then free(d) ; return nil end
	d[#d + 1] = base_roots

	local t = M.try_connect(base_roots, oil_tree)
	assert(t == true)
	local t = M.try_connect(oil_tree, oil_eater, OIL_EATER, OIL_EATER)
	assert(t == true)
	local tree_object = {
		roots = base_roots,
		tree = oil_tree,
		eater = oil_eater,

		id = base_roots.unit_number,
		name = tree_info.name,
		variation = tree_info.variation,

		-- Growth state
		regrowth_stage = 1,
		expand_stage = 1,
		eater_level = 1,
		eater_level_progress = 1,
		breed_count = 0,
		breed_attempt = 0,
		generation = 0,
	}

	local rid = script.register_on_object_destroyed(oil_tree)
	storage.entity_destroyed_script_events[rid] = {
		action = "on_oil_tree_destroyed",
		item = tree_object,
	}
	local rid = script.register_on_object_destroyed(base_roots)
	storage.entity_destroyed_script_events[rid] = {
		action = "on_oil_tree_destroyed",
		item = tree_object,
	}

	return tree_object
end

function M.deinitialize_oil_tree(tree)
	if tree.roots.valid then
		tree.roots.destroy()
	end
	if tree.tree.valid then
		tree.tree.destroy()
	end
	if tree.eater.valid then
		tree.eater.destroy()
	end
end

-- Returns pipes in order from start to end.
function M.draw_pipe_edge(surface, start, _end)
	local ret = {}
	local delta = util.normalize({
		x = _end.x - start.x,
		y = _end.y - start.y,
	})
	local p = start
	local last_node = nil

	local at_least_one = false
	while util.dist2(p, _end) >= 1 or not at_least_one do
		at_least_one = true
		p.x = p.x + delta.x
		p.y = p.y + delta.y
		local node = surface.create_entity{
			name = "hostile-trees-pipe-roots",
			position = p,
			force = "enemy",
		}
		if node == nil then free(ret) ; return nil end
		ret[#ret + 1] = node
		if last_node ~= nil then
			if not M.try_connect(last_node, node) then free(ret) ; return nil end
		end
		last_node = node
	end
	return ret
end

function M.connect_oil_tree_to_entity(roots, entity)
	local deletables = {}

	local pipe_edge = M.draw_pipe_edge(roots.surface, entity.position, roots.position)
	if pipe_edge == nil then free(deletables) ; return end
	for _, pipe in ipairs(pipe_edge) do
		deletables[#deletables + 1] = pipe
	end

	local pipe_end = pipe_edge[1]
	local tree_end = pipe_edge[#pipe_edge]

	if not M.try_connect(entity, pipe_end) then free(deletables) ; return end
	if not M.try_connect(roots, tree_end) then free(deletables) ; return end

	return {
		edge = pipe_edge,
	}
end

function M.setup_pump_protection(pump)
	local rid = script.register_on_object_destroyed(pump)
	storage.entity_destroyed_script_events[rid] = {
		action = "on_oil_tree_pump_destroyed",
		surface = pump.surface,
		position = pump.position
	}
	chunks.add_area_mask(pump.surface, pump.position)
end

function M.on_oil_tree_pump_destroyed(e)
	chunks.remove_area_mask(e.surface, e.position)
end

function M.connect_oil_tree_to_pipe(roots, pipe)
	if not pipe.valid or not roots.valid then return end

	local p = pipe.position
	local oil_pos = roots.position

	local deletables = {}
	local initial_pump = roots.surface.create_entity{
			name = "hostile-trees-pump-roots",
			position = p,
			force = "enemy",
	}
	if initial_pump == nil then free(deletables) ; return end
	if not M.try_connect(pipe, initial_pump, SPECIAL_OUTPUT_PIPE, ROOT_PUMP_INPUT) then free(deletables) ; return end
	deletables[#deletables + 1] = initial_pump

	local ret = M.connect_oil_tree_to_entity(roots, initial_pump)
	if ret == nil then free(deletables) ; return end

	M.setup_pump_protection(initial_pump)
	ret.pump = initial_pump
	return ret
end

function M.spawn_oil_tree(tree, pipe)
	if not pipe.valid then return end
	local oil_tree = M.make_oil_tree({
		surface = tree.surface,
		name = tree.name,
		position = tree.position,
		variation = tree.graphics_variation,
	})
	if oil_tree == nil then return end

	local connection = M.connect_oil_tree_to_pipe(oil_tree.roots, pipe)
	if connection == nil then
		M.deinitialize_oil_tree(oil_tree)
		return
	end
	tree.destroy()

	M.register_tree(oil_tree)
end

function M.tree_oil_level(tree)
	local f = tree.eater.fluidbox
	local fluid = f[1]
	if fluid == nil then return 0 end
	local ptypes = f.get_prototype(1)
	local volume = 0
	if ptypes.volume ~= nil then
		volume = ptypes.volume
	else
		for _, p in ipairs(ptypes) do
			volume = volume + p.volume
		end
	end
	return fluid.amount / volume
end

function max_generation()
	return 5 + math.floor(storage.hatred / 10)
end

function M.eater_level_up(tree_info)
	if not tree_info.tree.valid then return end
	if tree_info.eater_level_progress < EATER_LEVEL_TICKS then
		tree_info.eater_level_progress = tree_info.eater_level_progress + 1
		return
	end
	tree_info.eater_level_progress = 1
	if not tree_info.tree.valid or not tree_info.eater.valid then return end
	if tree_info.eater_level >= MAX_OIL_EATER then return end
	tree_info.eater_level = tree_info.eater_level + 1

	local new_eater = tree_info.roots.surface.create_entity{
		name = M.oil_eater_name(tree_info.eater_level),
		position = tree_info.roots.position,
		force = "enemy",
	}
	if new_eater == nil then return end
	tree_info.eater.destroy()
	tree_info.eater = new_eater
	local t = M.try_connect(tree_info.tree, tree_info.eater, OIL_EATER, OIL_EATER)
	assert(t == true)
end

-- Returns whether it cannot expand anymore due to counters.
function M.try_to_expand(tree_info)
	if tree_info.expand_stage < EXPAND_TICKS then
		tree_info.expand_stage = tree_info.expand_stage + 1
		return
	end
	tree_info.expand_stage = 1

	if tree_info.breed_attempt >= MAX_BREED_ATTEMPT then return false end
	if tree_info.breed_count >= MAX_BREED_COUNT then return false end

	if tree_info.generation >= max_generation() then return false end
	tree_info.breed_attempt = tree_info.breed_attempt + 1
	if not tree_info.tree.valid or not tree_info.roots.valid then return true end

	local tree = tree_info.tree
	local pos = util.random_offset_circle(tree_info.roots.position, 9, 16)
	local nearby_trees = M.get_oil_trees(tree_info.roots.surface, util.box_around(pos, 6))
	if #nearby_trees > 0 then return true end

	local nv = {
		name = tree_info.name,
		variation = tree_info.variation,
		surface = tree_info.roots.surface,
		position = pos,
	}
	local new_oil_tree = M.make_oil_tree(nv)
	if new_oil_tree == nil then return true end

	local conn = M.connect_oil_tree_to_entity(new_oil_tree.roots, tree_info.roots)
	if conn == nil then
		M.deinitialize_oil_tree(new_oil_tree)
		return
	end
	new_oil_tree.generation = tree_info.generation + 1
	M.register_tree(new_oil_tree)
	tree_info.breed_count = tree_info.breed_count + 1

	-- Eat all our oil as a price.
	tree_info.eater.fluidbox[1] = nil

	return true
end

local function try_to_attach_to_tree(tree_info, other_id)
	local other_tree_info = util.ldict_get(storage.oil_tree_state.trees, other_id)
	if other_tree_info == nil then return false end
	local oil_level = M.tree_oil_level(other_tree_info)
	if oil_level < OIL_HIGH_LEVEL then return false end
	local conn = connect_oil_tree_to_entity(tree_info.roots, other_tree_info.roots)
	if conn == nil then return false end
	return true
end

function M.try_to_attach_to_random_tree(tree_info)
	local nearby_trees = M.get_oil_trees(tree_info.roots.surface, util.box_around(tree_info.roots.position, 12))
	local pick = util.pick_random(nearby_trees, 1)[1]
	return try_to_attach_to_tree(tree_info, tree_info.roots.unit_number)
end

function M.try_to_attach_to_pipe(tree_info)
	game.print("Try pipe attach")
	local nearby_pipe = area_util.get_random_true_pipe(tree_info.roots.surface, util.box_around(tree_info.roots.position, 24))
	if nearby_pipe == nil then return false end
	game.print("Found pipe")
	if not M.pipe_can_spawn_oil_tree(nearby_pipe) then return false end
	if M.connect_oil_tree_to_pipe(tree_info.roots, nearby_pipe) == nil then return false end
	return true
end

function M.regrow_tree(tree_info)
	if tree_info.tree.valid then return end
	if tree_info.regrowth_stage < REGROWTH_TICKS then
		tree_info.regrowth_stage = tree_info.regrowth_stage + 1
		return
	end
	tree_info.regrowth_stage = 1

	local name = M.make_oil_tree_name(tree_info)
	local oil_tree = tree_info.roots.surface.create_entity{
		name = name,
		position = tree_info.roots.position,
		force = "enemy",
	}
	if oil_tree == nil then return end
	local rid = script.register_on_object_destroyed(oil_tree)
	storage.entity_destroyed_script_events[rid] = {
		action = "on_oil_tree_destroyed",
		item = tree_info,
	}
	tree_info.tree = oil_tree
	local t = M.try_connect(tree_info.roots, tree_info.tree)
	assert(t == true)
	local t = M.try_connect(tree_info.tree, tree_info.eater, OIL_EATER, OIL_EATER)
	assert(t == true)
end

function M.oil_tree_process(tree_info)
	-- First, do we have to regrow?
	if not tree_info.tree.valid then
		M.regrow_tree(tree_info)
		return
	end
	local oil = M.tree_oil_level(tree_info)
	if oil >= OIL_HIGH_LEVEL then
		local could_still_grow = M.try_to_expand(tree_info)
		if not could_still_grow then
			M.eater_level_up(tree_info)
		end
	elseif oil <= OIL_LOW_LEVEL then
		game.print("Low oil")
		if math.random() > 0.5 then
			M.try_to_attach_to_pipe(tree_info)
		else
			M.try_to_attach_to_random_tree(tree_info)
		end
	end
end

-- Called once per second.
function M.check_oil_trees()
	-- Change state once every 2 minutes.
	local state = storage.oil_tree_state.trees
	local gcount = #state.list / 2		-- FIXME
	while gcount > 1 or (gcount > 0 and math.random() < gcount) do
		gcount = gcount - 1
		local tree = util.ldict_get_random(state)
		M.oil_tree_process(tree)
	end
end

function M.rootpictures()
	local pics_from = data.raw["optimized-decorative"]["brown-carpet-grass"]
	local pic = pics_from.pictures[9]
	pic.tint = {
		r = 0.1,
		g = 0.1,
		b = 0.1,
		a = 1.0,
	}
	pic.scale = 0.4
	return {
		straight_vertical_single = pic,
		straight_vertical = pic,
		straight_vertical_window = pic,
		straight_horizontal_window = pic,
		straight_horizontal = pic,
		corner_up_right = pic,
		corner_up_left = pic,
		corner_down_right = pic,
		corner_down_left = pic,
		t_up = pic,
		t_down = pic,
		t_right = pic,
		t_left = pic,
		cross = pic,
	}
end

function M.generate_oil_tree(tree_data)
	local black_colors = {
		r = 0.1,
		g = 0.1,
		b = 0.1,
		a = 1.0,
	}
	for i, variation in ipairs(tree_data.variations) do
		local unit = {
			type = "fluid-turret",
			name = M.make_oil_tree_name{
				name = tree_data.name,
				variation = i,
			},
			localised_name = {"entity-name.hostile-trees-oily-tree"},
			hidden = true,
			flags = {
				"breaths-air",
				"hide-alt-info",
				"not-upgradable",
				"not-in-made-in"
			},
			max_health = 500,
			resistances = {
				{
					type = "fire",
					percent = 100,
				}
			},
			corpse = tree_data.corpse,
			dying_explosion = "gun-turret-explosion",
			collision_box = tree_data.collision_box,
			selection_box = tree_data.selection_box,
			drawing_box = tree_data.drawing_box,
			pictures = tree_images.generate_tree_image(tree_data, variation, black_colors),
			folded_animation = {
				north = tree_images.generate_tree_image(tree_data, variation, black_colors),
			},
			call_for_help_radius = 16,
			turret_base_has_direction = true,
			graphics_set = {},
			water_reflection = tree_data.water_reflection,
			fluid_buffer_size = 100,
			fluid_buffer_input_flow = 300 / 60 / 5,
			activation_buffer_ratio = 0.1,
			fluid_box = {
				volume = 100,
				hide_connection_info = true,
				pipe_connections = {
					{ connection_type = "linked", flow_direction = "input", linked_connection_id = 1 },
					{ connection_type = "linked", flow_direction = "input", linked_connection_id = 2 },
					{ connection_type = "linked", flow_direction = "input", linked_connection_id = 3 },
					{ connection_type = "linked", flow_direction = "input", linked_connection_id = 4 },
					{ connection_type = "linked", flow_direction = "output", linked_connection_id = OIL_EATER }
				},
				volume_reservation_fraction = 0.5,
				filter = "crude-oil",
			},
			attack_parameters = {
				type = "stream",
				cooldown = 4,
				range = 6,

				fire_penalty = 15,
				fluids =
				{
					{type = "crude-oil"},
				},
				fluid_consumption = 0.2,
				ammo_category = "flamethrower",
				ammo_type = {
					action = {
						type = "direct",
						action_delivery = {
							type = "stream",
							stream = "flamethrower-fire-stream",
							source_offset = {0.15, -0.5}
						}
					}
				},
			},
			trigger_target_mask = { "ground-unit" }
		}
		data:extend({unit})
	end
	local pump_pic = data.raw["optimized-decorative"]["brown-asterisk"].pictures[2]
	pump_pic.scale = 1.5
	pump_pic.tint = black_colors
	local initial_pump = {
		type = "pump",
		name = "hostile-trees-pump-roots",
		icon = "__base__/graphics/icons/tree-06-brown.png",
		max_health = 2000,
		energy_source = { type = "void" },
		flags = {
			"breaths-air",
			"hide-alt-info",
			"not-upgradable",
			"not-in-made-in",
		},
		selection_box = util.box_around({x = 0, y = 0}, 0.5),
		energy_usage = "1J",
		pumping_speed = 20,
		resistances = {
			{
				type = "fire",
				percent = 100
			},
		},
		fluid_box = {
			volume = 100,
			pipe_connections = {
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 1 },
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 2 },
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 3 },
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 4 },
				{ connection_type = "linked", flow_direction = "input", linked_connection_id = ROOT_PUMP_INPUT },
			},
			hide_connection_info = true,
			filter = "crude-oil",
		},
		animations = {
			north = pump_pic
		}
	}
	local pipe_roots = {
		type = "pipe",
		name = "hostile-trees-pipe-roots",
		icon = "__base__/graphics/icons/tree-06-brown.png",
		pictures = M.rootpictures(),
		flags = {
			"breaths-air",
			"hide-alt-info",
			"not-upgradable",
			"not-in-made-in",
		},
		selection_box = util.box_around({x = 0, y = 0}, 0.5),
		max_health = 1000,
		resistances = {		-- Roots are underground, dummy!
			{ type = "physical", percent = 80, decrease = 20 },
			{ type = "explosion", percent = 80, decrease = 20 },
			{ type = "fire", percent = 100 },
			{ type = "impact", percent = 100 },
			{ type = "acid", percent = 100 },
			{ type = "laser", percent = 100 },
			{ type = "electric", percent = 100 },
		},
		dying_explosion = "ground-explosion",
		horizontal_window_bounding_box = util.box_around({x = 0, y = 0}, 0.0),
		vertical_window_bounding_box = util.box_around({x = 0, y = 0}, 0.0),
		fluid_box = {
			volume = 20,
			pipe_connections = {
				{ connection_type = "linked", linked_connection_id = 1 },
				{ connection_type = "linked", linked_connection_id = 2 },
				{ connection_type = "linked", linked_connection_id = 3 },
				{ connection_type = "linked", linked_connection_id = 4 },
			},
			hide_connection_info = true,
			filter = "crude-oil",
		},
	}
	data:extend({initial_pump, pipe_roots})
	-- These uniquely identify trees.
	local p = table.deepcopy(pipe_roots)
	p.name = "hostile-trees-pipe-roots-vertex"
	data:extend({p})

	local oil_eater = {
		type = "generator",
		name = "hostile-trees-oil-eater",
		icon = "__base__/graphics/icons/tree-06-brown.png",
		pictures = M.rootpictures(),
		flags = {
			"breaths-air",
			"hide-alt-info",
			"not-upgradable",
			"not-in-made-in",
			"not-on-map",
		},
		max_health = 1000000,
		fluid_box = {
			volume = 100,
			pipe_connections = {
				{ connection_type = "linked", linked_connection_id = OIL_EATER },
			},
			hide_connection_info = true,
			filter = "crude-oil",
		},
		energy_source = {
			type = "electric",
			usage_priority = "primary-output",
			render_no_power_icon = false,
			render_no_network_icon = false,
		},
		fluid_usage_per_tick = 1 / 72,
		scale_fluid_usage = false,
		maximum_temperature = 1000,
		effectivity = 0.001,
	}

	for level=1,40 do
		oil_eater = table.deepcopy(oil_eater)
		oil_eater.name = M.oil_eater_name(level)
		oil_eater.fluid_usage_per_tick = oil_eater.fluid_usage_per_tick * 1.2
		data:extend({oil_eater})
	end
end

return M
