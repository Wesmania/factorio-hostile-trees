local M = {}

function M.get_buildings(surface, area)
	local out = {}
	for _, force in pairs(storage.game_forces) do
		for _, e in ipairs(surface.find_entities_filtered{area = area, force = force}) do
			if e.prototype.is_building then
				out[#out + 1] = e
			end
		end
	end
	return out
end

-- More expensive.
function M.get_random_building(surface, area)
	local buildings = M.get_buildings(surface, area)
	if #buildings == 0 then
		return nil
	else
		return buildings[math.random(1, #buildings)]
	end
end

function M.is_turret(building)
	local t = building.type
	return t == "ammo-turret" or t == "fluid-turret" or t == "electric-turret" or t == "artillery-turret"
end

function M.is_electric_pole(building)
	local t = building.type
	return t == "electric-pole"
end

function M.is_belt(building)
	local t = building.type
	return t == "transport-belt" or t == "underground-belt" or t == "splitter"
end

function M.is_pipe(building)
	local t = building.type
	return t == "pipe" or t == "pipe-to-ground"
end

function M.get_random_belt(surface, area)
       local items = surface.find_entities_filtered{
               area = area,
               type = { "transport-belt", "underground-belt", "splitter" },
       }
       if #items == 0 then
               return nil
       else
               return items[math.random(1, #items)]
       end
end

function M.get_random_true_pipe(surface, area)
       local items = surface.find_entities_filtered{
               area = area,
               type = { "pipe", "pipe-to-ground" },
       }
       local f = {}
       for _, item in ipairs(items) do
	       if string.find(item.name, "hostile-trees", 1, true) == nil then
		       f[#f + 1] = item
	       end
       end

       if #f == 0 then
               return nil
       else
               return f[math.random(1, #f)]
       end
end

-- Only call it after we did an entity / tree check
function M.has_buildings(surface, area)
	for _, force in pairs(storage.game_forces) do
		for _, e in ipairs(surface.find_entities_filtered{area = area, force = force}) do
			if e.prototype.is_building then return true end
		end
	end
	return false
end

function M.has_trees(surface, area)
	return surface.count_entities_filtered{area = area, type = "tree", limit = 1} > 0
end

function M.count_trees(surface, area, limit)
	return surface.count_entities_filtered{area = area, type = "tree", limit = limit}
end

function M.get_tree(surface, area)
	return surface.find_entities_filtered{area = area, type = "tree", limit = 1}[1]
end

-- More expensive, but there's no other way to get a truly random tree.
function M.get_random_tree(surface, area)
	local trees = surface.find_entities_filtered{area = area, type = "tree"}
	if #trees == 0 then
		return nil
	end
	return trees[math.random(1, #trees)]
end

function M.get_trees(surface, area)
	return surface.find_entities_filtered{area = area, type = "tree"}
end

function M.get_trees_radius(surface, position, radius)
	return surface.find_entities_filtered{position = position, radius = radius, type = "tree"}
end

function M.has_player_entities(surface, area)
	for _, force in pairs(storage.game_forces) do
		if surface.count_entities_filtered{area = area, force = force, limit = 1} > 0 then
			return true
		end
	end
	return false
end

function M.is_water(surface, position)
	local tile = surface.get_tile(position.x, position.y)
	return string.find(tile.prototype.name, "water", 1, true) ~= nil
end

function M.find_closest_player(surface, position, max_dist)
	local dist2 = 1000000000
	if max_dist ~= nil then
		dist2 = max_dist * max_dist
	end
	local res = nil
	for _, p in ipairs(storage.players_array) do
		if p.player.valid and p.player.surface.index == surface.index then
			local pos = p.player.position
			local dx = position.x - pos.x
			local dy = position.y - pos.y
			local d2 = dx * dx + dy * dy
			if d2 < dist2 then
				dist2 = d2
				res = p.player
			end
		end
	end

	return res
end

return M
