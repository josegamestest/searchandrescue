--verssione 1 = 5.4.0
--verssione 0 = 5.5.0
local verssione=1
-- constants
searchandrescue.tilting_speed = 1
searchandrescue.tilting_max = 0.5
searchandrescue.power_max = 20
searchandrescue.power_min = 0.2 -- if negative, the helicopter can actively fly downwards
searchandrescue.wanted_vert_speed = 10
searchandrescue.friction_air_quadratic = 0.01
searchandrescue.friction_air_constant = 0.2
searchandrescue.friction_land_quadratic = 1
searchandrescue.friction_land_constant = 2
searchandrescue.friction_water_quadratic = 0.1
searchandrescue.friction_water_constant = 1

searchandrescue.hoock="false"
		

local eyes_set_y=24.5
local eyes_set_z=30

--form_setup 1
searchandrescue.cam_set=	"image_button[0.3,0.4;2,2;cam_icone.png;cam_set;;false;true;]"
searchandrescue.tools=	"image_button[9.4,0.4;2,2;operador.png;tools;;false;true;]"
searchandrescue.goout=	"image_button_exit[0.2,5.9;2,2;goout.png;go_out;]"
searchandrescue.close= "image_button_exit[9.4,5.7;2,2;close.png;exit;]"
--cameras
searchandrescue.texto= "textarea[0.3,0.4;11.3,2;;;Camera system,"..
		"the buttons put the right camera for the player to see around the helicopter]"
searchandrescue.box=	 "box[0.2,2.8;11.6,5;]"
searchandrescue.cam_1= "image_button[0.4,3.1;2,2;cam_icone.png;cam_1;;false;true;]"
searchandrescue.cam_2= "image_button[2.6,3.1;2,2;cam_icone.png;cam_2;;false;true;]"
searchandrescue.cam_3= "image_button[4.8,3.1;2,2;cam_icone.png;cam_3;;false;true;]"
searchandrescue.cam_4= "image_button[7.1,3.1;2,2;cam_icone.png;cam_4;;false;true;]"
searchandrescue.cam_5= "image_button[9.4,3.1;2,2;cam_icone.png;cam_5;;false;true;]"
searchandrescue.formulario_tamanho="formspec_version[5]size[12,8]"

--form setup 2
local formulario_base =""..
		searchandrescue.formulario_tamanho..
		searchandrescue.close..
		searchandrescue.goout..
		searchandrescue.cam_set..
		searchandrescue.tools.."]"
local formulario_camera2 =""..
		searchandrescue.formulario_tamanho..
		searchandrescue.box..
		searchandrescue.texto..
		searchandrescue.close.."]"..
		searchandrescue.cam_1..
		searchandrescue.cam_2..
		searchandrescue.cam_3..
		searchandrescue.cam_4..
		searchandrescue.cam_5.."]"

if not minetest.global_exists("matrix3") then
	dofile(minetest.get_modpath("searchandrescue") .. DIR_DELIM .. "searchandrescue_api/matrix.lua")
end

local creative_exists = minetest.global_exists("creative")
local gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.8
searchandrescue.vector_up = vector.new(0, 1, 0)
searchandrescue.vector_forward = vector.new(0, 0, 1)

function searchandrescue.vector_length_sq(v)
	return v.x * v.x + v.y * v.y + v.z * v.z
end
------------------------------------------------------------------------------------------------------
function searchandrescue.check_node_below(obj)
	local pos_below = obj:get_pos()
	pos_below.y = pos_below.y - 0.1
	local node_below = minetest.get_node(pos_below).name
	local nodedef = minetest.registered_nodes[node_below]
	local touching_ground = not nodedef or -- unknown nodes are solid
			nodedef.walkable or false
	local liquid_below = not touching_ground and nodedef.liquidtype ~= "none"
	return touching_ground, liquid_below
