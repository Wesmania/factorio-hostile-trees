local M = {}

function M.event(surface, area)
	local random = math.random()
	tree_events.spitter_projectile(surface, area)
	do return end	-- FIXME for testing
	if random < 0.3 then
		tree_events.spread_trees_towards_buildings(surface, area)
	elseif random < 0.9 then
		tree_events.set_tree_on_fire(surface, area)
	else
		tree_events.small_tree_explosion(surface, area)
	end
end

return M
