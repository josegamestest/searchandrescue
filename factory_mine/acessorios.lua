minetest.register_node("factory_mine:factory_mine_light", {
	description ="factory_mine_light",
	drawtype = "nodebox", 
    use_texture_alpha ="clip",
	paramtype = "light",
	is_ground_content = false,
	sunlight_propagates = true,
    light_source = 10,
	drop = "",
    groups = {cracky=3,oddly_breakable_by_hand=3,torch=1,not_in_creative_inventory=1},
    tiles = {{
		name = "factory_mine_light.png", animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1,}}}
    })
