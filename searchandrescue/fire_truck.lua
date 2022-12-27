                    --1         2               3               4                5
                --veiculo, imagem_veiculo,  carenagem_veiculo, icone_veiculo, core_icone
local vehicles={
                {"fire_truck","fire_truck.png","fire_truck.b3d","fire_truck_icon.png"},
        }
local STEPH = 1 -- Stepheight, 10 = climb slabs, 0.1 = climb nodes
local function is_ground(pos)
  local nn = minetest.get_node(pos).name
  return minetest.get_item_group(nn, "stone") ~= 0
end

local function get_sign(i)
  if i == 0 then return 0
  else
    return i / math.abs(i)
	end
end

local function get_velocity(v, yaw, y)
  local x = -math.sin(yaw) * v
  local z =  math.cos(yaw) * v
  return {x = x, y = y, z = z}
end

local function get_v(v) return math.sqrt(v.x ^ 2 + v.z ^ 2) end

--
-- Car entity
--vehicles  carroceria  icone base

local fire_truck = {
  physical = true,
  selection_box = {type = "fixed",fixed = {-1, -0.5,-1.5, 1, 1.3, 1.5}},
  collision_box = {type = "fixed",fixed = {-1, -0.5, -1.5, 1, 1.3, 1.5}},
  visual = "mesh",
  mesh = vehicles[1][3],
  backface_culling = false,
  textures = {vehicles[1][2]},
  stepheight = STEPH,
  --drawtype="allfaces",
  driver = nil,
  v = 1,
  last_v = 1,
  removed = false
}

local function DetachPlayer(self, clicker, is_driver)
  local pname = clicker:get_player_name()
  clicker:set_detach()
  default.player_attached[pname] = false
  default.player_set_animation(clicker, "stand" , 30)
  if not is_driver then
    clicker:set_eye_offset({x=0, y=-0, z=1}, {x=0, y=0, z=0})
  end
  return nil
end

function fire_truck.on_rightclick(self, clicker)
  if not clicker or not clicker:is_player() then return end
  local name = clicker:get_player_name()
  if self.driver and clicker == self.driver then
    self.driver = nil
    clicker:set_detach()
    default.player_attached[name] = false
    default.player_set_animation(clicker, "stand" , 30)
    local pos = clicker:get_pos()

    pos = {x = pos.x, y = pos.y + 0.1, z = pos.z}
    clicker:set_eye_offset({x=0, y=0, z=0}, {x=0, y=1, z=0})
    minetest.after(0.1, function()
      clicker:set_pos(pos)
    end)
  elseif not self.driver then
    self.driver = clicker
    clicker:set_attach(self.object, "",{x = -3, y = -0.2, z = 0},{x = 0, y = 0, z = 0})

    --minetest.after(0.2, function()
	default.player_set_animation(clicker, "sit" , 30)
    clicker:set_eye_offset({x=-0, y=0.9, z=0}, {x=0, y=0, z=0})
    default.player_attached[name] = true
    --end)
    self.object:set_yaw(clicker:get_look_horizontal() - math.pi / 2)
  end
end

function fire_truck.on_activate(self, staticdata, dtime_s)
  self.object:set_armor_groups({immortal = 1})
  if staticdata then
    self.v = tonumber(staticdata)
  end
  self.last_v = self.v
end


function fire_truck.get_staticdata(self)
  return tostring(self.v)
end


function fire_truck.on_punch(self, puncher, time_from_last_punch, tool_capabilities, direction)
  if not puncher or not puncher:is_player() or self.removed then return end
  if self.driver and puncher == self.driver then
    self.driver = nil
    puncher:set_detach()
    default.player_attached[puncher:get_player_name()] = false
  end
  if not self.driver then
    self.removed = true
    -- delay remove to ensure player is detached
    minetest.after(0.1, function()
    puncher:get_inventory():add_item("main", "searchandrescue:"..vehicles[1][1])
	self.object:remove()
    end)
  end
