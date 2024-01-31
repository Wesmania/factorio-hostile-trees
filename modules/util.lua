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


-- List mixin for random selection of items in a dict.
-- Expects value to be a table and keeps its list index there.
function M.l_add(list, item)
	item.idx = #list + 1
	list[#list + 1] = item
end

function M.l_get_random(list)
	local c = #list
	if c == 0 then
		return nil
	else
		return list[math.random(1, c)]
	end
end

function M.l_remove(list, item)
	local victim = list[#list]
	victim.idx = item.idx
	list[item.idx] = victim
	list[#list] = nil
end

function M.dict2_add(d, key1, key2, item)
	if d[key1] == nil then
		d[key1] = {}
	end
	if d[key1][key2] == nil then
		d[key1][key2] = item
		return true
	else
		return false
	end
end

function M.dict2_get(d, key1, key2)
	local l1 = d[key1]
	if l1 == nil then return nil end
	return l1[key2]
end

function M.dict2_remove(d, key1, key2)
	local l1 = d[key1]
	if l1 == nil then return nil end
	local val = l1[key2]
	l1[key2] = nil
	if not next(l1) then
		d[key1] = nil
	end
	return val
end

function M.dict2_setdefault(d, key1, key2, default)
	if d[key1] == nil then
		d[key1] = {}
	end
	local l = d[key1]
	if l[key2] == nil then
		l[key2] = default
		return default
	else
		return l[key2]
	end
end

function M.ldict2_add(ldict, key1, key2, item)
	local l = ldict.list
	local d = ldict.dict
	if M.dict2_add(d, key1, key2, item) then
		M.l_add(l, item)
	end
end

function M.ldict2_remove(ldict, key1, key2)
	local l = ldict.list
	local d = ldict.dict
	local val = M.dict2_remove(d, key1, key2)
	if val ~= nil then
		M.l_remove(l, val)
	end
end

function M.ldict2_get(ldict, key1, key2)
	return M.dict2_get(key1, key2)
end

function M.ldict2_get_random(ldict)
	return M.l_get_random(ldict.list)
end

function M.ldict_add(ldict, key, item)
	if ldict.dict[key] ~= nil then return end
	ldict.dict[key] = item
	M.l_add(ldict.list, item)
end

function M.ldict_get(ldict, key)
	return ldict.dict[key]
end

function M.ldict_remove(ldict, key)
	if ldict.dict[key] == nil then return end
	M.l_remove(ldict.list, ldict.dict[key])
	ldict.dict[key] = nil
end

function M.ldict_get_random(ldict)
	return M.l_get_random(ldict.list)
end

return M
