local M = {}

-- TODO consider passing an argument by reference and using blocals to avoid allocation. Might be premature optimization?
function M.position(entity)
	local bb = entity.bounding_box
	return {
		x = (bb.left_top.x + bb.right_bottom.x) / 2,
		y = (bb.left_top.y + bb.right_bottom.y) / 2,
	}
end

function M.shuffle(count)
	local tbl = {}
	for i=1,count do
		tbl[i] = i
	end
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

function M.pick_random(list, n)
	if n > #list then
		return list
	end
	local out = {}
	while n > 0 and #list > 0 do
		local tgt = math.random(1, #list)
		out[#out + 1] = list[tgt]
		list[tgt], list[#list] = list[#list], nil
		n = n - 1
	end
	return out
end

function M.box_around(position, radius)
	return {
		left_top = {
			x = position.x - radius,
			y = position.y - radius,
		},
		right_bottom = {
			x = position.x + radius,
			y = position.y + radius,
		},
	}
end

function M.list_remove(list, idx)
	local out = nil
	if idx < #list then
		out, list[idx], list[#list] = list[idx], list[#list], nil
	else
		out, list[#list] = list[#list], nil
	end
	return out
end

return M
