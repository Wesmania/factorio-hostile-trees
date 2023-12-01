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

function M.len2(pos1)
	return pos1.x * pos1.x + pos1.y * pos1.y
end

function M.dist2(pos1, pos2)
	local dx = pos1.x - pos2.x
	local dy = pos1.y - pos2.y
	return dx * dx + dy * dy
end

-- Is vec2 rotated clockwise relative to vec1?
function M.clockwise(vec1, vec2)
	-- Multiply vec2 by conjugate of vec1 to subtract angles. If i < 0, then vec2 is clockwise to vec1.
	-- Re(vec2) * -Im(vec1) * i + Im(vec2) * Re(vec1) < 0
	return vec2.x * (-vec1.y) + vec2.y * vec1.x < 0
end

function M.ldict2_add(ldict, key1, key2, item)
	local l = ldict.list
	local d = ldict.dict

	if d[key1] == nil then
		d[key1] = {}
	end
	if d[key1][key2] == nil then
		d[key1][key2] = #l + 1
		l[#l + 1] = { key1, key2, item }
	end
end

function M.ldict2_remove(ldict, key1, key2)
	local l = ldict.list
	local d = ldict.dict

	local l1 = d[key1]
	if l1 == nil then return end
	local pos_to_remove = l1[key2]
	if pos_to_remove == nil then return end

	local last_on_list = l[#l]
	l[#l] = nil
	l[pos_to_remove] = last_on_list
	d[last_on_list[1]][last_on_list[2]] = pos_to_remove
	l1[key2] = nil
end

function M.ldict2_get(ldict, key1, key2)
	return ldict.list[ldict.dict[key1][key2]][3]
end

function M.ldict2_get_random(ldict)
	return ldict.list[math.random(1, #ldict.list)][3]
end

return M
