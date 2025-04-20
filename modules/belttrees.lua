local tree_images = require("modules/tree_images")
local util = require("modules/util")
local area_util = require("modules/area_util")

local proto_base = {
    type = "car",
    -- name = "tank",
    -- icon = "__base__/graphics/icons/tank.png",
    icon_size = 64,
    icon_mipmaps = 4,
    flags = {"placeable-off-grid", "breaths-air"},
    max_health = 50,
    --corpse = "tank-remnants",
    energy_per_hit_point = 1,
    --collision_box = {{-0.9, -1.3}, {0.9, 1.3}},
    --selection_box = {{-0.9, -1.3}, {0.9, 1.3}},
    --drawing_box = {{-1.8, -1.8}, {1.8, 1.5}},
    braking_power = "1kW",
    burner = {
	    type = "void",
	    fuel_inventory_size = 0,
	    render_no_power_icon = false,
	    render_no_network_icon = false,
    },
    energy_source = { type = "void" },
    consumption = "1kW",
    -- animation = { layers = ... },
    rotation_speed = 0.0035,
    friction_force = 0.001,
    effectivity = 1,
    weight = 20000,
    inventory_size = 0,
    --water_reflection = car_reflection(1.2)
  }

local M = {}

function M.make_belt_tree_name(params)
	return "tree-belt-" .. params.name .. "-" .. string.format("%03d", params.variation)
end

function M.is_belt_tree_name(name)
	return string.sub(name, 1, 10) == "tree-belt-"
end

function M.split_belt_tree_name(name)
		if string.sub(name, 1, 10) ~= "tree-belt-" then return nil end
		local l = string.len(name)
		return {
			name = string.sub(name, 11, l - 4),
			variation = tonumber(string.sub(name, l - 3, l)),
		}
end

function M.generate_belt_tree(tree_data)
	for i, variation in ipairs(tree_data.variations) do
		local unit = table.deepcopy(proto_base)

		unit.name = M.make_belt_tree_name{
			name = tree_data.name,
			variation = i,
		}
		unit.localised_name = {"entity-name.hostile-trees-belt-tree"}
		unit.corpse = tree_data.corpse
		unit.collision_box = tree_data.collision_box
		unit.selection_box = tree_data.selection_box
		unit.drawing_box = tree_data.drawing_box
		unit.animation = tree_images.generate_tree_image(tree_data, variation, tree_data.colors[i])
		unit.water_reflection = tree_data.water_reflection,
		data:extend({unit})
	end
end

function M.spit_on_belt(tree, belt)
	M.do_spit_on_belt(tree.name, tree.graphics_variation, tree.surface, tree.position, belt)
end

function M.do_spit_on_belt(name, graphics_variation, surface, position, belt)
	-- FIXME copypasta check
	if graphics_variation == nil then return end
	local s = surface.create_entity{
		name = 'belt-tree-spawner-projectile',
		position = position,
		source = position,
		target = belt,
	}
	if s ~= nil then
		local rid = script.register_on_object_destroyed(s)
		storage.entity_destroyed_script_events[rid] = {
			action = "on_belttree_spawning_spit_landed",
			tree_name = name,
			tree_variation = graphics_variation,
			target = belt,
		}
	end
end

function M.on_belttree_spawning_spit_landed(event)
	local target = event.target
	if not target.valid then return end
	local tpos = target.position
	local surface = target.surface
	local tree_name = event.tree_name
	local tree_variation = event.tree_variation

	local belttree_name = M.make_belt_tree_name{
		name = tree_name,
		variation = tree_variation,
	}

	tpos.x = tpos.x - 0.2 + math.random() * 0.4
	tpos.y = tpos.y - 0.2 + math.random() * 0.4

	-- Check for collision.
	local nc = surface.find_non_colliding_position_in_box(belttree_name, util.box_around(tpos, 0.1), 0.09)
	if nc == nil then return end

	local s = surface.create_entity{
		name = belttree_name,
		position = nc,
	}
	M.add_new_belt_tree({
		bt = s,
		tree_name = tree_name,
		tree_variation = tree_variation,
	})
end

