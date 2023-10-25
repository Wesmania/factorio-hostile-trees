local util = require("modules/util")
local tree_events = require("modules/tree_events")

local M = {}

local SpookyStoryPrototype = {
	stages = {
		-- Flicker light
		function(s)
			s.until_next = s.until_next - 1
			if s.until_next == 0 then
				s.player.disable_flashlight()
				s.until_next = global.rng(120, 180)
				s.stage = s.stage + 1
				return
			end
			if s.player.is_flashlight_enabled() then
				s.player.disable_flashlight()
			else
				s.player.enable_flashlight()
			end
		end,
		-- Dramatic pause
		function(s)
			s.until_next = s.until_next - 1
			if s.until_next ~= 0 then return end

			s.stage = s.stage + 1
			s.circle = util.shuffle(16)
			s.i = 1
			s.until_next = global.rng(5, 9)
			s.fire_radius = 6  + global.rng() * 4
		end,
		-- Start setting trees on fire
		function(s)
			s.until_next = s.until_next - 1
			if s.until_next ~= 0 then return end

			if s.i > 16 then
				s.stage = s.stage + 1
				s.until_next = global.rng(120, 180)
				return
			end

			local ppos = util.position(s.player)
			local search_pos = {
				x = ppos.x + math.sin(math.pi / 8 * s.circle[s.i]) * s.fire_radius,
				y = ppos.y + math.cos(math.pi / 8 * s.circle[s.i]) * s.fire_radius,
			}
			local box = {
				left_top = {
					x = search_pos.x - 2,
					y = search_pos.y - 2,
				},
				right_bottom = {
					x = search_pos.x + 2,
					y = search_pos.y + 2,
				},
			}
			tree_events.set_tree_on_fire(s.surface, box)
			s.i = s.i + 1
			s.until_next = global.rng(5, 9)
		end,
		-- Dramatic pause
		function(s)
			s.until_next = s.until_next - 1
			if s.until_next ~= 0 then return end
			s.stage = s.stage + 1
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
	s.stage = 1
	s.until_next = global.rng(45, 75)
	s.player = player
	s.surface = surface
	return s
end

return M
