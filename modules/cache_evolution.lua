local ents = require("modules/ent_generation")

local M = {}

local function interpolate_evolution_rates(evolution, rates, new_entries, rate_adjust)
	for _, entry in ipairs(rates) do
		local unit = entry.unit
		local unit_rates = entry.spawn_points
		local probability = nil
		if unit_rates[1].evolution_factor >= evolution then
			probability = unit_rates[1].weight
		end
		if unit_rates[#unit_rates].evolution_factor <= evolution then
			probability = unit_rates[#unit_rates].weight
		end
		for i = 1,#unit_rates - 1 do
			-- Linear interpolation, rates are ascending by evolution_factor
			if unit_rates[i].evolution_factor <= evolution and evolution < unit_rates[i + 1].evolution_factor then
				local range = unit_rates[i + 1].evolution_factor - unit_rates[i].evolution_factor
				local r1 = (evolution - unit_rates[i].evolution_factor) / range
				probability = unit_rates[i].weight * r1 + unit_rates[i + 1].weight * (1 - r1)
			end
		end
		if probability == nil then
			probability = 0
		end
		if probability ~= 0 then
			new_entries[#new_entries + 1] = { unit, probability * rate_adjust}
		end
	end
end

local function normalize_rates(new_entries)
	local res = {}
	local total_prob = 0
	for _, entry in ipairs(new_entries) do
		total_prob = total_prob + entry[2]
	end

	local sum = 0
	for _, entry in ipairs(new_entries) do
		res[#res+ 1] = {entry[1], sum}
		sum = sum + entry[2] / total_prob
	end
	return res
end

local function cache_evolution_for(evolution)
	local new_entries = {}
	local enemy_rates = {
		biters = 0.75,
		spitters = 0.25,
	}

	-- Collect spawn rates from saved spawner tables.
	for enemy_kind, rates in pairs(global.spawnrates) do
		local rate_adjust = enemy_rates[enemy_kind]
		interpolate_evolution_rates(evolution, rates, new_entries, rate_adjust)
	end

	return normalize_rates(new_entries)
end

local function cache_evolution_for_ents(evolution)
	local new_entries = {}
	interpolate_evolution_rates(evolution, ents.spawnrates, new_entries, 1.0)
	return normalize_rates(new_entries)
end

M.cache_evolution_rates = function()
	local evolution = game.forces["enemy"].evolution_factor
	global.spawntable = {
		default = cache_evolution_for(evolution),
		retaliation = cache_evolution_for(evolution + 0.1),
		half_retaliation = cache_evolution_for(evolution + 0.05),
		ents = cache_evolution_for_ents(evolution)
	}
end

return M