end


function fire_truck.on_step(self, dtime)
  self.v = get_v(self.object:get_velocity()) * get_sign(self.v)
  if self.driver then
    local ctrl = self.driver:get_player_control()
    local yaw = self.object:get_yaw()
    if ctrl.up then
      self.v = self.v + 0.1
    elseif ctrl.down then
      self.v = self.v - 0.1
    end
    if ctrl.left then
      if self.v < 0 then
        self.object:set_yaw(yaw - (1 + dtime) * 0.03)
      else
        self.object:set_yaw(yaw + (1 + dtime) * 0.03)
      end
    elseif ctrl.right then
      if self.v < 0 then
        self.object:set_yaw(yaw + (1 + dtime) * 0.03)
      else
        self.object:set_yaw(yaw - (1 + dtime) * 0.03)
      end
    end
  end
  local velo = self.object:get_velocity()
  if self.v == 0 and velo.x == 0 and velo.y == 0 and velo.z == 0 then
    self.object:set_pos(self.object:get_pos())
    return
  end
  local s = get_sign(self.v)
  self.v = self.v - 0.02 * s
  if s ~= get_sign(self.v) then
    self.object:set_velocity({x = 0, y = 0, z = 0})
    self.v = 0
    return
  end
  if math.abs(self.v) > 5 then
    self.v = 5 * get_sign(self.v)
  end

  local p = self.object:get_pos()
  p.y = p.y - 0.5
  local new_velo = {x = 0, y = 0, z = 0}
  local new_acce = {x = 0, y = 0, z = 0}
  if not is_ground(p) then
    local nodedef = minetest.registered_nodes[minetest.get_node(p).name]
    if (not nodedef) or nodedef.walkable then
      self.v = 1 new_acce = {x = 0, y = 1, z = 0}
    else
      new_acce = {x = 0, y = -9.8, z = 0}
    end
    new_velo = get_velocity(self.v, self.object:get_yaw(),
      self.object:get_velocity().y)
    self.object:set_pos(self.object:get_pos())
  else
    p.y = p.y + 1
    if is_ground(p) then

	  local y = self.object:get_velocity().y
      if y >= 24 then y = 24
      elseif y < 0 then new_acce = {x = 0, y = 3, z = 0}
      else new_acce = {x = 0, y = 8, z = 0}
      end

      new_velo = get_velocity(self.v, self.object:get_yaw(), y)
      self.object:set_pos(self.object:get_pos())
    else
      new_acce = {x = 0, y = 0, z = 0}
      if math.abs(self.object:get_velocity().y) < 1 then
        local pos = self.object:get_pos()
        pos.y = math.floor(pos.y) + 0.5
        self.object:set_pos(pos)
        new_velo = get_velocity(self.v, self.object:get_yaw(), 0)
      else
        new_velo = get_velocity(self.v, self.object:get_yaw(),
          self.object:get_velocity().y)
        self.object:set_pos(self.object:get_pos())
      end
    end
  end
  self.object:set_velocity(new_velo)
  self.object:set_acceleration(new_acce)
end

minetest.register_entity("searchandrescue:"..vehicles[1][1], fire_truck)

minetest.register_craftitem("searchandrescue:"..vehicles[1][1], {
  description = vehicles[1][1],
  inventory_image = vehicles[1][4],
  wield_image = vehicles[1][4],
  wield_scale = {x = 1, y = 1, z = 1},

  liquids_pointable = true,

  on_place = function(itemstack, placer, pointed_thing)
    if pointed_thing.type ~= "node" then
      return
    end
    if not is_ground(pointed_thing.under) then
    --  return
    end
    pointed_thing.under.y = pointed_thing.under.y + 1
    minetest.add_entity(pointed_thing.under, "searchandrescue:"..vehicles[1][1])
    itemstack:take_item()
    --[[if not minetest.settings:get("creative_mode") then
    itemstack:take_item()
    end]]
    return itemstack
  end,
})