end
------------------------------------------------------------------------------------------------------
function searchandrescue.heli_control(self, dtime, touching_ground, liquid_below, vel_before)
	local driver = minetest.get_player_by_name(self.driver_name)
	if not driver then
		-- there is no driver (eg. because driver left)
		self.driver_name = nil
		if self.sound_handle then
			minetest.sound_stop(self.sound_handle)
			self.sound_handle = nil
		end
		self.object:set_animation_frame_speed(0)
		self.object:set_acceleration(vector.multiply(searchandrescue.vector_up, -gravity))	-- gravity
		return
	end
	local rot = self.object:get_rotation()
	local ctrl = driver:get_player_control()

	local vert_vel_goal = 0
	if not liquid_below then
		if ctrl.jump	then	vert_vel_goal = vert_vel_goal + searchandrescue.wanted_vert_speed	end
		if ctrl.sneak	then	vert_vel_goal = vert_vel_goal - searchandrescue.wanted_vert_speed	end
	else vert_vel_goal = searchandrescue.wanted_vert_speed end

	-- rotation
	if not touching_ground then
		local tilting_goal = vector.new()
		if ctrl.up		then	tilting_goal.z = tilting_goal.z + 1	end
		if ctrl.down	then	tilting_goal.z = tilting_goal.z - 1	end
		if ctrl.right	then	tilting_goal.x = tilting_goal.x + 1	end
		if ctrl.left	then	tilting_goal.x = tilting_goal.x - 1	end

		tilting_goal = vector.multiply(vector.normalize(tilting_goal), searchandrescue.tilting_max)

		-- tilting
		if searchandrescue.vector_length_sq(vector.subtract(tilting_goal, self.tilting)) > (dtime * searchandrescue.tilting_speed)^2 then
			self.tilting = vector.add(self.tilting,
					vector.multiply(vector.direction(self.tilting, tilting_goal), dtime * searchandrescue.tilting_speed))
		else self.tilting = tilting_goal
		end

		if searchandrescue.vector_length_sq(self.tilting) > searchandrescue.tilting_max^2 then
			self.tilting = vector.multiply(vector.normalize(self.tilting), searchandrescue.tilting_max)
		end
		local new_up = vector.new(self.tilting)
		new_up.y = 1
		new_up = vector.normalize(new_up) -- this is what searchandrescue.vector_up should be after the rotation
		local new_right = vector.cross(new_up, searchandrescue.vector_forward)
		local new_forward = vector.cross(new_right, new_up)
		local rot_mat = matrix3.new(
			new_right.x, new_up.x, new_forward.x,
			new_right.y, new_up.y, new_forward.y,
			new_right.z, new_up.z, new_forward.z
		)
		rot = matrix3.to_pitch_yaw_roll(rot_mat)
		rot.y = driver:get_look_horizontal()
	else
		rot.x = 0			rot.z = 0
		self.tilting.x = 0	self.tilting.z = 0
	end

	self.object:set_rotation(rot)

	-- calculate how strong the heli should accelerate towards rotated up
	local power = vert_vel_goal - vel_before.y + gravity * dtime
	power = math.min(math.max(power, searchandrescue.power_min * dtime), searchandrescue.power_max * dtime)
	local rotated_up = matrix3.multiply(matrix3.from_pitch_yaw_roll(rot), searchandrescue.vector_up)
	local added_vel = vector.multiply(rotated_up, power)
	added_vel = vector.add(added_vel, vector.multiply(searchandrescue.vector_up, -gravity * dtime))
	return vector.add(vel_before, added_vel)
