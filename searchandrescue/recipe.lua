-- recipe
minetest.register_craft({ output = "searchandrescue:blades",
	recipe ={
				{"","default:steel_ingot", ""},
				{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
				{"",                    "default:steel_ingot", ""},
	}
	})

	minetest.register_craft({output = "searchandrescue:cabin",
		recipe ={
				{"default:mese_crystal","default:glass",	"default:glass"},
				{"default:steel_ingot",	"default:glass",	"default:glass"},
				{"default:steel_ingot",	"default:steel_ingot","default:steel_ingot"},
		}
	})

minetest.register_craft({ output = "searchandrescue:heli",
		recipe ={
				{"","searchandrescue:blades"},
				{"searchandrescue:blades",	"searchandrescue:cabin"},
		}
	})
