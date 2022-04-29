-- recipe
if minetest.get_modpath("default") then
	minetest.register_craft({ output = "searchandrescue:blades",
		recipe = {
			{"",                    "default:steel_ingot", ""},
			{"default:steel_ingot", "group:stick",         "default:steel_ingot"},
			{"",                    "default:steel_ingot", ""},
		}
	})
	minetest.register_craft({output = "searchandrescue:cabin",
		recipe = {
			{"",           "group:wood",           ""},
			{"group:wood", "default:mese_crystal", "default:glass"},
			{"group:wood", "group:wood",           "group:wood"},
		}
	})
	minetest.register_craft({ output = "searchandrescue:helicopter",
		recipe = {
			{"",                  "searchandrescue:blades"},
			{"searchandrescue:blades", "searchandrescue:cabin"},
		}
	})
end 