end
------------------------------------------------------------------------------------------------------
--
-- entity
--
minetest.register_entity("searchandrescue:helicopter", {
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = {-2,0,-2, 2,0.3,2},
		selectionbox = {-2,0,-2, 2,0.3,2},
		visual = "mesh",
		mesh = "helicoptero.b3d",
		textures = {"helicoptero.png"},
	},
	add_rope_ative="false",
	driver_name = nil,
	sound_handle = nil,
	tilting = vector.new(),
on_activate = function(self)
		-- set the animation once and later only change the speed
		self.object:set_animation({x = 0, y = 5}, 0, 0, true)
		self.object:set_armor_groups({immortal=1})
		self.object:set_acceleration(vector.multiply(searchandrescue.vector_up, -gravity))
	end,

on_detach= function(self)
	self.object:set_acceleration(vector.multiply(searchandrescue.vector_up, -gravity))
end,
on_step = function(self, dtime)

		local touching_ground, liquid_below
		local vel = self.object:get_velocity()

		if self.driver_name then
			touching_ground, liquid_below = searchandrescue.check_node_below(self.object)
			vel = searchandrescue.heli_control(self, dtime, touching_ground, liquid_below, vel) or vel
		end

		if vel.x == 0 and vel.y == 0 and vel.z == 0 then return	end
		if touching_ground == nil then touching_ground, liquid_below = searchandrescue.check_node_below(self.object) end

		-- quadratic and constant deceleration
		local speedsq = searchandrescue.vector_length_sq(vel)
		local fq, fc
		if touching_ground 	then fq, fc = searchandrescue.friction_land_quadratic, searchandrescue.friction_land_constant
		elseif liquid_below then fq, fc = searchandrescue.friction_water_quadratic, searchandrescue.friction_water_constant
		else fq, fc = searchandrescue.friction_air_quadratic, searchandrescue.friction_air_constant
		end
		vel = vector.apply(vel, function(a)
			local s = math.sign(a)
			a = math.abs(a)
			a = math.max(0, a - fq * dtime * speedsq - fc * dtime)
			return a * s
		end)

		self.object:set_velocity(vel)
	end,
on_punch = function(self, puncher) if puncher then return false end end,

on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then return end
			if minetest.get_node(pointed_thing.above).name ~= "air" then return end
			minetest.add_entity(pointed_thing.above, "searchandrescue:helicopter")
			if not (creative_exists and placer and creative.is_enabled_for(placer:get_player_name())) then itemstack:take_item()
				end return itemstack
	end,

on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then return end
		local name = clicker:get_player_name() if name == nil then return end 
		local ent = self.object:get_luaentity() if ent == nil then return end 
		if name ~= self.driver_name then searchandrescue.entrar_helicoptero(self, clicker)
		elseif name == self.driver_name then 
					--add rope
				searchandrescue.add_rope=	"checkbox[0.6,0.7;add_rope;add_rope;"..ent.add_rope_ative.."]"
				local tools_helicoptero =""..
										searchandrescue.formulario_tamanho..
										searchandrescue.add_rope..
										searchandrescue.close.."]"
	--form1
				minetest.show_formspec(name,"clicker:helic",formulario_base)

				minetest.register_on_player_receive_fields(function(clicker, formname, fields)
				if formname == "clicker:helic" then
					if fields.cam_set then	minetest.show_formspec(name,"clicker:helic_cam",formulario_camera2) end
					if fields.go_out then 	searchandrescue.sair_helicoptero(self, clicker)
											minetest.close_formspec(name, "clicker:helic_cam")
					end

					if fields.tools then	minetest.show_formspec(name,"clicker:tools_helicoptero",tools_helicoptero) end
	--cameras
				elseif formname == "clicker:helic_cam" then
					if fields.cam_1 then clicker:set_eye_offset({x = 0, y = 24.5, z =30}, {x = 0, y = 8, z = -5})
						elseif fields.cam_2 then clicker:set_eye_offset({x = 0, y = 0, z = -60}, {x = 0, y = 0, z = 0})
						elseif fields.cam_3 then clicker:set_eye_offset({x = 0, y = 60, z = -60}, {x = 0, y = 0, z = 0})
						elseif fields.cam_4 then clicker:set_eye_offset({x = 0, y = -5, z = 0}, {x = 0, y = 0, z = 0})
						elseif fields.cam_5 then clicker:set_eye_offset({x = -30, y = 30, z = -30}, {x = 0, y = 0, z = 0})
						elseif fields.exit then  minetest.close_formspec(name, "clicker:helic")
					end
	--add rope
				elseif formname == "clicker:tools_helicoptero" then
					if fields.add_rope then
						if fields.add_rope=="true" then
							ent.add_rope_ative="true"
							searchandrescue.roope_helicoptero(self, clicker)
							searchandrescue.attachment_helicoptero(self, clicker, rook)
						else
							ent.add_rope_ative="false"
							searchandrescue.roope_helicoptero(self, clicker)
							searchandrescue.attachment_helicoptero(self, clicker, rook)
						end
					end
				end
			end )
	end end
})
-----------------------------------------------------------------------------------------------------------------------------------------
function searchandrescue.entrar_helicoptero(self, clicker)
	local name = clicker:get_player_name()
			self.driver_name = name
			-- sound and animation
			self.sound_handle = minetest.sound_play({name = "helicopter_motor"},
					{object = self.object, gain = 2.0, max_hear_distance = 32, loop = true,})
			self.object:set_animation_frame_speed(30)
			-- attach the driver
			if verssione ==0 then
					clicker:set_attach(self.object, "", {x = 0, y = 17, z =28}, {x = 0, y = 0, z = 0})
					clicker:set_eye_offset( {x = 0, y = 24.5, z =30}, {x = 0, y = 8, z = -5})
			elseif verssione == 1 then
					clicker:set_attach(self.object, "", {x = 0, y = 18, z =28}, {x = 0, y = 0, z = 0})
					clicker:set_eye_offset( {x = 0, y = 24.5, z =30}, {x = 0, y = 8, z = -5})
			end
			player_api.player_attached[name] = true
			-- make the driver sit
			minetest.after(0.2, function()
				local player = minetest.get_player_by_name(name)
				if player then player_api.set_animation(player, "sit") end
			end)
			-- disable gravity
			self.object:set_acceleration(vector.new())
		end
