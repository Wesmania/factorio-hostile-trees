local util = require("modules/util")
local tree_events = require("modules/tree_events")

local M = {}

local function flicker_light(s)
	s.until_next = s.until_next - 1
	if s.until_next == 0 then
		s.player.disable_flashlight()
		return true
	end
	if s.player.is_flashlight_enabled() then
		s.player.disable_flashlight()
	else
		s.player.enable_flashlight()
	end
	return false
end

local function pause(s)
	s.until_next = s.until_next - 1
	return s.until_next <= 0
end

local function fire_ring(s, until_low, until_high)
	s.until_next = s.until_next - 1
	if s.until_next > 0 then return false end

	if s.i > 16 then
		return true
	end

	local ppos = util.position(s.player)
	local search_pos = {
		x = ppos.x + math.sin(math.pi / 8 * s.circle[s.i]) * s.fire_radius,
		y = ppos.y + math.cos(math.pi / 8 * s.circle[s.i]) * s.fire_radius,
	}
	local box = util.box_around(search_pos, 2)
	tree_events.set_tree_on_fire(s.surface, box)
	s.i = s.i + 1
	s.until_next = global.rng(until_low, until_high)
	return false
end

local SpookyStoryPrototype = {
	stages = {
		-- Flicker light
		start = function(s)
			if not flicker_light(s) then return end
			s.until_next = global.rng(120, 180)
			s.stage = "initial_pause"
		end,
		initial_pause = function(s)
			if not pause(s) then return end
			s.stage = "fire_ring"
			s.until_next = 0
			s.fire_radius = 6  + global.rng() * 4
			s.circle = util.shuffle(16)
			s.i = 1
		end,
		fire_ring = function(s)
			if not fire_ring(s, 5, 9) then return end
			s.stage = "outro"
			s.until_next = global.rng(120, 180)
		end,
		-- Dramatic pause
		outro = function(s)
			if not pause(s) then return end
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
