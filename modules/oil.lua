local util = require("modules/util")
local tree_images = require("modules/tree_images")

local M = {}

function M.data_stage()

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

function M.get_free_connection(root)
	local box = root.fluidbox
	for i=1,4 do
		local e = box.get_linked_connection(i)
		if e == nil then
			return i
		end
	end
	return nil
end

function M.try_connect(one, two)
	if one == nil or two == nil then return false end
	local pc = M.get_free_connection(one)
	local cc = M.get_free_connection(two)
	if cc == nil or pc == nil then return false end
	one.fluidbox.add_linked_connection(pc, two, cc)
	return true
end

function M.spawn_oil_tree(tree, pipe)
	if storage.oil_trees[tree.name] == nil then return nil end
	local name = M.make_oil_tree_name{
		name = tree.name,
		variation = tree.graphics_variation,
	}

	local p = pipe.position
	local off = {
		x = p.x + math.random(-20, 20),
		y = p.y + math.random(-20, 20),
	}

	local unit_dir = { x = 0, y = 1 }
	local rand_dir = util.rotate(unit_dir, math.random() * 6.283)
	local rand_dist = math.random() * 20
	local off = {
		x = p.x + rand_dir.x * rand_dist,
		y = p.y + rand_dir.y * rand_dist
	}

	local initial_pump = tree.surface.create_entity{
			name = "hostile-trees-pump-roots",
			position = p,
			force = "enemy",
	}
	local previous_thing = tree.surface.create_entity{
			name = "hostile-trees-pipe-roots",
			position = p,
			force = "enemy",
	}

	while util.dist2(p, off) >= 1 do
		if previous_thing == nil then return end
		p.x = p.x + rand_dir.x
		p.y = p.y + rand_dir.y
		local current_thing = tree.surface.create_entity{
			name = "hostile-trees-pipe-roots",
			position = p,
			force = "enemy",
		}
		if current_thing == nil then return end
		if not M.try_connect(previous_thing, current_thing) then return end
		previous_thing = current_thing
	end

	local current_thing = tree.surface.create_entity{
		name = name,
		position = off,
		force = "enemy",
	}
	M.try_connect(previous_thing, current_thing)
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
			fluid_buffer_size = 300,
			fluid_buffer_input_flow = 300 / 60 / 5,
			activation_buffer_ratio = 0.1,
			fluid_box = {
				volume = 100,
				hide_connection_info = true,
				pipe_connections = {
					{ direction = defines.direction.north, position = {0.0, 0.0} },
					{ direction = defines.direction.south, position = {0.0, 0.0} },
					{ direction = defines.direction.east, position = {0.0, 0.0} },
					{ direction = defines.direction.west, position = {0.0, 0.0} },
				}
			},
			attack_parameters = {
				type = "stream",
				cooldown = 4,
				range = 1,

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
		energy_usage = "0J",
		pumping_speed = 1200,
		resistances = {
			{
				type = "fire",
				percent = 100
			},
		},
		fluid_box = {
			volume = 100,
			pipe_connections = {
				{ direction = defines.direction.north, position = {0.0, 0.0}, flow_direction = "input" },
				{ direction = defines.direction.south, position = {0.0, 0.0}, flow_direction = "input"  },
				{ direction = defines.direction.east, position = {0.0, 0.0}, flow_direction = "input" },
				{ direction = defines.direction.west, position = {0.0, 0.0}, flow_direction = "input" },
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 1 },
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 2 },
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 3 },
				{ connection_type = "linked", flow_direction = "output", linked_connection_id = 4 },
			},
			hide_connection_info = false
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
		max_health = 100,
		resistances = {
			{
				type = "fire",
				percent = 100
			},
		},
		collision_box = util.box_around({x = 0, y = 0}, 0.1),
		horizontal_window_bounding_box = util.box_around({x = 0, y = 0}, 0.5),
		vertical_window_bounding_box = util.box_around({x = 0, y = 0}, 0.5),
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		fluid_box = {
			volume = 100,
			pipe_connections = {
				{ connection_type = "linked", linked_connection_id = 1 },
				{ connection_type = "linked", linked_connection_id = 2 },
				{ connection_type = "linked", linked_connection_id = 3 },
				{ connection_type = "linked", linked_connection_id = 4 },
			},
			hide_connection_info = false
		},
	}
	data:extend({initial_pump, pipe_roots})
end

return M
