itens={{"tanque_toxico","tanque_toxico.obj","tanque_toxico.png","tanque_toxico_icon.png"},}
for i = 1, #itens, 1 do
minetest.register_craftitem("searchandrescue:"..itens[i][1], {
  stack_max = 1,
  description = itens[i][1],
  inventory_image = itens[i][4],
--[[on_use = function(_, player, pointed_thing, pos)
      local throw_starting_pos = vector.add({x=0, y=1.5, z=0}, player:get_pos())
    minetest.after(0, function() player:get_inventory():remove_item("main", "searchandrescue:"..itens[i][1]) end)
		local posicao = player:get_pos()
		local node = minetest.get_node(posicao)
    if node.name == "air" then
		minetest.add_entity(posicao, "searchandrescue:"..itens[i][1])
    end
    end,]]
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then return end
		if minetest.get_node(pointed_thing.above).name ~= "air" then return end
		local imeta = itemstack:get_meta()
		local obj = minetest.add_entity(pointed_thing.above, "searchandrescue:"..itens[i][1])
		if not (searchandrescue.creative and placer and
				creative.is_enabled_for(placer:get_player_name())) then
			itemstack:take_item()
		end
		return itemstack
	end,

})

minetest.register_entity("searchandrescue:"..itens[i][1],{   --propriedades da entidade
	hp_max = 200,
	physical = true,
	weight = 5,
	collide_with_objects = false,
	selectionbox = {-1.2,-0.0,-4, 1.5,3,4},
	collisionbox = {-1.2,-0.0,-4, 1.5,3,4},
	--visual = "cube"/"sprite"/"upright_sprite"/"mesh"/"wielditem",
	visual = "mesh",
	mesh = itens[i][2],
	textures = {itens[i][3]}, --texturas
	initial_sprite_basepos = {x=0, y=0},
	visual_size = {x=1, y=1},
	is_visible = true,
	automatic_rotate = 0,
	backface_culling = false,
	player_name = "",
	drop="",

on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then return end
			if minetest.get_node(pointed_thing.above).name ~= "air" then return end
			minetest.add_entity(pointed_thing.above, "searchandrescue:"..itens[i][1])
			if not (creative_exists and placer and creative.is_enabled_for(placer:get_player_name())) then itemstack:take_item()
				end return itemstack
	end,

})
end
