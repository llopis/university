shader_type spatial;
// Grass with a thin scale grid. Lines are placed from world position, so the
// grid stays put whatever the mesh or the camera does. Purely visual: the sim
// has no grid.

uniform vec3 grass_color : source_color = vec3(0.36, 0.55, 0.29);
uniform vec3 line_color : source_color = vec3(0.29, 0.46, 0.24);
// Metres between lines, and a line's width in metres.
uniform float grid_spacing = 10.0;
uniform float line_width = 0.2;
// Lines fade out between these distances from the camera, where they would
// otherwise shimmer.
uniform float fade_start = 400.0;
uniform float fade_end = 1200.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metres from this fragment to the nearest grid line, per axis.
	vec2 to_line = abs(fract(world_pos.xz / grid_spacing - 0.5) - 0.5) * grid_spacing;
	// Metres one pixel covers: the anti-aliasing band. A line thinner than a
	// pixel keeps its share of the pixel instead of popping in and out.
	vec2 pixel = max(fwidth(world_pos.xz), vec2(0.00001));
	vec2 cover = clamp((0.5 * line_width + 0.5 * pixel - to_line) / pixel, 0.0, 1.0);
	cover *= min(vec2(1.0), line_width / pixel);
	float line = max(cover.x, cover.y);
	float fade = 1.0 - smoothstep(fade_start, fade_end, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = mix(grass_color, line_color, line * fade);
	ROUGHNESS = 1.0;
}
