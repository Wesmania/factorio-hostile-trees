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

local function fire_ring(s)
	s.until_next = s.until_next - 1
	if s.until_next > 0 then return false end

	if s.i > 16 then
		return true
	end

	local ppos = util.position(s.player)
	local search_pos = {
		x = ppos.x + math.sin(math.pi / 8 * s.tree_circle[s.i]) * s.fire_radius,
		y = ppos.y + math.cos(math.pi / 8 * s.tree_circle[s.i]) * s.fire_radius,
	}
	local box = util.box_around(search_pos, 2)
	tree_events.set_tree_on_fire(s.surface, box)
	s.i = s.i + 1
	s.until_next = math.random(s.until_low, s.until_high)
	return false
end

local SpookyStoryPrototype = {
	stages = {
		-- Args: until_next
		flicker_light = function(s)
			if not flicker_light(s) then return end
			s.next_stage(s)
		end,
		-- Args: until_next
		pause = function(s)
			if not pause(s) then return end
			s.next_stage(s)
		end,
		-- Args s.fire_radius, s.until_low, s.until_high, s.tree_count
		fire_ring = function(s)
			if s.tree_circle == nil then
				s.i = 1
				s.tree_circle = util.shuffle(s.tree_count)
			end
			if not fire_ring(s) then return end
			s.tree_circle = nil
			s.next_stage(s)
		end,
		-- Dramatic pause
		unflicker_light = function(s)
			s.player.enable_flashlight()
			s.next_stage(s)
		end,
	},

	next_stage = function(s)
		s.stage_idx = s.stage_idx + 1
		local stage = s.stage_list[s.stage_idx]
		if stage == nil then return end
		for n, v in pairs(stage[2]) do
			s[n] = v
		end
	end,

	finish = function(s)
		s.stage_idx = nil
	end,

	run = function(s)
		local stage = s.stage_list[s.stage_idx]
		if stage == nil then return false end
		if not s.player.valid or not s.surface.valid then return false end
		s.stages[stage[1]](s)
		return true
	end,
}

M.spooky_story = function(player, surface)
	local s = {}
	setmetatable(s, {__index = SpookyStoryPrototype})
	s.stage_list = {
		{ "flicker_light", {until_next = math.random(45, 75)} },
		{ "pause", {until_next = math.random(120, 180)} },
		{ "fire_ring", {fire_radius = 6 + math.random() * 4, until_low = 5, until_high = 9, tree_count = 16}},
		{ "pause", {until_next = math.random(120, 180)}},
		{ "unflicker_light", {}}
	}
	s.stage_idx = 0
	s.player = player
	s.surface = surface
	s.next_stage(s)
	return s
end

return M
