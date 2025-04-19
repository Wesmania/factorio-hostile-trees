local util = require("modules/util")
local stdlib_util = require("__core__/lualib/util")

local M = {}

local proto_anim = {
	layers = {
		{
			filename = "__base__/graphics/entity/beam/tileable-beam-END.png",
			draw_as_glow = true,
			blend_mode = "additive-soft",
			line_length = 4,
			width = 49,
			height = 54,
			frame_count = 16,
			direction_count = 1,
			shift = {-0.046875, 0},
			scale = 2.0,
			hr_version =
			{
				filename = "__base__/graphics/entity/beam/hr-tileable-beam-END.png",
				draw_as_glow = true,
				blend_mode = "additive-soft",
				line_length = 4,
				width = 91,
				height = 93,
				frame_count = 16,
				direction_count = 1,
				shift = {-0.078125, -0.046875},
			}
		}
	}
}

local shadow_anim = stdlib_util.empty_sprite()
shadow_anim.repeat_count = 16

local proto_base = {
	type = "combat-robot",
	name = "hostile-trees-poltergeist",
	localised_name = {"entity-name.hostile-trees-poltergeist"},
	icon = "__base__/graphics/icons/list-dot.png",
	icon_size = 64, icon_mipmaps = 4,
	flags = {"placeable-off-grid", "not-repairable"},
	time_to_live = 60 * 30,
	follows_player = false,
	friction = 0.01,
	speed = 0.05,
	collision_box = {{0, 0}, {0, 0}},
	selection_box = {{0, 0}, {0, 0}},
	attack_parameters = {
		type = "beam",
		ammo_category = "bullet",
		range = 13,
		cooldown = 60,
		ammo_consumption_modifier = 0,
		cooldown_deviation = 0.5,
		sound = {
			layers = {
				{
					filename = "__base__/sound/fight/pulse.ogg",
					volume = 0.5,
					min_speed = 1.0,
					max_speed = 2.0,
					aggregation = {
						max_count = 6,
						remove = false,
					}
				}
			}
		},
		ammo_type = {
			category = "beam",
			action = {
				type = "direct",
				action_delivery = {
					type = "beam",
					beam = "electric-beam",
					max_length = 15,
					duration = 20,
					source_offset = {0.15, -0.5}
				}
			}
		},
	},	-- TODO
	movement_speed = 0, 	-- TODO
	distance_per_frame = 0.0,
	pollution_to_join_attack = 100000,
	distraction_cooldown = 0,
	idle = stdlib_util.empty_sprite(),
	in_motion = stdlib_util.empty_sprite(),
	shadow_idle = stdlib_util.empty_sprite(),
	shadow_in_motion = stdlib_util.empty_sprite(),
	working_sound = {
		filename = "__base__/sound/accumulator-working.ogg",
		volume = 0.7
	}
}

local proto_projectile = {
	type = "projectile",
	name = "hostile-trees-graphics",
	collision_box = {{0, 0}, {0, 0}},
	acceleration = 0,
	animation = proto_anim,
}

local function make_poltergeist_proto(name, speed)
	local t = table.deepcopy(proto_base)
	t.name = "hostile-trees-poltergeist" .. name
	t.speed = speed
	return t
end

function M.data_stage()
	data:extend({
		make_poltergeist_proto("", 0.05),
		make_poltergeist_proto("-fast", 0.25),
		proto_base, proto_projectile
	})
end

function M.spawn_poltergeist(surface, pos, direction, ttl, speed)
	if speed == nil then speed = 0.05 end

	if speed == 0.25 then
		ptg = "hostile-trees-poltergeist-fast"
	else
		speed = 0.05
		ptg = "hostile-trees-poltergeist"
	end

	local ptgt = {
		x = pos.x + 1000 * direction.x,
		y = pos.y + 1000 * direction.y,
	}
	local l = surface.create_entity{
		name = ptg,
		position = pos,
		target = ptgt,
	}
	l.time_to_live = ttl * 60
	l.orientation = math.atan2(direction.x, -direction.y) / (math.pi * 2)
	surface.create_entity{
		name = "hostile-trees-graphics",
		position = pos,
		target = ptgt,
		speed = speed,
		max_range = speed * ttl * 60,
	}
end

function M.throw_poltergeist(surface, source, target, ttl, speed, spread_degrees)
	if spread_degrees == nil then spread_degrees = 10 end
	local ndis = math.sqrt(util.dist2(source, target))
	if ndis == 0 then return end
	local norm = {
		x = (target.x - source.x) * ndis,
		y = (target.y - source.y) * ndis,
	}
	local rand = math.random()
	local target_dir = util.rotate(norm, 2 * math.pi / 360 * spread_degrees * (1 - 2 * rand))

	M.spawn_poltergeist(surface, source, target_dir, ttl, speed)
end

function M.throw_a_bunch_of_fast_poltergeists_story(surface, target, treepos, count, ilow, ihigh)
	local s = {}
	s.event_name = "throw_a_bunch_of_fast_poltergeists"
	s.surface = surface
	s.target = target
	s.count = count
	s.treepos = treepos
	s.count = count
	s.ilow = ilow
	s.ihigh = ihigh
	s.tick = 0
	return s
end

function M.throw_a_bunch_of_fast_poltergeists_coro(s)
	if s.tick > 0 then
		s.tick = s.tick - 1
		return true
	end
	if not s.target.valid then return false end
	local ppos = {
		x = s.treepos.x - 5 + math.random() * 10,
		y = s.treepos.y - 5 + math.random() * 10,
	}
	M.throw_poltergeist(s.surface, ppos, s.target.position, math.random() * 4 + 7, 0.25, 15)
	s.count = s.count - 1
	if s.count == 0 then return false end
	s.tick = math.random(s.ilow, s.ihigh)
	return 0
end

function M.throw_a_bunch_of_fast_poltergeists(surface, target, treepos, count, ilow, ihigh)
	local s = M.throw_a_bunch_of_fast_poltergeists_story(surface, target, treepos, count, ilow, ihigh)
	global.tree_stories[#global.tree_stories + 1] = s
end

function M.can_introduce()
	return game.forces["enemy"].evolution_factor >= 0.2
end

return M
