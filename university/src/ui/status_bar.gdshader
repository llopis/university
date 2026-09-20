shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	float a = UV.y;
	COLOR = vec4(a*COLOR.r, a*COLOR.g, a*COLOR.b, 1.0-a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
