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

function M.spawn_oil_tree(tree, pipe)
	if storage.oil_trees[tree.name] == nil then return nil end
	local name = M.make_oil_tree_name{
		name = tree.name,
		variation = tree.graphics_variation,
	}
	tree.surface.create_entity{
		name = name,
		position = pipe.position,
		force = "enemy",
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
			collision_box = util.box_around({x = 0, y = 0}, 0.5),
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
					{ direction = defines.direction.northeast, position = {0.0, 0.0} },
					{ direction = defines.direction.northwest, position = {0.0, 0.0} },
					{ direction = defines.direction.southeast, position = {0.0, 0.0} },
					{ direction = defines.direction.southwest, position = {0.0, 0.0} },
				}
			},
			attack_parameters = {
				type = "stream",
				cooldown = 4,
				range = 30,

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
end

return M
