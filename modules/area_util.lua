local M = {}

function M.get_building(surface, area)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			for _, e in ipairs(surface.find_entities_filtered{area = area, force = force}) do
				if e.prototype.is_building then return e end
			end
		end
	end
	return nil
end

function M.get_buildings(surface, area)
	local out = {}
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			for _, e in ipairs(surface.find_entities_filtered{area = area, force = force}) do
				if e.prototype.is_building then
					out[#out + 1] = e
				end
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
	-- Might also find worms, but who cares.
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

-- Only call it after we did an entity / tree check
function M.has_buildings(surface, area)
	return M.get_building(surface, area) ~= nil
end

function M.has_trees(surface, area)
	local global = global
	return surface.count_entities_filtered{area = area, name = global.surface_trees, limit = 1} > 0
end

function M.count_trees(surface, area, limit)
	local global = global
	return surface.count_entities_filtered{area = area, name = global.surface_trees, limit = limit}
end

function M.get_tree(surface, area)
	local global = global
	return surface.find_entities_filtered{area = area, name = global.surface_trees, limit = 1}[1]
end

-- More expensive, but there's no other way to get a random tree.
function M.get_random_tree(surface, area)
	local trees = surface.find_entities_filtered{area = area, name = global.surface_trees}
	if #trees == 0 then
		return nil
	end
	return trees[math.random(1, #trees)]
end

function M.get_trees(surface, area)
	return surface.find_entities_filtered{area = area, name = global.surface_trees}
end

function M.has_player_entities(surface, area)
	for _, force in pairs(game.forces) do
		if #force.players > 0 then
			if surface.count_entities_filtered{area = area, force = force, limit = 1} > 0 then
				return true
			end
		end
	end
	return false
end

return M
