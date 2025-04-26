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
local belttrees = require("modules/belttrees")
local _on_entity_died = require("modules/on_entity_died")

script.on_init(function()
	setup.initialize_fresh()
end)

script.on_configuration_changed(function(info)
	local old_grace_period = storage.config.grace_period

	if info.old_version ~= nil or info.mod_changes["hostile-trees"] ~= nil or info.mod_startup_settings_changed then
		setup.initialize(info)
		storage.config.grace_period = old_grace_period
	end
end)

script.on_event({defines.events.on_tick}, function(event)
	local storage = storage
	local config = storage.config

	storage.tick_mod_10_s = (storage.tick_mod_10_s + 1) % 600
	if storage.tick_mod_10_s == 0 then
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
	for _, player_info in pairs(storage.players) do
		if player_info.story ~= nil then
			if not player_stories.run_coro(player_info.story) then
				player_info.story = nil
			end
		end
	end

	-- Tree stories. Safe iteration while removing elements.
	local i = 1
	while true do
		if i > #storage.tree_stories then break end
		local story = storage.tree_stories[i]
		if trees.run_coro(story) then
			i = i + 1
		else
			local tmp = storage.tree_stories[#storage.tree_stories]
			storage.tree_stories[i] = tmp
			storage.tree_stories[#storage.tree_stories] = nil
			-- New entity under same i
		end
	end

	if storage.config.factory_events then
		-- Run factory events for every surface.
		-- Probably could skip planets without trees, but whatever.
		
		for _, surface in pairs(game.surfaces) do
			if util.skip_planet(surface) then
				goto next_surface
			end

			local cks = storage.chunks
			local accum = chunks.get_accum(cks, surface)
			accum = accum + chunks.active_per_tick(cks, surface)
			local tocheck = math.floor(accum)
			chunks.set_accum(cks, surface, accum - tocheck)

			for i = 1,tocheck do
				-- TODO do we define these as globals to avoid allocation cost?
				local chunk = chunks.pick_random_active_chunk(cks, surface)
				local map_pos = {
					x = chunk.x * 32 + math.random(0, 32),
					y = chunk.y * 32 + math.random(0, 32),
				}
				local box = util.box_around(map_pos, 4)
				-- These two first, they remove most checks
				if area_util.has_player_entities(surface, box) and area_util.has_trees(surface, box)
				    and area_util.has_buildings(surface, box) then
					trees.event(surface, box)
				end
			end
			::next_surface::
		end
	end

	-- Player event check.

	do
		if not storage.config.player_events or #storage.players_array == 0 then goto after_player_check end
		local event_chance = #storage.players_array / (storage.config.player_event_frequency * 30)
		if math.random() >= event_chance then goto after_player_check end
		local player_info = storage.players_array[math.random(1, #storage.players_array)]
		if not player_info.player.valid then goto after_player_check end
		if player_info.story ~= nil then goto after_player_check end

		local story = player_stories.spooky_story(player_info, false)
		if story ~= nil then
			player_info.story = story
		end
	end
	::after_player_check::

	do
		-- Player event check for players that are focused on.
		local chance_every_sec = #storage.players_focused_on.list / 60
		if math.random() >= chance_every_sec then goto after_focus_check end
		local l = storage.players_focused_on.list
		local pid = l[math.random(1, #l)]
		local player_info = storage.players[pid]
		if player_info == nil or not player_info.player.valid then goto after_focus_check end
		if player_info.story ~= nil then goto after_focus_check end

		local story = player_stories.spooky_story(player_info, true)
		if story ~= nil then
			player_info.story = story
		end
	end
	::after_focus_check::

	belttrees.check_jumping_belt_trees()

	-- Call only once per second, booby trapping cars doesn't have to be precise
	if storage.tick_mod_10_s % 60 == 0 then
		car.car_tree_events()
	end

	-- Same wih electrified trees
	if storage.tick_mod_10_s % 60 == 30 then
		electricity.check_electrified_trees()
	end

	-- Same wih maturing belt trees
	if storage.tick_mod_10_s % 60 == 15 then
		belttrees.mature_travelling_belt_trees()
	end

	-- Surprise, settings can change at any time.
	-- Just reload them every second instead of renaming everything.
	if storage.tick_mod_10_s % 60 == 0 then
		setup.reload_config()
	end
end)
