local stdlib_util = require("__core__/lualib/util")
local ents = require("modules/ent_generation")

local function edit_spitter_projectile(p, damage_mult)
	for _, e in pairs(p.initial_action) do
		if e.type == "area" then
			for _, ef in pairs(e.action_delivery.target_effects) do
				if ef.type == "damage" then
					ef.damage.amount = ef.damage.amount * damage_mult
				end
			end
		end
	end
end

local tree_spitter_projectile = table.deepcopy(data.raw["stream"]["acid-stream-worm-small"])
tree_spitter_projectile.name = "tree-spitter-projectile"
edit_spitter_projectile(tree_spitter_projectile, 30)

data:extend({tree_spitter_projectile})

local ts = table.deepcopy(data.raw["stream"]["acid-stream-worm-small"])
ts.initial_action = {
	{
		type = "direct",
		action_delivery = {
			type = "instant",
			target_effects = {
				type = "script",
				effect_id = "tree-spawner-projectile",
			}
		}
	}
}
ts.name = "tree-spawner-projectile"
data:extend({ts})

function fake_biter_sounds(name, soundlist)
	data:extend({
		{
			type = "explosion",
			name = name,
			flags = {"not-on-map", "placeable-off-grid"},
			sound = {
				aggregation = { max_count = 3, remove = false },
				variations = soundlist,
			},
			animations = stdlib_util.empty_sprite(),
		},
	})
end

local sounds = require("__base__/prototypes/entity/sounds")

fake_biter_sounds("fake-biter", sounds.biter_roars(0.5))

local tree_poison = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
tree_poison.name = "tree-poison-cloud"

-- Remove capsule explosion sound
for _, i in pairs(tree_poison.created_effect) do
	if i.action_delivery.target_effects ~= nil then
		local effects = {}
		for _, j in pairs(i.action_delivery.target_effects) do
			if j.type ~= "play-sound" then
				effects[#effects + 1] = j
			end
		end
		i.action_delivery.target_effects = effects
	end
end

-- Only make poison affect the player
tree_poison.action.action_delivery.target_effects.action.force = "enemy"

data:extend({tree_poison})

for _, tree in pairs(data.raw["tree"]) do
	for _, ent_type in pairs(ents.spawnrates) do
		if ents.can_generate_ent(tree) then
			ents.generate_ent(tree, ent_type.unit)
		end
	end
end

-- Volatile saplings

-- Copied and modified grenade settings
data:extend({{
    type = "projectile",
    name = "volatile-sapling",
    flags = {"not-on-map"},
    acceleration = 0.005,
    action =
    {
      {
        type = "direct",
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            {
              type = "create-entity",
              entity_name = "massive-explosion"
            },
            {
              type = "create-entity",
              entity_name = "small-scorchmark-tintable",
              check_buildability = true
            },
            {
              type = "destroy-decoratives",
              from_render_layer = "decorative",
              to_render_layer = "object",
              include_soft_decoratives = true, -- soft decoratives are decoratives with grows_through_rail_path = true
              include_decals = false,
              invoke_decorative_trigger = true,
              decoratives_with_trigger_only = false, -- if true, destroys only decoratives that have trigger_effect set
              radius = 2.25 -- large radius for demostrative purposes
            }
          }
        }
      },
      {
        type = "area",
        radius = 4.5,
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            {
              type = "damage",
              damage = {amount = 500, type = "explosion"}	-- Enough to destroy a car
            },
            {
              type = "create-entity",
              entity_name = "explosion"
            }
          }
        }
      }
    },
    animation =
    {
      filename = "__base__/graphics/entity/tree/06/tree-06-a-trunk.png",
      draw_as_glow = true,
      frame_count = 1,
      line_length = 1,
      animation_speed = 0.250,
      width = 60,
      height = 62,
      shift = util.by_pixel(1, 1),
      priority = "high",
      hr_version =
      {
        filename = "__base__/graphics/entity/tree/06/hr-tree-06-a-trunk.png",
        draw_as_glow = true,
        frame_count = 1,
        line_length = 1,
        animation_speed = 0.250,
        width = 118,
        height = 120,
        shift = util.by_pixel(0.5, 0.5),
        priority = "high",
        scale = 0.5
      }

    },
    shadow =
    {
      filename = "__base__/graphics/entity/tree/06/tree-06-a-shadow.png",
      frame_count = 4,
      line_length = 4,
      animation_speed = 0.250,
      width = 170,
      height = 76,
      shift = util.by_pixel(2, 6),
      priority = "high",
      draw_as_shadow = true,
      hr_version =
      {
        filename = "__base__/graphics/entity/tree/06/hr-tree-06-a-shadow.png",
        frame_count = 4,
        line_length = 4,
        animation_speed = 0.250,
        width = 338,
        height = 148,
        shift = util.by_pixel(2, 6),
        priority = "high",
        draw_as_shadow = true,
        scale = 0.5
      }
    }
  }
})