function M.do_spit_on_belt_final(name, graphics_variation, surface, position, belt)
	-- FIXME copypasta check
	if graphics_variation == nil then return end
	local s = surface.create_entity{
		name = 'belt-tree-final-projectile',
		position = position,
		source = position,
		target = belt,
	}
	if s ~= nil then
		local rid = script.register_on_object_destroyed(s)
		storage.entity_destroyed_script_events[rid] = {
			action = "on_belttree_final_spit_landed",
			tree_name = name,
			tree_variation = graphics_variation,
			target = belt,
			surface = surface,
		}
	end
end

function M.on_belttree_final_spit_landed(event)
	local tpos = event.target
	local surface = event.surface
	local tree_name = event.tree_name
	local tree_variation = event.tree_variation

	local s = surface.create_entity{
		name = tree_name,
		position = tpos
	}
	if s ~= nil then
		s.graphics_variation = tree_variation
	end
end

function M.jump_box(position, belt_direction)
	local d = defines.direction
	local off = 2.5
	local width = 5
	local depth = 2.5
	local dx
	local dy
	local hx
	local xy
	if belt_direction == d.north then
		dx = 0
		dy = -off
	elseif belt_direction == d.south then
		dx = 0
		dy = off
	elseif belt_direction == d.east then
		dx = off
		dy = 0
	elseif belt_direction == d.west then
		dx = -off
		dy = 0
	end
	if dx == 0 then
		hx = width
		hy = depth
	else
		hx = depth
		hy = width
	end

	position.x = position.x + dx
	position.y = position.y + dy

	return {
		left_top = {
			x = position.x - hx,
			y = position.y - hy,
		},
		right_bottom = {
			x = position.x + hx,
			y = position.y + hy,
		},
	}
end

function M.belttree_jump(bt_data)
	local belttree = bt_data.bt
	if not belttree.valid then return end
	if math.random() < 0.75 then
		-- Jump to another belt. Try not to jump backwards.
		local belt_we_are_on = area_util.get_random_belt(belttree.surface, util.box_around(belttree.position, 0.3))
		local box
		if belt_we_are_on ~= nil then
			box = M.jump_box(belttree.position, belt_we_are_on.direction)
		else
			box = util.box_around(belttree.position, 5)
		end
		local belt = area_util.get_random_belt(belttree.surface, box)
		if belt == nil then return end
		M.do_spit_on_belt(bt_data.tree_name, bt_data.tree_variation, belttree.surface, belttree.position, belt)
	else
		local rdist = 3 + math.random() * 2
		local angle = math.random() * math.pi * 2
		local dx = math.sin(angle) * rdist
		local dy = math.cos(angle) * rdist
		local pos = belttree.position
		pos.x = pos.x + dx
		pos.y = pos.y + dy
		M.do_spit_on_belt_final(bt_data.tree_name, bt_data.tree_variation, belttree.surface, belttree.position, pos)
	end
	belttree.destroy()
end

function M.fresh_setup()
	storage.belttrees = {
		travelling = {},
		jumping = {
			dict = {},
			list = {},
		},
	}
end

function M.add_new_belt_tree(bt_data)
	bt_data.unit_number = bt_data.bt.unit_number
	-- Have the tree travel for at least 10 seconds
	local active_time = math.floor(game.tick / 60) + 10
	local t = storage.belttrees.travelling
	if t[active_time] == nil then
		t[active_time] = {}
	end
	local lst = t[active_time]
	lst[#lst + 1] = bt_data
end

-- Needs to be called once a second or else it will leak!
function M.mature_travelling_belt_trees()
	local now = math.floor(game.tick / 60)
	local t = storage.belttrees.travelling
	if t[now] == nil then return end
	local j = storage.belttrees.jumping
	local count = #t[now]
	for _, bt_data in ipairs(t[now]) do
		if bt_data.bt.valid then
			util.ldict_add(j, bt_data.unit_number, bt_data)
		end
	end
	t[now] = nil
end

function M.check_jumping_belt_trees()
	local j = storage.belttrees.jumping
	local count = #j.list / 600	-- FIXME
	while count > 1 or math.random() < count do
		count = count - 1
		local bt_data = util.ldict_get_random(j)
		if bt_data == nil then return end
		util.ldict_remove(j, bt_data.unit_number)
		if bt_data.bt.valid then
			M.belttree_jump(bt_data)
		end
	end
end

return M
