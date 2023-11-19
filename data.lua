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

local function can_generate_ent(tree_data)
	return tree_data.variations ~= nil
end

local function generate_ent_animation(tree_data)
	local v = tree_data.variations[1]
	local layers = {}

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

	local adjust_frame_count = function(l, target)
		if l.layers ~= nil then
			for _, ll in pairs(l.layers) do
				ll.frame_count = target
				if ll.hr_version ~= nil then
					ll.hr_version.frame_count = target
				end
			end
		else
			l.frame_count = target
			if l.hr_version ~= nil then
				l.hr_version.frame_count = target
			end
		end
	end

	for _, l in pairs({ v.leaves, v.overlay }) do
		local ll = table.deepcopy(l)
		adjust_frame_count(ll, 1)
		add_layer(ll)
	end

--	local fc = get_frame_count(v.leaves)

	if v.shadow ~= nil then
		local s = table.deepcopy(v.shadow)
		adjust_frame_count(s, 1)
		add_layer(s)
	end

	local s = table.deepcopy(v.trunk)
	adjust_frame_count(s, 1)
	add_layer(s)

	return {
		layers = layers
	}
end

local function generate_ent(tree_data)
	local unit = table.deepcopy(data.raw["unit"]["small-biter"])
	unit.name = "ent-" .. tree_data.name
	unit.icon = tree_data.icon
	unit.corpse = tree_data.corpse
	unit.dying_explosion = nil
	unit.run_animation = generate_ent_animation(tree_data)
	unit.dying_sound = nil
	unit.working_sound = nil
	unit.running_sound_animation_positions = nil
	unit.walking_sound = nil
	unit.water_reflection = nil
	unit.attack_parameters.animation = generate_ent_animation(tree_data)
	unit.attack_parameters.sound = nil
	data:extend({unit})
end

for _, tree in pairs(data.raw["tree"]) do
	if can_generate_ent(tree) then
		generate_ent_animation(tree)
		generate_ent(tree)
	end
end