data:extend({{
    type = "capsule",
    name = "volatile-sapling",
    icon = "__base__/graphics/icons/tree-06-brown.png",
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "trees",
    stack_size = 1,
    capsule_action = {
	    type = "throw",
	    attack_parameters = {
		    type = "projectile",
		    activation_type = "throw",
		    ammo_category = "grenade",
		    cooldown = 30,
		    projectile_creation_distance = 0.6,
		    range = 15,
		    ammo_type = {
			    category = "grenade",
			    target_type = "position",
			    action = {
				    {
					    type = "direct",
					    action_delivery = {
						    type = "projectile",
						    projectile = "volatile-sapling",
						    starting_speed = 0.3
					    }
				    },
			    }
		    }
	    }
    }
}})

data:extend({{
	type = "electric-pole",
	name = "tree-electric-pole",
	icon = "__base__/graphics/icons/big-electric-pole.png",
	icon_size = 64, icon_mipmaps = 4,
	flags = {"placeable-neutral", "breaths-air", "not-deconstructable", "not-repairable", "not-blueprintable", "hidden", "hide-alt-info", "not-upgradable", "not-in-made-in"},
	max_health = 150,
	corpse = "big-electric-pole-remnants",
	dying_explosion = "big-electric-pole-explosion",
	collision_box = {{-0.65, -0.65}, {0.65, 0.65}},
	selection_box = {{-1, -1}, {1, 1}},
	drawing_box = {{-1, -3}, {1, 0.5}},
	maximum_wire_distance = 30,
	supply_area_distance = 0,
	pictures =
	{
		layers =
		{
			{
				filename = "__base__/graphics/entity/big-electric-pole/big-electric-pole.png",
				priority = "extra-high",
				width = 76,
				height = 156,
				direction_count = 4,
				shift = stdlib_util.by_pixel(1, -51),
				hr_version =
				{
					filename = "__base__/graphics/entity/big-electric-pole/hr-big-electric-pole.png",
					priority = "extra-high",
					width = 148,
					height = 312,
					direction_count = 4,
					shift = stdlib_util.by_pixel(0, -51),
					scale = 0.5
				}
			},
			{
				filename = "__base__/graphics/entity/big-electric-pole/big-electric-pole-shadow.png",
				priority = "extra-high",
				width = 188,
				height = 48,
				direction_count = 4,
				shift = stdlib_util.by_pixel(60, 0),
				draw_as_shadow = true,
				hr_version =
				{
					filename = "__base__/graphics/entity/big-electric-pole/hr-big-electric-pole-shadow.png",
					priority = "extra-high",
					width = 374,
					height = 94,
					direction_count = 4,
					shift = stdlib_util.by_pixel(60, 0),
					draw_as_shadow = true,
					scale = 0.5
				}
			}
		}
	},
	connection_points =
	{
		{
			shadow =
			{
				copper = stdlib_util.by_pixel_hr(245.0, -34.0),
			},
			wire =
			{
				copper = stdlib_util.by_pixel_hr(0, -246.0),
			}
		},
		{
			shadow =
			{
				copper = stdlib_util.by_pixel_hr(279.0, -24.0),
			},
			wire =
			{
				copper = stdlib_util.by_pixel_hr(34.0, -235.0),
			}
		},
		{
			shadow =
			{
				copper = stdlib_util.by_pixel_hr(292.0, 0.0),
			},
			wire =
			{
				copper = stdlib_util.by_pixel_hr(47.0, -212.0),
			}
		},
		{
			shadow =
			{
				copper = stdlib_util.by_pixel_hr(277.0, 23.0),
			},
			wire =
			{
				copper = stdlib_util.by_pixel_hr(33.0, -188.0),
			}
		}
	},
	water_reflection =
	{
		pictures =
		{
			filename = "__base__/graphics/entity/big-electric-pole/big-electric-pole-reflection.png",
			priority = "extra-high",
			width = 16,
			height = 32,
			shift = stdlib_util.by_pixel(0, 60),
			variation_count = 1,
			scale = 5
		},
		rotate = false,
		orientation_to_variation = false
	}
}})
