local setup = require("modules/setup")
local on_destroyed = require("modules/on_destroyed")
local util = require("modules/util")
local area_util = require("modules/area_util")
local player_stories = require("modules/player")
local tree_events = require("modules/tree_events")
local trees = require("modules/trees")
local car = require("modules/car")
local chunks = require("modules/chunks")
local retaliation = require("modules/retaliation")
local cache_evolution = require("modules/cache_evolution")
local electricity = require("modules/electricity")

script.on_init(function()
	setup.initialize_fresh()
end)

script.on_configuration_changed(function(info)
	local old_grace_period = global.config.grace_period

	if info.old_version ~= nil or info.mod_changes["hostile-trees"] ~= nil or info.mod_startup_settings_changed then
		setup.initialize(info)
		global.config.grace_period = old_grace_period
	end
end)

script.on_event({defines.events.on_tick}, function(event)
	local global = global
	local surface = global.surface
	local config = global.config

	global.tick_mod_10_s = (global.tick_mod_10_s + 1) % 600
	if global.tick_mod_10_s == 0 then
		setup.refresh_caches()
	end

	if config.grace_period ~= nil then
		if config.grace_period <= 0 then
			config.grace_period = nil
		else
			config.grace_period = config.grace_period - 1
		end
		return
	end

	-- Stories, ran once per tick.
	for _, player_info in pairs(global.players) do
		if player_info.story ~= nil then
			if not player_stories.run_coro(player_info.story) then
				player_info.story = nil
			end
		end
	end

	-- Tree stories. Safe iteration while removing elements.
	local i = 1
	while true do
		if i > #global.tree_stories then break end
		local story = global.tree_stories[i]
		if trees.run_coro(story) then
			i = i + 1
		else
			local tmp = global.tree_stories[#global.tree_stories]
			global.tree_stories[i] = tmp
			global.tree_stories[#global.tree_stories] = nil
			-- New entity under same i
		end
	end

	if global.config.factory_events then

		local cks = global.chunks
		global.accum = global.accum + chunks.active_per_tick(cks)
		local tocheck = math.floor(global.accum)
		global.accum = global.accum - tocheck

		for i = 1,tocheck do
			-- TODO do we define these as globals to avoid allocation cost?
			local chunk = chunks.pick_random_active_chunk(cks)
			local map_pos = {
				x = chunk.x * 32 + math.random(0, 32),
				y = chunk.y * 32 + math.random(0, 32),
			}
			local box = util.box_around(map_pos, 4)
			if area_util.has_player_entities(surface, box) and area_util.has_trees(surface, box) -- These two first, they remove most checks
			    and area_util.has_buildings(surface, box) then
				trees.event(surface, box)
			end
		end
	end

	-- Player event check.

	do
		if not global.config.player_events or #global.players_array == 0 then goto after_player_check end
		local event_chance = #global.players_array / (global.config.player_event_frequency * 30)
		if math.random() >= event_chance then goto after_player_check end
		local player_info = global.players_array[math.random(1, #global.players_array)]
		if not player_info.player.valid then goto after_player_check end
		if player_info.story ~= nil then goto after_player_check end

		local story = player_stories.spooky_story(player_info, surface, false)
		if story ~= nil then
			player_info.story = story
		end
	end
	::after_player_check::

	do
		-- Player event check for players that are focused on.
		local chance_every_sec = #global.players_focused_on.list / 60
		if math.random() >= chance_every_sec then goto after_focus_check end
		local l = global.players_focused_on.list
		local pid = l[math.random(1, #l)]
		local player_info = global.players[pid]
		if player_info == nil or not player_info.player.valid then goto after_focus_check end
		if player_info.story ~= nil then goto after_focus_check end

		local story = player_stories.spooky_story(player_info, surface, true)
		if story ~= nil then
			player_info.story = story
		end
	end
	::after_focus_check::

	-- Call only once per second, booby trapping cars doesn't have to be precise
	if global.tick_mod_10_s % 60 == 0 then
		car.car_tree_events()
	end

	-- Same wih electrified trees
	-- FIXME
	if global.tick_mod_10_s % 2 == 1 then
		electricity.check_electrified_trees()
	end
end)