------------------------------------------------------------------------------------------------------
function searchandrescue.sair_helicoptero(self, clicker)
	if not clicker or not clicker:is_player() then return end
		local name = clicker:get_player_name()
		if name == self.driver_name then
			self.driver_name = nil
			-- sound and animation
			minetest.sound_stop(self.sound_handle)
			self.sound_handle = nil
			self.object:set_animation_frame_speed(0)
			-- detach the player
			clicker:set_detach()
			clicker:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
			player_api.player_attached[name] = nil
			-- player should stand again
			player_api.set_animation(clicker, "stand")
			-- gravity
			self.object:set_acceleration(vector.multiply(searchandrescue.vector_up, -gravity))
end end
------------------------------------------------------------------------------------------------------


function searchandrescue.roope_helicoptero(self, clicker, rook)
	local ent = self.object:get_luaentity()
	local throw_starting_pos={}
	throw_starting_pos = vector.add({x=0, y=2, z=0}, self.object:get_pos())
	rook=minetest.add_entity(throw_starting_pos, "searchandrescue:hook_entity", name)
	if ent.add_rope_ative=="true"then
		rook:set_attach(self.object,"",{x = 0, y = -1.5, z =0}, {x = 0, y = 0, z = 0})
	elseif ent.add_rope_ative =="false" then
		for _, object in ipairs(minetest.get_objects_inside_radius(throw_starting_pos,5)) do
			local luaentity = object:get_luaentity()

			if not object:is_player() and luaentity and luaentity.itemstring ~="" and luaentity.name=="searchandrescue:hook_entity" and
				luaentity.name~="searchandrescue:helicopter"then
				minetest.sound_play("item_drop_pickup", {to_player = clicker:get_player_name(),gain = 0.4,})
				luaentity.itemstring = ""
				--object:remove()
				object:set_detach()
			end
		end
	end
end
------------------------------------------------------------------------------------------------------------------------------------------
function searchandrescue.attachment_helicoptero(self, clicker, rook)
	local ent = self.object:get_luaentity()
	local throw_starting_pos={}

	if ent.add_rope_ative=="true"then
		throw_starting_pos = vector.add({x=0, y=-5, z=0}, self.object:get_pos())
		for _, object in ipairs(minetest.get_objects_inside_radius(throw_starting_pos,2)) do
			local luaentity = object:get_luaentity()
			if not object:is_player() and
					luaentity and
					luaentity.itemstring ~="" and
					luaentity.name~="searchandrescue:hook_entity" and
					luaentity.name~="searchandrescue:helicopter"then

					minetest.sound_play("item_drop_pickup", {to_player = clicker:get_player_name(),gain = 0.4,})
					object:set_attach(self.object,"",{x = 0, y = -45, z =0})
					object:set_pos(throw_starting_pos)
					
					self.object:set_properties({
						collisionbox = {-2,-7,-2, 2,0.3,2},
						selectionbox = {-2,-7,-2, 2,0.3,2}
					})
			end
		end

	elseif ent.add_rope_ative =="false" then
		for _, object in ipairs(minetest.get_objects_inside_radius(self.object:get_pos(),2)) do
			local luaentity = object:get_luaentity()
			
			if not object:is_player() and
					luaentity and
					luaentity.itemstring ~="" and
					luaentity.name~="searchandrescue:hook_entity" and
					luaentity.name~="searchandrescue:helicopter"then

					minetest.sound_play("item_drop_pickup", {to_player = clicker:get_player_name(),gain = 0.4,})
					object:set_detach()
					object:set_pos(vector.add({x = 0, y =-7, z =0}, self.object:get_pos()))

					self.object:set_properties({
						collisionbox = {-2,0,-2, 2,0.3,2}, selectionbox = {-2,0,-2, 2,0.3,2}
					})
	end	 end end end
