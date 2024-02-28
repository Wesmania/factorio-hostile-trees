local area_util = require("modules/area_util")
local util = require("modules/util")

local M = {}

local function on_placed_vehicle(e)
	-- Identifying cars 101
	if e.created_entity.type ~= "car" then return end
	if not string.find(e.created_entity.name, "car") then return end

	local car = e.created_entity
	local pc = global.player_cars

	-- Don't tank performance if player's a psycho that places down hundreds of cars
	if #pc.list >= 250 then return end

	local rid = script.register_on_entity_destroyed(car)
	global.entity_destroyed_script_events[rid] = {
		action = "on_car_destroyed",
		id = car.unit_number,
	}
	util.ldict_add(pc, car.unit_number, {
		e = car,
	})
end

function M.on_car_destroyed(e)
	util.ldict_remove(global.player_cars, e.id)
end

local function car_has_sapling(car)
	local inv = car.get_inventory(defines.inventory.car_trunk)
	if inv == nil then return false end
	local saplings = inv.get_item_count("volatile-sapling")
	return saplings > 0
end

local function player_has_sapling(car)
	local inv = car.get_inventory(defines.inventory.character_main)
	if inv == nil then return false end
	local saplings = inv.get_item_count("volatile-sapling")
	return saplings > 0
end

local function player_clear_saplings(car)
	local inv = car.get_inventory(defines.inventory.character_main)
	if inv == nil then return false end
	inv.remove({name = "volatile-sapling", count = 1000})
end

local function blow_up(c)
	c.surface.create_entity{
		name = "volatile-sapling",
		position = c.position,
		target = c,
		speed = 1.0,
	}
end

local function arming_events()
	local cs = global.player_cars.armed.cars
	local ps = global.player_cars.armed.players
	local es = global.player_cars.armed.early

	for id, item in pairs(cs) do
		item.time = item.time - 1
		if item.time > 0 then goto next end

		cs[id] = nil
		if not item.e.valid then goto next end
		local c = item.e
		if not car_has_sapling(c) then goto next end

		blow_up(c)

		-- HACK: players won't get damaged as long as they're
		-- in a vehicle and we do want them to die in the
		-- explosion, so damage them here.
		for _, rider in ipairs({ c.get_driver(), c.get_passenger() }) do
			if rider ~= nil and rider.valid and not rider.is_player() then
				rider.damage(500, "enemy", "explosion")
			end
		end

		::next::
	end
	for id, item in pairs(ps) do
		item.time = item.time - 1
		if item.time > 0 then goto next_2 end

		ps[id] = nil
		if not item.e.valid then goto next_2 end
		local c = item.e
		if not player_has_sapling(c) then goto next_2 end
		player_clear_saplings(c)

		blow_up(c)

		::next_2::
	end

	for id, item in pairs(es) do
		local car = item.info.e
		local dvr = item.info.last_driver
		item.time = item.time - 1

		-- Wait a few seconds in case we got booby trapped immediately after leaving the car.
		if item.time > 595 then
			goto next_3
		end

		if item.time <= 0 or not car.valid then
			es[id] = nil
			goto next_3
		end
		if dvr == nil or not dvr.valid then
			es[id] = nil
			goto next_3
		end
		if util.dist2(car.position, dvr.position) < 256 and math.random() < 0.8 then
			es[id] = nil
			blow_up(car)
		end

		::next_3::
	end
end

-- NOTE: this is called once every second, NOT evey frame!
function M.car_tree_events()
	-- Check existing arming events.
	arming_events()

	if not global.config.player_events then return end
	local ccount = #global.player_cars.list
	if ccount == 0 then return end

	-- Player events are each frequency * 0.5 seconds. Booby trap cars 10 times less often.
	local event_chance = ccount / (global.config.player_event_frequency * 5)
	if math.random() >= event_chance then return end

	local victim_info = util.ldict_get_random(global.player_cars)
	local victim = victim_info.e

	-- Is the car empty?
	if victim.get_driver() ~= nil or victim.get_passenger() ~= nil then return end

	-- Are there trees around?
	local tree_count = area_util.count_trees(victim.surface, util.box_around(victim.position, 12), 5)
	if tree_count < 5 then return end

	-- Then booby trap!
	local inv = victim.get_inventory(defines.inventory.car_trunk)
	if inv == nil then return end
	inv.insert({name = "volatile-sapling"})

	-- And add a small chance of exploding too early.
	if math.random() < 0.1 then
		if global.player_cars.armed.early[victim.unit_number] == nil then
			global.player_cars.armed.early[victim.unit_number] = {
				time = 600,
				info = victim_info,
			}
		end
	end
end

local function arm_booby_trap(e)
	local car = e.entity
	-- Sanity checks
	if car == nil then return end
	if global.player_cars.dict[car.unit_number] == nil then return end

	if car.get_driver() == nil and car.get_passenger() == nil then return end

	-- EXTRA: add last driver for early explosion checks.
	local driver = car.get_driver()
	if driver ~= nil and not driver.is_player() then
		global.player_cars.dict[car.unit_number].last_driver = driver
	end

	if not car_has_sapling(car) then return end

	-- Small chance of failing to arm
	if math.random() < 0.2 then return end

	if global.player_cars.armed.cars[car.unit_number] ~= nil then return end
	global.player_cars.armed.cars[car.unit_number] = {
		time = math.random(5, 15),
		e = car,
	}
end

local function arm_held_sapling(e)
	local ch = game.players[e.player_index].character
	if ch == nil or not player_has_sapling(ch) then return end
	if global.player_cars.armed.players[ch.unit_number] ~= nil then return end
	global.player_cars.armed.players[ch.unit_number] = {
		time = math.random(5, 10),
		e = ch,
	}
end

function M.fresh_setup()
	global.player_cars = {
		list = {},
		dict = {},
		armed = {
			cars = {},
			players = {},
			early = {},
		},
	}
end

script.on_event(defines.events.on_built_entity, on_placed_vehicle, {{ filter = "vehicle" }})
script.on_event(defines.events.on_player_driving_changed_state, arm_booby_trap)
script.on_event(defines.events.on_player_main_inventory_changed, arm_held_sapling)

return M
