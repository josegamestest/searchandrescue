--[[minetest.register_craftitem("factory_mine:robo_operario", { description = "factory_mine", inventory_image = "factory_mine.png", -- heli
	on_use =function(_, player, pointed_thing, pos)
      local throw_starting_pos = vector.add({x=0, y=1.5, z=0}, player:get_pos())
      minetest.add_entity(throw_starting_pos, "factory_mine:robo_operario", player:get_player_name())
      minetest.after(0, function() 
                     player:get_inventory():remove_item("main", "factory_mine:robo_operario")
                     minetest.sound_play("transformation", {pos=pos, gain = 1.0, max_hear_distance = 3})
	end)
end,
})]]
 
minetest.register_entity("factory_mine:robo_operario", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		visual = "mesh",
		mesh = "robo_operario.b3d",
		textures = {"factory_mine.png"},
	},
on_activate = function(self)
		self.object:set_animation({x = 0, y = 100}, 0, 0, true)
		self.object:set_armor_groups({immortal=1})
		self.sound_handle = minetest.sound_play({name = "helicopter_motor"},
					{object = self.object, gain = 2.0, max_hear_distance = 32, loop = false,})
		self.object:set_animation_frame_speed(30)
	end,
})
