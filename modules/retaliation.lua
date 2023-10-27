script.on_nth_tick(30 * 60, function()
	global.tree_kill_count = 0
	global.tree_kill_locs = {}
end)

script.on_event(defines.events.on_entity_died, function(event)
	global.tree_kill_count = global.tree_kill_count + 1
end, {{
	filter = "type",
	type = "tree",
}})
