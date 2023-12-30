local M = {}

function M.get_buildings(surface, area)
	local out = {}
	for _, force in pairs(global.game_forces) do
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

function M.get_random_turret(surface, area)
	local turrets = surface.find_entities_filtered{
		area = area,
		type = { "ammo-turret", "fluid-turret", "electric-turret", "artillery-turret" },
	}
	if #turrets == 0 then
		return nil
	else
		return turrets[math.random(1, #turrets)]
	end
end

function M.get_big_electric(surface, area)
	local items = surface.find_entities_filtered{
		area = area,
		type = { "electric-pole" },
	}
	if #items == 0 then
		return nil
	else
		return items[math.random(1, #items)]
	end
end

-- Only call it after we did an entity / tree check
function M.has_buildings(surface, area)
	for _, force in pairs(global.game_forces) do
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

-- More expensive, but there's no other way to get a random tree.
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
	for _, force in pairs(global.game_forces) do
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

return M
