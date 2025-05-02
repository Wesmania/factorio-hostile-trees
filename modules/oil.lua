local util = require("modules/util")
local tree_images = require("modules/tree_images")

local M = {}


-- Randomly selected from between 3 to 4 billion. Let's hope it doesn't collide.
local SPECIAL_OUTPUT_PIPE = 3521853045
local OIL_EATER = 10

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

local function new_tree(tree)
	return {
		tree = tree,
	}
end

local function new_oil_tree_web(pump)
	return {
		pump = nil,
		trees = {}
	}
end

function M.fresh_setup()
	storage.oil_tree_state = {
		trees = {
			dict = {},
			list = {},
		},
		pumps = {
			dict = {},
			list = {},
		},
	}
end

function M.register_edge(edge)
	for _, unit in ipairs(edge) do
		local rid = script.register_on_object_destroyed(unit)
		storage.entity_destroyed_script_events[rid] = {
			action = "on_oil_edge_destroyed",
			edge = edge,
		}
	end
end

function M.on_oil_edge_destroyed(e)
	if e.edge == nil then return end
	local l = e.edge
	e.edge = nil
	for _, unit in ipairs(l) do
		if unit.valid then
			unit.die()
		end
	end
end

function M.register_tree(tree)
	util.ldict_add(storage.oil_tree_state.trees, tree.tree.unit_number, tree)
	return tree.tree.unit_number
end

function M.destroy_tree(num)
	local tree = util.ldict_get(storage.oil_tree_state.trees, num)
	M.destroy_oil_tree(tree)
	util.ldict_remove(storage.oil_tree_state.trees, num)
end

function M.register_pump(pump)
	util.ldict_add(storage.oil_tree_state.pumps, pump.unit_number, { item = pump })
	return pump.unit_number
end

function M.destroy_pump(num)
	local pump = util.ldict_get(storage.oil_tree_state.pumps, num).item
	if pump.valid then
		pump.destroy()
	end
	util.ldict_remove(storage.oil_tree_state.pumps, num)
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
		d.destroy()
	end
end

function M.make_oil_tree(tree_info)
	if storage.oil_trees[tree_info.name] == nil then return nil end
	local name = M.make_oil_tree_name(tree_info)
	local oil_tree = tree_info.surface.create_entity{
		name = name,
		position = tree_info.position,
		force = "enemy",
	}
	if oil_tree == nil then return nil end

	local oil_eater = tree_info.surface.create_entity{
		name = "hostile-trees-oil-eater",
		position = tree_info.position,
		force = "enemy",
	}
	if oil_eater == nil then
		oil_tree.destroy()
		return nil
	end
	local t = M.try_connect(oil_tree, oil_eater, OIL_EATER, OIL_EATER)
	assert(t == true)
	return {
		tree = oil_tree,
		eater = oil_eater,
	}
end

function M.destroy_oil_tree(tree)
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

function M.connect_oil_tree_to_pipe(oil_tree, pipe)
	if not pipe.valid or not oil_tree.valid then return end

	local p = pipe.position
	local oil_pos = oil_tree.position

	local deletables = {}
	local initial_pump = oil_tree.surface.create_entity{
			name = "hostile-trees-pump-roots",
			position = p,
			force = "enemy",
	}
	if initial_pump == nil then free(deletables) ; return end
	if not M.try_connect(pipe, initial_pump, SPECIAL_OUTPUT_PIPE, 5) then free(deletables) ; return end
	deletables[#deletables + 1] = initial_pump

	local pipe_edge = M.draw_pipe_edge(oil_tree.surface, p, oil_pos)
	if pipe_edge == nil then free(deletables) ; return end
	for _, pipe in ipairs(pipe_edge) do
		deletables[#deletables + 1] = pipe
	end

	local pipe_end = pipe_edge[1]
	local tree_end = pipe_edge[#pipe_edge]

	if not M.try_connect(initial_pump, pipe_end) then free(deletables) ; return end
	if not M.try_connect(oil_tree, tree_end) then free(deletables) ; return end

	return {
		edge = pipe_edge,
		pump = initial_pump,
	}
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

	local connection = M.connect_oil_tree_to_pipe(oil_tree.tree, pipe)
	if connection == nil then
		M.destroy_oil_tree(oil_tree)
		return
	end
	tree.destroy()

	M.register_edge(connection.edge)
	M.register_pump(connection.pump)
	M.register_tree(oil_tree)
end

function M.rootpictures()
	local pics_from = data.raw["optimized-decorative"]["brown-hairy-grass"]
	local pic = pics_from.pictures[1]
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
			max_health = 250,
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
			pictures = tree_images.generate_tree_image(tree_data, variation, tree_data.colors[i]),
			folded_animation = {
				north = tree_images.generate_tree_image(tree_data, variation, tree_data.colors[i]),
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
	local initial_pump = {
		type = "pump",
		name = "hostile-trees-pump-roots",
		icon = "__base__/graphics/icons/tree-06-brown.png",
		max_health = 100,
		collision_box = util.box_around({x = 0, y = 0}, 0.1),
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		energy_source = { type = "void" },
		flags = {
			"breaths-air",
			"hide-alt-info",
			"not-upgradable",
			"not-in-made-in",
		},
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
				{ connection_type = "linked", flow_direction = "input", linked_connection_id = 5 },
			},
			hide_connection_info = false,
			filter = "crude-oil",
		},
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
		max_health = 500,
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
		collision_box = util.box_around({x = 0, y = 0}, 0.1),
		horizontal_window_bounding_box = util.box_around({x = 0, y = 0}, 0.5),
		vertical_window_bounding_box = util.box_around({x = 0, y = 0}, 0.5),
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		fluid_box = {
			volume = 20,
			pipe_connections = {
				{ connection_type = "linked", linked_connection_id = 1 },
				{ connection_type = "linked", linked_connection_id = 2 },
				{ connection_type = "linked", linked_connection_id = 3 },
				{ connection_type = "linked", linked_connection_id = 4 },
			},
			hide_connection_info = false,
			filter = "crude-oil",
		},
	}
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
		fluid_usage_per_tick = 1 / 60,
		scale_fluid_usage = false,
		maximum_temperature = 1000,
		effectivity = 0.001,
	}

	data:extend({initial_pump, pipe_roots, oil_eater})
end

return M
