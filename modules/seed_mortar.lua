local M = {}

local util = require("modules/util")
local area_util = require("modules/area_util")

local function tree_is_dead(tree_name)
	return string.find(tree_name, "dead", 1, true) ~= nil
end

function M.artillery_strike_story(surface, sources_targets, projectile, speed)
	local s = {}
	s.surface = surface
	s.sources_targets = sources_targets
	s.projectile = projectile
	s.per_frame = speed / 60.0
	s.frame = 0
	s.idx = 1
	s.event_name = "event_artillery_strike"
	return s
end

function M.tree_artillery(surface, source_rect, target, target_radius, projectile, count, speed)
	local coro = M.tree_artillery_coro(surface, source_rect, target, target_radius, projectile, count, speed)
	storage.tree_stories[#storage.tree_stories + 1] = coro
end

function M.tree_artillery_coro(surface, source_rect, target, target_radius, projectile, count, speed)
	local trees = area_util.get_trees(surface, source_rect)
	if count * 2 > #trees then
		count = math.floor(#trees / 2)
	end

	local sources = {}
	for i = 0, count do
		local r = math.random(#trees)
		local tree = trees[r]
		local random_target = util.random_offset(target, target_radius)
		if tree.valid then
			sources[#sources + 1] = {
				source = tree.position,
				target = random_target,
				tree_name = tree.name,
			}
		end
	end
	return M.artillery_strike_story(surface, sources, projectile, speed)
end

function M.artillery_strike_frame(s)
	local st = s.sources_targets
	if s.idx > #st or s.frame > 1200 then return false end

	s.frame = s.frame + 1
	if s.idx >= s.frame * s.per_frame then return true end

	if not s.surface.valid then return false end

	local sti = st[s.idx]
	s.idx = s.idx + 1

	s.projectile(s.surface, sti.source, sti.target, sti.tree_name)
	return true
end

function M.make_seed_mortar(surface, source, target, tree_name)
	if tree_is_dead(tree_name) then return end

	local s = surface.create_entity{
		name = 'hostile-trees-seed-mortar-' .. tree_name,
		position = source,
		source = source,
		target = target,
		speed = 0.3,
	}
	if s ~= nil then
		local rid = script.register_on_object_destroyed(s)
		storage.entity_destroyed_script_events[rid] = {
			action = "on_seed_mortar_landed",
			surface = surface,
			tree_name = tree_name,
			target = target,
		}
	end
end

function M.make_explosive_mortar(surface, source, target, tree_name)
	if tree_is_dead(tree_name) then return end
	local s = surface.create_entity{
		name = 'hostile-trees-explosive-mortar',
		position = source,
		source = source,
		target = target,
		speed = 0.3,
	}
end

function M.on_seed_mortar_landed(s)
	if s.surface.valid then
		local ts = s.surface.create_entity {
			name = "item-on-ground",
			position = s.target,
			stack = {
				name = "hostile-trees-seed-" .. s.tree_name,
				count = 1,
			}
		}
		if ts ~= nil then
			ts.to_be_looted = true
		end
	end
end

-- I wish it was possible to throw it in a high arc...
local explosive_tree_mortar = {
  type = "projectile",
  name = "hostile-trees-explosive-mortar",
  acceleration = 0,
  flags = {"not-on-map"},
  hidden = true,
  animation =
  {
    filename = "__base__/graphics/icons/tree-06-brown.png",
    frame_count = 1,
    line_length = 1,
    animation_speed = 0.250,
    width = 64,
    height = 64,
    scale = 0.5,
  },
  action =
  {
    type = "direct",
    action_delivery =
    {
      type = "instant",
      target_effects =
      {
        {
          type = "nested-result",
          action =
          {
            type = "area",
            radius = 4.0,
            action_delivery =
            {
              type = "instant",
              target_effects =
              {
                {
                  type = "damage",
                  damage = {amount = 75, type = "explosion"}
                }
              }
            }
          }
        },
        {
          type = "create-entity",
          entity_name = "big-explosion"
        },
      }
    }
  },
}

function M.generate_tree(tree)
	local unit = table.deepcopy(explosive_tree_mortar)
	unit.icon = tree.icon
	-- Work around some mods with no icons
	if unit.icon == nil then
		unit.icon = "__base__/graphics/icons/tree-06-brown.png"
	end
	unit.animation.filename = unit.icon
	unit.name = "hostile-trees-seed-mortar-" .. tree.name
        unit.action = {
          type = "direct",
          action_delivery =
          {
            type = "instant",
            target_effects =
            {
              {
                type = "script",
                effect_id = "hostile-trees-seed-mortar-spawn",
              },
            },
          },
        }

	local seed =  {
          type = "item",
          name = "hostile-trees-seed-" .. tree.name,
          icon = unit.icon,
          icon_size = 64, icon_mipmaps = 4,
          subgroup = "trees",
          stack_size = 50,
          spoil_ticks = 3600,
	  flags = {
            "hide-from-bonus-gui",
	  },
	  fuel_value = "6MJ",
	  fuel_category = "chemical",
          spoil_to_trigger_result = {
	    items_per_trigger = 5,
	    trigger = {
              type = "direct",
              action_delivery = {
                type = "instant",
                target_effects = {
                  type = "create-entity",
                  offset_deviation = util.box_around({x = 0, y = 0}, 3),
                  entity_name = tree.name
                }
              }
            }
          }
        }
	data:extend({seed})
	data:extend({unit})
end

function M.data_stage()
	data:extend({explosive_tree_mortar})
	for _, tree in pairs(data.raw["tree"]) do
		if not tree_is_dead(tree.name) then
			M.generate_tree(tree)
		end
	end
end

return M
