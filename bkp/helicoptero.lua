--verssione 1 = 5.4.0
--verssione 0 = 5.5.0
local verssione=1
--
-- constants
--
local tilting_speed = 1
local tilting_max = 0.5
local power_max = 20
local power_min = 0.2 -- if negative, the helicopter can actively fly downwards
local wanted_vert_speed = 10
local friction_air_quadratic = 0.01
local friction_air_constant = 0.2
local friction_land_quadratic = 1
local friction_land_constant = 2
local friction_water_quadratic = 0.1
local friction_water_constant = 1


local eyes_set_y=24.5
local eyes_set_z=30
-- helpers and co.

if not minetest.global_exists("matrix3") then
	dofile(minetest.get_modpath("searchandrescue") .. DIR_DELIM .. "searchandrescue_api/matrix.lua")
end

local creative_exists = minetest.global_exists("creative")
local gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.8
local vector_up = vector.new(0, 1, 0)
local vector_forward = vector.new(0, 0, 1)

local function vector_length_sq(v)
	return v.x * v.x + v.y * v.y + v.z * v.z
end
------------------------------------------------------------------------------------------------------
local function check_node_below(obj)
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
local function heli_control(self, dtime, touching_ground, liquid_below, vel_before)
	local driver = minetest.get_player_by_name(self.driver_name)
	if not driver then
		-- there is no driver (eg. because driver left)
		self.driver_name = nil
		if self.sound_handle then
			minetest.sound_stop(self.sound_handle)
			self.sound_handle = nil
		end
		self.object:set_animation_frame_speed(0)
		self.object:set_acceleration(vector.multiply(vector_up, -gravity))	-- gravity
		return
	end
	local rot = self.object:get_rotation()
	local ctrl = driver:get_player_control()

	local vert_vel_goal = 0
	if not liquid_below then
		if ctrl.jump	then	vert_vel_goal = vert_vel_goal + wanted_vert_speed	end
		if ctrl.sneak	then	vert_vel_goal = vert_vel_goal - wanted_vert_speed	end
	else
		vert_vel_goal = wanted_vert_speed
	end

	-- rotation
	if not touching_ground then
		local tilting_goal = vector.new()
		if ctrl.up		then	tilting_goal.z = tilting_goal.z + 1	end
		if ctrl.down	then	tilting_goal.z = tilting_goal.z - 1	end
		if ctrl.right	then	tilting_goal.x = tilting_goal.x + 1	end
		if ctrl.left	then	tilting_goal.x = tilting_goal.x - 1	end

		tilting_goal = vector.multiply(vector.normalize(tilting_goal), tilting_max)

		-- tilting
		if vector_length_sq(vector.subtract(tilting_goal, self.tilting)) > (dtime * tilting_speed)^2 then
			self.tilting = vector.add(self.tilting,
					vector.multiply(vector.direction(self.tilting, tilting_goal), dtime * tilting_speed))
		else self.tilting = tilting_goal
		end

		if vector_length_sq(self.tilting) > tilting_max^2 then
			self.tilting = vector.multiply(vector.normalize(self.tilting), tilting_max)
		end
		local new_up = vector.new(self.tilting)
		new_up.y = 1
		new_up = vector.normalize(new_up) -- this is what vector_up should be after the rotation
		local new_right = vector.cross(new_up, vector_forward)
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
	power = math.min(math.max(power, power_min * dtime), power_max * dtime)
	local rotated_up = matrix3.multiply(matrix3.from_pitch_yaw_roll(rot), vector_up)
	local added_vel = vector.multiply(rotated_up, power)
	added_vel = vector.add(added_vel, vector.multiply(vector_up, -gravity * dtime))
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
		collisionbox = {-4,0,-4, 4,0.3,4},
		selectionbox = {-4,0,-4, 4,0.3,4},
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
		self.object:set_acceleration(vector.multiply(vector_up, -gravity))
	end,

on_detach= function(self)
	self.object:set_acceleration(vector.multiply(vector_up, -gravity))
end,
on_step = function(self, dtime)

		local touching_ground, liquid_below
		local vel = self.object:get_velocity()

		if self.driver_name then
			touching_ground, liquid_below = check_node_below(self.object)
			vel = heli_control(self, dtime, touching_ground, liquid_below, vel) or vel
		end

		if vel.x == 0 and vel.y == 0 and vel.z == 0 then return	end
		if touching_ground == nil then touching_ground, liquid_below = check_node_below(self.object) end

		-- quadratic and constant deceleration
		local speedsq = vector_length_sq(vel)
		local fq, fc
		if touching_ground 	then fq, fc = friction_land_quadratic, friction_land_constant
		elseif liquid_below then fq, fc = friction_water_quadratic, friction_water_constant
		else fq, fc = friction_air_quadratic, friction_air_constant
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
		local name = clicker:get_player_name()
		if not clicker or not clicker:is_player() then return end

		--if clicker:get_attach() == self.object then return end
		--clicker:get_attach() ~= self.object then return end
		if name~= self.driver_name then
			entrar_helicoptero(self, clicker)	
		end

		if name== self.driver_name then
			formulario_helicoptero(self, clicker)
		end
