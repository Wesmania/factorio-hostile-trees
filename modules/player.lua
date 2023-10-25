local util = require("modules/util")
local tree_events = require("modules/tree_events")

local M = {}

local SpookyStoryPrototype = {
	stages = {
		-- Flicker light
		start = function(s)
			s.until_next = s.until_next - 1
			if s.until_next == 0 then
				s.player.disable_flashlight()
				s.until_next = global.rng(120, 180)
				s.stage = "initial_pause"
				return
			end
			if s.player.is_flashlight_enabled() then
				s.player.disable_flashlight()
			else
				s.player.enable_flashlight()
			end
		end,
		initial_pause = function(s)
			s.until_next = s.until_next - 1
			if s.until_next ~= 0 then return end

			s.stage = "fire_ring"
			s.circle = util.shuffle(16)
			s.i = 1
			s.until_next = global.rng(5, 9)
			s.fire_radius = 6  + global.rng() * 4
		end,
		fire_ring = function(s)
			s.until_next = s.until_next - 1
			if s.until_next ~= 0 then return end

			if s.i > 16 then
				s.stage = "outro"
				s.until_next = global.rng(120, 180)
				return
			end

			local ppos = util.position(s.player)
			local search_pos = {
				x = ppos.x + math.sin(math.pi / 8 * s.circle[s.i]) * s.fire_radius,
				y = ppos.y + math.cos(math.pi / 8 * s.circle[s.i]) * s.fire_radius,
			}
			local box = util.box_around(search_pos, 2)
			tree_events.set_tree_on_fire(s.surface, box)
			s.i = s.i + 1
			s.until_next = global.rng(5, 9)
		end,
		-- Dramatic pause
		outro = function(s)
			s.until_next = s.until_next - 1
			if s.until_next ~= 0 then return end
			s.stage = nil
			s.player.enable_flashlight()
		end,
	},
	run = function(s)
		local stage = s.stages[s.stage]
		if stage == nil then return false end
		if not s.player.valid or not s.surface.valid then return false end
		stage(s)
		return true
	end,
}

M.spooky_story = function(player, surface)
	local s = {}
	setmetatable(s, {__index = SpookyStoryPrototype})
	s.stage = "start"
	s.until_next = global.rng(45, 75)
	s.player = player
	s.surface = surface
	return s
end

return M
