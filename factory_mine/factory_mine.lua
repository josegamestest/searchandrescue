local repor_node="false"
local item1 = "searchandrescue:heli"
local produto_saida = "searchandrescue:heli"
local furnace_inactive_formspec ="formspec_version[5] size[14,10]"..
	"label[5,0.6;use:"..item1.."]"..	
	"label[5.5,2.1;input]"..
	"list[current_name;item1;5.4,2.6;1,1;0]"..
	"list[current_player;main;2.2,8.3;8,1;1]"..
	"list[current_player;main;2.2,4.3;8,3;0]"
	
minetest.register_node("factory_mine:factory", {
	description = "factory",
	visual_size = {x = 1,y = 1},

	selection_box = {type = "fixed",	fixed = {-4,-5,-4, 4,0,4},},
	collision_box = {type = "fixed",	fixed = {-4,-5,-4, 4,0,4},},

	drawtype = "mesh",
	mesh = "factory_mine.b3d",
    tiles = {"factory_mine.png"},
	inventory_image="factory_mine_icon.png",
	wield_image="factory_mine_icon.png",
	legacy_facedir_simple = true,
	paramtype = "light",
	--paramtype2 = "facedir",
	groups = {	snappy=1, choppy=2, flammable=3, oddly_breakable_by_hand=2, not_in_creative_inventory=0},

on_construct = function(pos)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("formspec", furnace_inactive_formspec)
		meta:set_string("infotext", "factory_mine")
		local inv = meta:get_inventory()
		inv:set_size("item1", 1)
		add_acessorios(pos,player)
end,

can_dig = function(pos,player)
		local meta = minetest.env:get_meta(pos);
		local inv = meta:get_inventory()
		if not inv:is_empty("item1") then return false end
		limpar_area(pos,player)
return true end,
})

minetest.register_node("factory_mine:factory_active", {
	description = "factory_active",
	visual_size = {x = 1,y = 1},
    drawtype = "mesh",
	mesh = "factory_mine.b3d",
    tiles = {"factory_mine.png"},
	paramtype = "light",
	light_source = 13,
	drop = "factory_mine:factory",
	groups = {	snappy=1, choppy=2, flammable=3, oddly_breakable_by_hand=2, not_in_creative_inventory=1},

on_construct = function(pos)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("formspec", furnace_inactive_formspec)
		local inv = meta:get_inventory()
		inv:set_size("item1", 1)
	end,

can_dig = function(pos,player)
		local meta = minetest.env:get_meta(pos);
		local inv = meta:get_inventory()
		if not inv:is_empty("item1") then return false end
		limpar_area(pos,player)
return true end,
})

function hacky_swap_node(pos,name)
	local node = minetest.env:get_node(pos)
	local meta = minetest.env:get_meta(pos)
	local meta0 = meta:to_table()
	if node.name == name then return end
	node.name = name
	local meta0 = meta:to_table()
	minetest.env:set_node(pos,node)
	meta = minetest.env:get_meta(pos)
	meta:from_table(meta0)
end

minetest.register_abm({
	nodenames = {"factory_mine:factory","factory_mine:factory_active"},
	interval =1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.env:get_meta(pos)
		local inv = meta:get_inventory()
		local stack = inv:get_stack("item1",1)
		if stack:get_name() == item1 then
			inv:remove_item("item1",ItemStack(item1))

			local position = vector.add({x=0, y=1, z=0},pos)
			if  minetest.get_node(position).name == "air" then
				local node_add=minetest.add_entity(position, "searchandrescue:helicopter")
			end

			meta:set_int("Total",meta:get_int("Total")+1)
			meta:set_string("formspec", furnace_inactive_formspec.."label[4.5,1.5;Total: "..meta:get_int("Total"))
		end
	end
})

function add_acessorios(pos, player)
local posicoes={
				{5,3,3}, --1
				{5,3,-3},--2
				{-5,3,-3},--3
				{-5,3,3},--4
	}
	posicao = vector.add(pos,{x=0, y=0, z=0})
	if  minetest.get_node(posicao).name == "air" then
		local robot=minetest.add_entity(posicao, "factory_mine:robo_operario")
	end

		for i = 1, #posicoes, 1 do  
			local position = vector.add({x=posicoes[i][1], y=posicoes[i][2], z=posicoes[i][3]},pos)
			if  minetest.get_node(position).name == "air" then
			local node_add=minetest.set_node(position, {name="factory_mine:factory_mine_light"})
		end
	end end

function limpar_area(pos, player)
--	local posicao = minetest.env:get_node(pos)
	for _, ob in ipairs(minetest.get_objects_inside_radius(pos,50)) do
		local luaentity = ob:get_luaentity()
		if not ob:is_player() and
					luaentity and
					luaentity.itemstring ~="" and
					luaentity.name=="factory_mine:robo_operario" then
			ob:remove() 
local posicoes={
				{5,3,3}, --1
				{5,3,-3},--2
				{-5,3,-3},--3
				{-5,3,3},--4
	}
		for i = 1, #posicoes, 1 do  
			local position = vector.add({x=posicoes[i][1], y=posicoes[i][2], z=posicoes[i][3]},pos)
		if  minetest.get_node(position).name == "factory_mine:factory_mine_light" then
			minetest.chat_send_all("removido")
			local node_add=minetest.set_node(position, {name="air"})
		end
	end end
end end
