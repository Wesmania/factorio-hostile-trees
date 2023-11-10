local M = {}

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
	local out
	if idx < #list then
		out, list[idx], list[#list] = list[idx], list[#list], nil
	else
		out, list[#list] = list[#list], nil
	end
	return out
end

function M.random_offset(pos, offset)
	return {
		x = pos.x - offset + math.random() * offset * 2,
		y = pos.y - offset + math.random() * offset * 2,
	}
end

function M.rotate(position, angle)
	local x = position.x
	local i_x = position.y
	local c = math.cos(angle)
	local i_c = math.sin(angle)
	-- (x + i * i_x)(c + i * i_c) = xc - i_x * i_c + i * (x * i_c + i_x * c)
	return {
		x = x * c - i_x * i_c,
		y = x * i_c + i_x * c,
	}
end

return M
