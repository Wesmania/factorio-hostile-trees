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
	}
end

function M.on_chunk_generated(cs, c)
	local cinfo = {
		x = c.x,
		y = c.y,
	}
	util.dict2_add(cs.all, c.x, c.y, cinfo)
	if dict2.get(cs.masked, c.x, c.y) ~= nil then
		util.ldict2_add(cs.active, c.x, c.y, cinfo)
	end
end

function M.on_chunk_deleted(cs, c)
	util.dict2_remove(cs.all, c.x, c.y)
	util.ldict2_remove(cs.active, c.x, c.y)
end

function M.chunk_mask_inc(cs, c)
	local cmask = util.dict2_setdefault(cs.masked, c.x, c.y, {c = 0})
	if cmask.c == 0 then
		util.ldict2_remove(cs.active, c.x, c.y)
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
	end
end

function M.reinitialize_chunks(cs)
	for c in global.surface.get_chunks() do
		M.on_chunk_generated(cs, c)
	end
end

return M
