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

--
-- helpers and co.

if not minetest.global_exists("matrix3") then
	dofile(minetest.get_modpath("searchandrescue") .. DIR_DELIM .. "matrix.lua")
end

local creative_exists = minetest.global_exists("creative")
local gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.8
local vector_up = vector.new(0, 1, 0)
local vector_forward = vector.new(0, 0, 1)

local function vector_length_sq(v)
	return v.x * v.x + v.y * v.y + v.z * v.z
end

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
	
	if ctrl.jump and ctrl.sneak then
		--minetest.chat_send_all("controle f")
		helicoptero(self, driver)
	end

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

--
-- entity
--

minetest.register_entity("searchandrescue:helicopter", {
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = {-1,0,-1, 1,0.3,1},
		selectionbox = {-1,0,-1, 1,0.3,1},
		visual = "mesh",
		mesh = "helicoptero.b3d",
		textures = {"helicoptero.png"},
	},

	driver_name = nil,
	sound_handle = nil,
	tilting = vector.new(),

	on_activate = function(self)
		-- set the animation once and later only change the speed
		self.object:set_animation({x = 0, y = 5}, 0, 0, true)
		self.object:set_armor_groups({immortal=1})
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

	on_punch = function(self, puncher)
		if not puncher or not puncher:is_player() then return end

		local name = puncher:get_player_name()
		-- do not allow other players to remove the object while there is a driver
		if self.driver_name and self.driver_name ~= name then return end

		if self.sound_handle then minetest.sound_stop(self.sound_handle) self.sound_handle = nil end
		if self.driver_name then
			-- detach the driver first (puncher must be driver)
			puncher:set_detach()
			puncher:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
			player_api.player_attached[name] = nil
			-- player should stand again
			player_api.set_animation(puncher, "stand")
			self.driver_name = nil
		end

		self.object:remove()
		minetest.handle_node_drops(self.object:get_pos(), {"searchandrescue:helicopter"}, puncher)
	end,
	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then return end

		local name = clicker:get_player_name()
		if name == self.driver_name then
			-- driver clicked the object => driver gets off the vehicle
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

		elseif not self.driver_name then
			-- no driver => clicker is new driver
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

	end,
})
-- items
minetest.register_craftitem("searchandrescue:blades",{description = "Helicopter Blades", inventory_image = "helicopter_blades.png",}) -- blades
minetest.register_craftitem("searchandrescue:cabin",{ description = "Cabin for Helicopter", inventory_image = "cabin_inv.png", })-- cabin
minetest.register_craftitem("searchandrescue:heli", { description = "Helicopter", inventory_image = "heli_inv.png", -- heli

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then return end
		if minetest.get_node(pointed_thing.above).name ~= "air" then return end
		minetest.add_entity(pointed_thing.above, "searchandrescue:helicopter")
		if not (creative_exists and placer and creative.is_enabled_for(placer:get_player_name())) then itemstack:take_item()
			end return itemstack
	end,
})

-- crafting
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

function helicoptero(self, driver)
      --local rope=minetest.add_entity({x=0, y=-5, z=0}, "searchandrescuehook_entity",driver:get_player_name())
			local throw_starting_pos = vector.add({x=0, y=1.5, z=0}, driver:get_pos())
			local rook=minetest.add_entity(throw_starting_pos, "searchandrescue:hook_entity", driver:get_player_name())
			rook:set_attach(self.object,"",{x = 0, y = -1.5, z =0}, {x = 0, y = 0, z = 0})
			
      --minetest.after(0, function() driver:get_inventory():remove_item("main", "searchandrescuerope") end)
    end
