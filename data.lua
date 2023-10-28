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

local stdlib_util = require("__core__/lualib/util")

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
