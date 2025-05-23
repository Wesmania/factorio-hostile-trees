local tree_images = require("modules/tree_images")
require("__base__/prototypes/entity/spitter-animations")

local ent_balance = {
	ent = {		-- Should be between small and medium biter.
		max_health = 30,
		healing_per_tick = 0.01,
		movement_speed = 0.2,
		resistances = {
			{
				type = "physical",
				decrease = 2,
				percent = 10,
			},
			{
				type = "explosion",
				percent = 10,
			},
			{
				type = "fire",
				percent = 90,
			},
		},
	},
	exp = {		-- Should be between medium and large biter.
		max_health = 30,	-- Low health but high resistances so that laser turrets and fire demolish it.
		healing_per_tick = 0.01,
		movement_speed = 0.25,
		resistances = {
			{
				type = "physical",
				decrease = 4,
				percent = 85,
			},
			{
				type = "explosion",
				percent = 99,
			},
			{
				type = "acid",
				percent = 80,
			},
			{
				type = "poison",
				percent = 90,
			},
		},
		explosion = {
			radius = 4,
			damage = 60,
		}
	},
	beh = {		-- Should be between medium and large biter.
		max_health = 300,	-- Strong and has great resistances, but weak to explosions. Arm these landmines!
		healing_per_tick = 0.10,
		movement_speed = 0.1,
		resistances = {
			{
				type = "physical",
				decrease = 8,
				percent = 85,
			},
			{
				type = "explosion",
				decrease = 50,
			},
			{
				type = "acid",
				percent = 90,
			},
			{
				type = "poison",
				percent = 60,
			},
			{
				type = "laser",
				percent = 96,
			},
			{
				type = "fire",
				percent = 96,
			},
			{
				type = "electric",
				percent = 80,
			},
		},
		-- We'd like to re-use spitter projectile here, but base file
		-- makes a require() that makes it impossible to import.
		-- So, let's just copypaste.
		attack_parameters = function() return {
			type = "stream",
			ammo_category = "biological",
			cooldown = 100,
			cooldown_deviation = 0.15,
			range = 10,
			range_mode = "bounding-box-to-bounding-box",
			min_attack_distance = 2,
			damage_modifier = 10,
			warmup = 30,
			projectile_creation_parameters = spitter_shoot_shiftings(1, 20),
			use_shooter_direction = true,
			lead_target_for_projectile_speed = 0.2* 0.75 * 1.5 *1.5, -- this is same as particle horizontal speed of flamethrower fire stream
			ammo_type = {
				category = "biological",
				action = {
					{
						type = "direct",
						action_delivery = {
							type = "stream",
							stream = "acid-stream-spitter-big",
						}
					},
					{
						type = "direct",
						action_delivery = {
							type = "stream",
							stream = "flamethrower-fire-stream",
						}
					}
				}
			},
			cyclic_sound = {
				begin_sound = {
					{ filename = "__base__/sound/creatures/spitter-spit-start-1.ogg", volume = 0.27 },
					{ filename = "__base__/sound/creatures/spitter-spit-start-2.ogg", volume = 0.27 },
					{ filename = "__base__/sound/creatures/spitter-spit-start-3.ogg", volume = 0.27 },
					{ filename = "__base__/sound/creatures/spitter-spit-start-4.ogg", volume = 0.27 }
				},
				middle_sound = {
					{ filename = "__base__/sound/fight/flamethrower-mid.ogg", volume = 0 }
				},
				end_sound = {
					{ filename = "__base__/sound/creatures/spitter-spit-end-1.ogg", volume = 0 }
				}
			},
		} end
	},
}

local function apply_ent_balance(unit, type)
	local params = ent_balance[type]
	unit.max_health = params.max_health
	unit.healing_per_tick = params.healing_per_tick
	unit.resistances = params.resistances
	unit.movement_speed = params.movement_speed
end

local M = {}

function M.can_generate_ent(tree_data)
	return tree_data.variations ~= nil and string.find(tree_data.name, "dead", 1, true) == nil
end

