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


return M
