local util = require("modules/util")

local M = {}

function M.chunks_new()
	return {
		active = {
			list = {},
			dict = {},
		},
		all = {},
		masked = {},
		per_tick = 0,
		accum = 0,
		tree = {
			kill_count = 0,
			robot_deconstruct_count = 0,
			kill_locs = {},
			major_retaliation_threshold = 200,
		},
	}
end

local function cache_squares_to_check_per_tick(cs)
	cs.per_tick = #cs.active.list * storage.config.factory_events_per_tick_per_chunk
end

function M.get_surface_cs(cs, surface)
	local c = cs[surface.index]
	if c == nil then
		local c = M.chunks_new()
		cs[surface.index] = c
		return c
	end
	return c
end

function M.on_chunk_generated(cs, c, surface)
	local cs = M.get_surface_cs(cs, surface)
	local cinfo = {
		x = c.x,
		y = c.y,
	}
	util.dict2_add(cs.all, c.x, c.y, cinfo)
	if util.dict2_get(cs.masked, c.x, c.y) == nil then
		util.ldict2_add(cs.active, c.x, c.y, cinfo)
		cache_squares_to_check_per_tick(cs)
	end
end

function M.on_chunk_deleted(cs, c, surface)
	local cs = M.get_surface_cs(cs, surface)
	util.dict2_remove(cs.all, c.x, c.y)
	util.ldict2_remove(cs.active, c.x, c.y)
	cache_squares_to_check_per_tick(cs)
end

function M.chunk_mask_inc(cs, surface, x, y)
	local cs = M.get_surface_cs(cs, surface)
	local cmask = util.dict2_setdefault(cs.masked, x, y, {c = 0})
	if cmask.c == 0 then
		util.ldict2_remove(cs.active, x, y)
		cache_squares_to_check_per_tick(cs)
	end
	cmask.c = cmask.c + 1
end

function M.chunk_mask_dec(cs, surface, x, y)
	local cs = M.get_surface_cs(cs, surface)
	local cmask = util.dict2_get(cs.masked, x, y)
	if cmask == nil then return end
	cmask.c = cmask.c - 1
	if cmask.c > 0 then return end

	util.dict2_remove(cs.masked, x, y)
	local masked_chunk = util.dict2_get(cs.all, x, y)
	if masked_chunk ~= nil then
		util.ldict2_add(cs.active, x, y, masked_chunk)
		cache_squares_to_check_per_tick(cs)
	end
end

function M.reinitialize_chunks(cs)
	for _, surface in pairs(game.surfaces) do
		for c in surface.get_chunks() do
			M.on_chunk_generated(cs, c, surface)
		end
		local surface_cs = M.get_surface_cs(cs, surface)
		cache_squares_to_check_per_tick(surface_cs)
	end
end

function M.active_per_tick(cs, surface)
	local cs = M.get_surface_cs(cs, surface)
	return cs.per_tick
end

function M.pick_random_active_chunk(cs, surface)
	local cs = M.get_surface_cs(cs, surface)
	return util.ldict2_get_random(cs.active)
end

function M.get_accum(cs, surface)
	local cs = M.get_surface_cs(cs, surface)
	return cs.accum
end

function M.set_accum(cs, surface, accum)
	local cs = M.get_surface_cs(cs, surface)
	cs.accum = accum
end

function M.get_tree_data(cs, surface)
	local cs = M.get_surface_cs(cs, surface)
	return cs.tree
end

function M.fresh_setup()
	storage.chunks = {}
	M.reinitialize_chunks(storage.chunks)
end

return M