local function generate_ent_animation(tree_data, v, color, unit_type)
	if unit_type == "exp" then
		-- Make it red
		if color ~= nil then
			local newcolor = {
				r = (0.9 * 255) + color.g * 0.1,
				g = 0.2 * color.r,
				b = color.b,
				a = color.a
			}
			color = newcolor
		else
			color = {
				r = 0.9,
				g = 0.2,
				b = 0.2,
				a = 1.0,
			}
		end
	elseif unit_type == "beh" then
		-- Make it yellow
		if color ~= nil then
			local avg = (color.r + color.g) / 2
			local newcolor = {
				r = (0.9 * 255) + avg * 0.1,
				g = (0.6 * 255) + avg * 0.1,
				b = color.b,
				a = color.a
			}
			color = newcolor
		else
			color = {
				r = 0.9,
				g = 0.6,
				b = 0.2,
				a = 1.0,
			}
		end
	end

	return tree_images.generate_tree_image(tree_data, v, color)
end

local function exploder_ammo_type(ent_data)
	local params = ent_balance.exp.explosion
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
					damage = { amount = ent_data.max_health * 2 , type = "fire"}
				},
				target_effects = {
					{
						type = "nested-result",
						action = {
							type = "area",
							radius = params.radius,
							force = "enemy",
							action_delivery = {
								type = "instant",
								target_effects = {
									type = "damage",
									damage = {
										amount = params.damage,
										type = "explosion",
									}
								}
							}
						}
					},
					{
						type = "create-entity",
						entity_name = "big-explosion",
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

function M.generate_ent(tree_data, unit_type, walk_sounds)
	local balance = ent_balance[unit_type]

	local unit = table.deepcopy(data.raw["unit"]["small-biter"])
	unit.icon = tree_data.icon
	-- Work around some mods with no icons
	if unit.icon == nil then
		unit.icon = "__base__/graphics/icons/tree-06-brown.png"
	end
	unit.corpse = tree_data.corpse
	unit.dying_explosion = nil
	unit.dying_sound = nil
	unit.working_sound = nil
	unit.running_sound_animation_positions = {120,}		-- TODO do specific values do anything?
	unit.walking_sound = walk_sounds
	unit.water_reflection = tree_data.water_reflection
	unit.collision_box = tree_data.collision_box
	unit.localised_name = {"entity-name.hostile-trees-ent-" .. unit_type}
	unit.localised_description = {"entity-description.hostile-trees-ent-" .. unit_type}

	if balance.attack_parameters ~= nil then
		unit.attack_parameters = balance.attack_parameters()
	end
	unit.attack_parameters.sound = nil

	apply_ent_balance(unit, unit_type)
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

function M.can_make_ents(params)
	return game.forces["enemy"].get_evolution_factor("nauvis") >= 0.1
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
				weight = 0.15,
			},
		},
	},
	{
		unit = "exp",
		spawn_points = {
			{
				evolution_factor = 0.25,
				weight = 0.0,
			},
			{
				evolution_factor = 0.6,
				weight = 0.7,
			},
			{
				evolution_factor = 1.0,
				weight = 0.2,
			},
		},
	},
	{
		unit = "beh",
		spawn_points = {
			{
				evolution_factor = 0.6,
				weight = 0.0,
			},
			{
				evolution_factor = 1.0,
				weight = 0.6,
			},
		},
	},
}

function M.make_walking_sounds()
	local s = require("__base__/prototypes/tile/tile-sounds")
	local ent_walk_sounds = {
		volume = 0.4,
		variations = {},
	}
	for _, t in ipairs({ s.walking.plant, s.walking.small_bush, s.walking.big_bush }) do
		for _, tt in ipairs(t.variations) do
			local v = ent_walk_sounds.variations
			v[#v + 1] = tt
		end
	end
	return ent_walk_sounds
end

function M.datastage(data)
	local sounds = M.make_walking_sounds()
	for _, tree in pairs(data.raw["tree"]) do
		for _, ent_type in pairs(M.spawnrates) do
			if M.can_generate_ent(tree) then
				M.generate_ent(tree, ent_type.unit, ent_walk_sounds)
			end
		end
	end
end

return M
