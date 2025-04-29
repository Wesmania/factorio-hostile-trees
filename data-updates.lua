local oil = require("modules/oil")

if settings.startup["hostile-trees-are-trees-damp"].value == true then
	local f = data.raw.fire["fire-flame-on-tree"]
	f.spread_delay = f.spread_delay * 100.0
	f.spread_delay_deviation = f.spread_delay_deviation * 100.0
end

oil.data_updates_stage()
