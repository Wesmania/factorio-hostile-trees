local entity_sounds = require("__base__/prototypes/entity/sounds")

local M = {}

function M.can_generate_ent(tree_data)
	return tree_data.variations ~= nil
end

local function generate_ent_animation(tree_data, v, color, unit_type)
	local layers = {}

	if unit_type == "exp" and color ~= nil then
		-- Make it red
		if color ~= nil then
			color = {
				r = color.g,
				g = color.r,
				b = color.b,
				a = color.a
			}
		else
			color = {
				r = 1.0,
				g = 0.5,
				b = 0.5,
				a = 1.0,
			}
		end
	end

	local fixup_anim = function(a)
		a.direction_count = 1
		if a.hr_version ~= nil then
			a.hr_version.direction_count = 1
		end
	end

	local add_layer = function(l)
		if l.layers ~= nil then
			for ll in l.layers do
				fixup_anim(ll)
				layers[#layers + 1] = ll
			end
		else
			fixup_anim(l)
			layers[#layers + 1] = l
		end
	end

	local get_frame_count = function(l)
		if l.layers ~= nil then
			return l.layers[1].frame_count
		else
			return l.frame_count
		end
	end

	local for_each_anim = function(l, action)
		if l.layers ~= nil then
			for _, ll in pairs(l.layers) do
				action(ll)
				if ll.hr_version ~= nil then
					action(ll.hr_version)
				end
			end
		else
			action(l)
			if l.hr_version ~= nil then
				action(l.hr_version)
			end
		end
	end

	local adjust_frame_count = function(l, target)
		for_each_anim(l, function(v)
			v.frame_count = target
		end)
	end

	local set_tint = function(l, tint)
		for_each_anim(l, function(v)
			v.tint = tint
		end)
	end

	local s = table.deepcopy(v.trunk)
	adjust_frame_count(s, 1)
	add_layer(s)

	if v.leaves ~= nil then
		local ll = table.deepcopy(v.leaves)
		adjust_frame_count(ll, 1)
		set_tint(ll, color)
		add_layer(ll)
	end
	if v.overlay ~= nil then
		local ll = table.deepcopy(v.overlay)
		adjust_frame_count(ll, 1)
		add_layer(ll)
	end
	if v.shadow ~= nil then
		local s = table.deepcopy(v.shadow)
		adjust_frame_count(s, 1)
		add_layer(s)
	end

	return {
		layers = layers
	}
end

local ent_walk_sounds = {}
local s = entity_sounds
for _, t in ipairs({ s.plant, s.small_bush, s.big_bush }) do
	for _, tt in ipairs(t) do
		ent_walk_sounds[#ent_walk_sounds + 1] = {
			filename = tt.filename,
			volume = 0.4,
		}
	end
end

local function exploder_ammo_type(ent_data)
	return
	{
		category = "melee",
		target_type = "entity",
		action = {
			type = "direct",
			action_delivery = {
				type = "instant",
				source_effects = {
					type = "damage",
					affects_target = true,
					show_in_tooltip = false,
					damage = { amount = ent_data.max_health * 2 , type = "explosion"}
				},
				target_effects = {
					{
						type = "nested-result",
						action = {
							type = "area",
							radius = 3,
							force = "enemy",
							action_delivery = {
								type = "instant",
								target_effects = {
									type = "damage",
									damage = {
										amount = 10,
										type = "explosion",
									}
								}
							}
						}
					},
					{
						type = "create-entity",
						entity_name = "explosion",
					},
					{
						type = "create-entity",
						entity_name = "small-scorchmark",
						check_buildability = true,
					},
				}
			}
		}
	}
end

function M.generate_ent(tree_data, unit_type)
	local unit = table.deepcopy(data.raw["unit"]["small-biter"])
	unit.icon = tree_data.icon
	unit.corpse = tree_data.corpse
	unit.dying_explosion = nil
	unit.dying_sound = nil
	unit.working_sound = nil
	unit.running_sound_animation_positions = {120,}		-- TODO do specific values do anything?
	unit.walking_sound = ent_walk_sounds
	unit.water_reflection = nil
	unit.attack_parameters.sound = nil
	unit.collision_box = tree_data.collision_box

	if unit_type == "exp" then
		unit.attack_parameters.ammo_type = exploder_ammo_type(unit)
	end

	for i, variation in ipairs(tree_data.variations) do
		local vunit = table.deepcopy(unit)
		local anim = generate_ent_animation(tree_data, variation, tree_data.colors[i], unit_type)
		vunit.attack_parameters.animation = anim
		vunit.run_animation = anim
		vunit.name = M.make_ent_entity_name{
			name = tree_data.name,
			variation = i,
			unit_variant = unit_type,
		}
		data:extend({vunit})
	end
end

function M.split_ent_entity_name(name)
		if string.sub(name, 1, 18) ~= "hostile-trees-ent-" then return nil end
		local l = string.len(name)
		return {
			name = string.sub(name, 19, l - 8),
			variation = tonumber(string.sub(name, l - 7, l - 4)),
			unit_variant = string.sub(name, l - 3, l),
		}
end

function M.make_ent_entity_name(params)
		return "hostile-trees-ent-" .. params.name .. "-" .. string.format("%03d", params.variation) .. "-" .. params.unit_variant
end

M.spawnrates = {
	{
		unit = "ent",
		spawn_points = {
			{
				evolution_factor = 0.0,
				weight = 1.0,
			},
			{
				evolution_factor = 1.0,
				weight = 0.3,
			},
		},
	},
	{
		unit = "exp",
		spawn_points = {
			{
				evolution_factor = 0.2,
				weight = 0.0,
			},
			{
				evolution_factor = 1.0,
				weight = 0.7,
			},
		},
	},
}

return M
