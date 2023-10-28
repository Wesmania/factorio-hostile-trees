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
