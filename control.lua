local setup = require("modules/setup")
local util = require("modules/util")
local area_util = require("modules/area_util")
local player_stories = require("modules/player")
local tree_events = require("modules/tree_events")
local trees = require("modules/trees")

local retaliation = require("modules/retaliation")

local config = setup.config

local function count_chunks(surface)
	local global = global
	global.chunks = 0
	for _ in surface.get_chunks() do
		global.chunks = global.chunks + 1
	end
end

local function squares_to_check_per_tick()
	return global.chunks * config.factory_events_per_tick_per_chunk
end

-- Tree-factory interactions


script.on_init(function()
	setup.initialize()
end)

script.on_event({defines.events.on_tick}, function(event)
	local global = global
	local surface = game.get_surface(1)

	global.tick_mod_10_s = (global.tick_mod_10_s + 1) % 600
	if global.tick_mod_10_s == 0 then
		count_chunks(surface)
		setup.cache_players()
	end

	-- Stories, ran once per tick.
	for cid, story in pairs(global.stories) do
		if not story.run(story) then
			global.stories[cid] = nil
		end
	end

	-- Tree stories. Safe iteration while removing elements.
	local i = 1
	while true do
		if i > #global.tree_stories then break end
		local story = global.tree_stories[i]
		if story.run(story) then
			i = i + 1
		else
			util.list_remove(global.tree_stories, i)
			-- New entity under same i
		end
	end

	if not surface or not surface.valid then
		return
	end

	-- FIXME replace with TODO when we add player events
	if config.factory_events then

		global.accum = global.accum + squares_to_check_per_tick()
		local tocheck = math.floor(global.accum)
		global.accum = global.accum - tocheck

		for i = 1,tocheck do
			-- TODO do we define these as globals to avoid allocation cost?
			local chunk = surface.get_random_chunk()
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

	do return end
	local event_chance = 1 / 60
	if math.random() >= event_chance then return end
	if #global.players == 0 then return end
	local player = global.players[math.random(1, #global.players)]
	if not player.valid then return end
	if global.stories[player.unit_number] ~= nil then return end

	local ppos = util.position(player)
	local box = util.box_around(ppos, 8)
	if area_util.count_trees(surface, box) > 40 then
		global.stories[player.unit_number] = player_stories.spooky_story(player, surface)
	end
end)
