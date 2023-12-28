data:extend({
	{
		type = "bool-setting",
		name = "hostile-trees-do-trees-hate-your-factory",
		setting_type = "runtime-global",
		default_value = true,
		order = "a-a"
	},
	{
		type = "int-setting",
		name = "hostile-trees-how-often-do-trees-hate-your-factory",
		setting_type = "runtime-global",
		minimum_value = 1,
		default_value = 600,
		order = "a-b"
	},
	{
		type = "bool-setting",
		name = "hostile-trees-do-trees-hate-you",
		setting_type = "runtime-global",
		default_value = true,
		order = "b-a"
	},
	{
		type = "int-setting",
		name = "hostile-trees-how-often-do-trees-hate-you",
		setting_type = "runtime-global",
		minimum_value = 1,
		default_value = 30,
		order = "b-b"
	},
	{
		type = "bool-setting",
		name = "hostile-trees-do-trees-retaliate",
		setting_type = "runtime-global",
		default_value = true,
		order = "c-a"
	},
	{
		type = "int-setting",
		name = "hostile-trees-how-long-do-trees-withhold-their-hate",
		setting_type = "runtime-global",
		minimum_value = 0,
		default_value = 0,
		order = "d-a"
	},
	{
		type = "bool-setting",
		name = "hostile-trees-are-trees-damp",
		setting_type = "startup",
		default_value = true,
		order = "c-a"
	},
})
