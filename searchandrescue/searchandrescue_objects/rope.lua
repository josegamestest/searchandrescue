minetest.register_craftitem("searchandrescue:hook",{description = "hook rope", inventory_image = "rope.png",}) -- blades
local rope_entity = {
	groups = {not_in_creative_inventory=1},
	initial_properties = {
    hp_max = 20,
    physical = false,
    collide_with_objects = false,
    collisionbox = {-0.2, -0.2, -0.2, 0.2, 0.2, 0.2},
    visual = "mesh",
	mesh = "helicoptero_hook.obj",
    visual_size = {x = 1, y = 1},
    textures = {"helicoptero_hook.png"},
    spritediv = {x = 1, y = 1},
    initial_sprite_basepos = {x = 0, y = 0},
    pointable = false,
	glow= 8,
    speed = 15, gravity = 16,
	damage = 0,
    lifetime = 10
  }
}

function rope_entity.on_step(self,pos,dtime)
	if self.object:get_attach() == nil  then self.object:remove() end
end
--[[
		local distancia=10
		local pos1 = self.object:get_pos()
		pos1.z = pos1.z+math.random(-distancia, distancia)
		pos1.x = pos1.x+math.random(-distancia, distancia)
		local node_glow = minetest.get_node(pos1)
		if node_glow.name == "air" or node_glow.name == "searchandrescue:glow" then
			minetest.set_node(pos1, {name = "searchandrescue:glow" })
			minetest.get_node_timer(pos1):start(4.5)
		end

		local posicao2 = vector.add({x=0, y=-5, z=0}, pos1)
		if posicao2 == nil then minetest.chat_send_all("posicao nil") return end
		local node = minetest.get_node(posicao2)

		if node.name == "air" or node.name == "searchandrescue:glow" then
				minetest.get_node_timer(posicao2):start(1.0)

		end
		--local all_objects = minetest.get_objects_inside_radius({x = pos.x, y = pos.y, z = pos.z}, 1)
		local all_objects = minetest.get_objects_inside_radius(posicao2,2)

		for _,obj in pairs(minetest.get_objects_inside_radius(posicao2,2)) do
			if obj:get_luaentity() ~= nil then
				if not obj:is_player() and (not entity or not entity.name:find()) then
					minetest.sound_play("catch3", {pos=posicao2, gain = 1.0, max_hear_distance = 5})
					obj:set_attach(self.object,"",{x = 0, y = -50, z =0}, {x = 0, y = 0, z = 0})

					if self.object:get_attach() == nil
						then self.object:remove()
					end

				end
			end
		end
end]]
minetest.register_entity("searchandrescue:hook_entity", rope_entity)
minetest.register_node("searchandrescue:glow", {description = "glow",
    drawtype = "airlike",paramtype = "light", walkable = false,
	buildable_to = true, pointable = false, sunlight_propagates = true,light_source = 13,
	on_construct = function(pos)minetest.get_node_timer(pos):start(1.0)end,
	on_timer = function(pos, elapsed) minetest.swap_node(pos, {name = "air"})end,
	drop = "",
groups = {not_in_creative_inventory=1},
})
