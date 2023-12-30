local stdlib_util = require("__core__/lualib/util")

local chunks = require("modules/chunks")
local area_util = require("modules/area_util")
local util = require("modules/util")
local tree_images = require("modules/tree_images")

local M = {}

local function add_mask(pos)
	local cx = math.floor(pos.x / 32)
	local cy = math.floor(pos.y / 32)
	local cs = global.chunks

	for i = cx - 1,cx + 1 do
		for j = cy - 1, cy + 1 do
			chunks.chunk_mask_inc(cs, i, j)
		end
	end
end

local function remove_mask(pos)
	local cx = math.floor(pos.x / 32)
	local cy = math.floor(pos.y / 32)
	local cs = global.chunks

	for i = cx - 1,cx + 1 do
		for j = cy - 1, cy + 1 do
			chunks.chunk_mask_dec(cs, i, j)
		end
	end
end

function M.try_to_hook_up_electricity(tree, electric)
	local surface = tree.surface
	local treepos = tree.position
	local pole = M.electrify_tree(tree)
	if pole == nil then
		return
	end

	-- connect_neighbour returns false if we're already connected and
	-- there's no way to find out connection status (?????)
	pole.disconnect_neighbour(electric)
	if not pole.connect_neighbour(electric) then
		pole.destroy()
		return
	end

	local electric = tree.surface.create_entity{
		name = "electric-tree-consumption",
		position = tree.position,
	}

	tree.destroy()
	local rid = script.register_on_entity_destroyed(pole)
	global.entity_destroyed_script_events[rid] = {
		action = "on_electric_tree_destroyed",
		pos = pole.position,
	}
	add_mask(pole.position)
end

function M.on_electric_tree_destroyed(e)
	remove_mask(e.pos)
end

function M.make_electric_tree_name(params)
		return "tree-electric-pole-" .. params.name .. "-" .. string.format("%03d", params.variation)
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
			flags = {
				"breaths-air",
				"hidden",
				"hide-alt-info",
				"not-upgradable",
				"not-in-made-in"
			},
			max_health = 150,
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
		}
		data:extend({unit})
	end
end

function M.electrify_tree(tree)
	if global.electric_trees[tree.name] == nil then return nil end
	local ent = tree.surface.create_entity{
		name = M.make_electric_tree_name{
			name = tree.name,
			variation = tree.graphics_variation,
		},
		position = tree.position,
	}
	return ent
end

return M
