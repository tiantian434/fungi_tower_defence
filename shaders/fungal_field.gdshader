shader_type canvas_item;
render_mode unshaded;

// xy 是地面中心，z 是当前半径，w 区分连通与失联。
uniform vec4 patches[64];
uniform int patch_count = 0;
uniform float ground_ratio = 0.7;
uniform vec4 live_color : source_color = vec4(0.32, 0.49, 0.29, 0.55);
uniform vec4 sleeping_color : source_color = vec4(0.40, 0.30, 0.21, 0.40);
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

void fragment() {
	float live_distance = 100000.0;
	float sleeping_distance = 100000.0;
	for (int i = 0; i < patch_count; i++) {
		if (patches[i].z <= 0.0) { continue; }
		vec2 offset = (ground_position - patches[i].xy) / vec2(1.0, ground_ratio);
		float distance_to_edge = length(offset) - patches[i].z;
		if (patches[i].w > 0.5) {
			live_distance = min(live_distance, distance_to_edge);
		} else {
			sleeping_distance = min(sleeping_distance, distance_to_edge);
		}
	}
	// 对所有区域取并集距离，内部重叠处不产生多层圆圈。
	float live_mask = 1.0 - smoothstep(-1.0, 1.0, live_distance);
	float sleeping_mask = 1.0 - smoothstep(-1.0, 1.0, sleeping_distance);
	float rim = 1.0 - smoothstep(0.0, 3.0, abs(live_distance));
	vec4 live = vec4(live_color.rgb + vec3(0.16, 0.20, 0.10) * rim, live_color.a);
	vec4 sleeping = vec4(sleeping_color.rgb, sleeping_color.a * sleeping_mask);
	COLOR = mix(sleeping, live, live_mask);
}
