--itens
minetest.register_craftitem("searchandrescue:blades",{description = "Helicopter Blades", inventory_image = "helicopter_blades.png",})
minetest.register_craftitem("searchandrescue:cabin",{ description = "Cabin for Helicopter", inventory_image = "cabin_inv.png", })
minetest.register_craftitem("searchandrescue:heli", { description = "Helicopter", inventory_image = "heli_inv.png", -- heli
	on_use =function(_, player, pointed_thing, pos)
      local throw_starting_pos = vector.add({x=0, y=1.5, z=0}, player:get_pos())
      minetest.add_entity(throw_starting_pos, "searchandrescue:helicopter", player:get_player_name())
      minetest.after(0, function() 
                     player:get_inventory():remove_item("main", "searchandrescue:heli")
                     minetest.sound_play("transformation", {pos=pos, gain = 1.0, max_hear_distance = 3})
					end)
    end,
})
 
