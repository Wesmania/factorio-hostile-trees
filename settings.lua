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
		default_value = 60,
		order = "b-b"
	},
	{
		type = "bool-setting",
		name = "hostile-trees-do-trees-retaliate",
		setting_type = "runtime-global",
		default_value = true,
		order = "c-a"
	},
})