end
})
-------------------------------------------------------------------------------------------------------
--local entrope=false
function formulario_helicoptero(self, clicker)
		local name = clicker:get_player_name()
		local close=	"button_exit[0.2,5.9;3,1.8;close;close]"
		local goout=	"button_exit[4.8,5.9;3,1.8;go_out;go_out]"
		local cam_set=	"button[0.3,0.4;3,1.7;cam_set;cam_set]"
		local tools=	"button[4.7,0.4;3,1.8;tools;tools]"
		
		local formulario = "formspec_version[3] size[8,8]"..close..goout..cam_set..tools.."]"
		
		minetest.show_formspec(name,"man:helic",formulario)
		minetest.register_on_player_receive_fields(function(clicker, formname, fields)
			if formname ~= "man:helic" then return false end
				--if formname == "man:helic" then
						if fields.cam_set then
							
							camera_helicoptero(self, clicker)
						end
						if fields.go_out then 
							sair_helicoptero(self, clicker)
						end
						
						if fields.tools then 
							tools_helicoptero(self, clicker)
						end

			return true end )
end
------------------------------------------------------------------------------------------------------
--camera helicoptero
function camera_helicoptero(self, clicker)
		local name = clicker:get_player_name()
		local cam_up= "button[2.5,0.3;3,1.8;cam_up;cam_up]"
		local cam_down= "button[2.6,5.3;3,1.8;cam_down;cam_down]"
		local cam_front= "button[0.2,2.7;3,1.8;cam_front;cam_front]"
		local cam_back= "button[4.8,2.6;3,1.8;cam_back;cam_back]"
			
		local formulario_camera = "formspec_version[3] size[8,8]"..cam_up..cam_down..cam_front..cam_back.."]"
		minetest.show_formspec(name,"man:form_camera",formulario_camera)
				
			minetest.register_on_player_receive_fields(function(clicker, formname, fields)
			if formname == "man:form_camera" then
					if fields.cam_up and eyes_set_y<=50 then		eyes_set_y=eyes_set_y+1
					elseif fields.cam_down and eyes_set_y>=0 then	eyes_set_y=eyes_set_y-1
					elseif fields.cam_front and eyes_set_z<=50 then eyes_set_z=eyes_set_z+1
					elseif fields.cam_back and eyes_set_z>=0 then 	eyes_set_z=eyes_set_z-1
					end
					clicker:set_eye_offset( {x = 0, y = eyes_set_y, z =eyes_set_z}, {x = 0, y = 8, z = -5})
					minetest.chat_send_player(name, "cam_pos y:"..eyes_set_y.." z:"..eyes_set_z)
			return end
			return true end )
end
------------------------------------------------------------------------------------------------------
function tools_helicoptero(self, clicker)
local name = clicker:get_player_name()

	--pega valores da variavel na entity
	local ent = self.object:get_luaentity()

	local add_rope=	"checkbox[0.6,0.7;add_rope;add_rope;"..ent.add_rope_ative.."]"
	local close=	"button_exit[0.2,5.9;3,1.8;close;close]"
	local to_take=	"button[4.6,4;3,1.7;to_take;to_take]"
	local drop=		"button[4.6,5.9;3,1.7;drop;drop]"
	
	local tools_helicoptero = "formspec_version[3] size[8,8]"..add_rope..to_take..drop..close.."]"
	minetest.show_formspec(name,"man:tools_helicoptero",tools_helicoptero)
	
	minetest.register_on_player_receive_fields(function(clicker, formname, fields)
			if formname == "man:tools_helicoptero" then
					
					if fields.add_rope then
						if fields.add_rope=="true" then
							ent.add_rope_ative="true"
							roope_helicoptero(self, clicker)
						else
							ent.add_rope_ative="false"
							roope_helicoptero(self, clicker)
					end
						end 
			end 
			return true end )
end	

------------------------------------------------------------------------------------------------------
--function sair_helicoptero(clicker,self, formname, fields)
function sair_helicoptero(self, clicker)
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
			self.object:set_acceleration(vector.multiply(vector_up, -gravity))
end end
------------------------------------------------------------------------------------------------------

function entrar_helicoptero(self, clicker)
		--elseif not self.driver_name then
			-- no driver => clicker is new driver
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
function roope_helicoptero(self, clicker, rook)
		local ent = self.object:get_luaentity()
		--local rook={}
		local throw_starting_pos={}

		if ent.add_rope_ative=="true" then
		--local rope=minetest.add_entity({x=0, y=-5, z=0}, "searchandrescuehook_entity",driver:get_player_name())
				throw_starting_pos = vector.add({x=0, y=2, z=0}, self.object:get_pos())
				rook=minetest.add_entity(throw_starting_pos, "searchandrescue:hook_entity", name)
				rook:set_attach(self.object,"",{x = 0, y = -1.5, z =0}, {x = 0, y = 0, z = 0})
		else
			throw_starting_pos = vector.add({x=0, y=1.5, z=0}, self.object:get_pos())
			for _, object in ipairs(minetest.get_objects_inside_radius(throw_starting_pos,5)) do
			local luaentity = object:get_luaentity()
			if not object:is_player() and luaentity and luaentity.itemstring ~="" and luaentity.name=="searchandrescue:hook_entity"then
					minetest.sound_play("item_drop_pickup", {to_player = clicker:get_player_name(),gain = 0.4,})
					luaentity.itemstring = ""
					object:remove()
			end
		end

		end
		
end
