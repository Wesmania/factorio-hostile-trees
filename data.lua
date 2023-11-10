local stdlib_util = require("__core__/lualib/util")

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

local function generate_tree_spawner_projectile(generation, tree_name)
	local ts = table.deepcopy(data.raw["stream"]["acid-stream-worm-small"])
	ts.initial_action = {
		{
			type = "direct",
			action_delivery = {
				type = "instant",
				target_effects = {
					type = "create-entity",
					entity_name = tree_name,
					offset_deviation = {{-2, -2}, {2, 2}},
					repeat_count = 2,
					repeat_count_deviation = 1,
					tile_collision_mask = { "object-layer", "water-tile" },
				}
			}
		},
		{
			type = "direct",
			action_delivery = {
				type = "instant",
				target_effects = {
					type = "script",
					effect_id = "tree-spawner-projectile-" .. tree_name .. "-" .. generation,
				}
			}
		}
	}
	ts.name = "tree-spawner-projectile-" .. tree_name .. "-" .. generation
	data:extend({ts})
end

for _, tree in pairs(data.raw["tree"]) do
	for i = 1,3 do
		generate_tree_spawner_projectile(i, tree.name)
	end
end

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
