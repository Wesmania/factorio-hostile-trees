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
	}
end

local function cache_squares_to_check_per_tick(cs)
	cs.per_tick = #cs.active.list * global.config.factory_events_per_tick_per_chunk
end

function M.on_chunk_generated(cs, c)
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

function M.on_chunk_deleted(cs, c)
	util.dict2_remove(cs.all, c.x, c.y)
	util.ldict2_remove(cs.active, c.x, c.y)
	cache_squares_to_check_per_tick(cs)
end

function M.chunk_mask_inc(cs, c)
	local cmask = util.dict2_setdefault(cs.masked, c.x, c.y, {c = 0})
	if cmask.c == 0 then
		util.ldict2_remove(cs.active, c.x, c.y)
		cache_squares_to_check_per_tick(cs)
	end
	cmask.c = cmask.c + 1
end

function M.mask_chunk_dec(cs, c)
	local cmask = util.dict2_get(cs.masked, c.x, c.y)
	if cmask == nil then return end
	cmask.c = cmask.c - 1
	if cmask.c > 0 then return end

	util.dict2_remove(cs.masked, c.x, c.y)
	local masked_chunk = util.dict2_get(cs.all, c.x, c.y)
	if masked_chunk ~= nil then
		util.ldict2_add(c.x, c.y, masked_chunk)
		cache_squares_to_check_per_tick(cs)
	end
end

function M.reinitialize_chunks(cs)
	for c in global.surface.get_chunks() do
		M.on_chunk_generated(cs, c)
	end
	cache_squares_to_check_per_tick(cs)
end

function M.active_per_tick(cs)
	return cs.per_tick
end

function M.pick_random_active_chunk(cs)
	return util.ldict2_get_random(cs.active)
end

return M
