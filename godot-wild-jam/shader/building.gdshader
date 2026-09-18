shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 full_color : source_color = vec3(0.55, 0.55, 0.58);
uniform float fill_level : hint_range(0.0, 1.0) = 0.0;
uniform float door_dir : hint_range(0.0, 3.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 1.0;

uniform vec3 empty_color : source_color = vec3(0.20, 0.62, 0.52);
uniform vec3 window_lit : source_color = vec3(0.98, 0.87, 0.58);
uniform vec3 window_dark : source_color = vec3(0.10, 0.14, 0.18);
uniform vec3 door_color : source_color = vec3(0.30, 0.20, 0.15);

uniform float win_spacing_h = 2.6;   // world units between window columns
uniform float win_spacing_v = 3.0;   // world units between window rows
uniform float win_w = 1.1;           // window width
uniform float win_h = 1.5;           // window height
uniform float door_w = 1.5;
uniform float door_h = 2.3;
uniform float face_margin = 0.7;     // keep windows off the corners
uniform float edge_softness : hint_range(0.0, 0.2) = 0.02;


varying vec3 vpos;    // position in world-scale units, y from 0 at the base
varying vec3 vnorm;   // model-space normal
varying vec3 vsize;   // the building's actual world dimensions

void vertex() {
	// pull the real world size out of the model matrix, so window size
	// stays constant no matter how the box is scaled
	vsize = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	// BoxMesh is centred, so shift y into 0..1 before scaling up
	vpos = (VERTEX + vec3(0.0, 0.5, 0.0)) * vsize;
	vnorm = NORMAL;
}

void fragment() {
	float t = smoothstep(
		fill_level - edge_softness,
		fill_level + edge_softness,
		vpos.y / max(vsize.y, 0.001)
	);
	vec3 col = mix(empty_color, full_color, t);

	// roof and underside get no detail
	if (abs(vnorm.y) < 0.5) {
		bool on_x_face = abs(vnorm.x) > 0.5;
		float u = on_x_face ? vpos.z : vpos.x;
		float half_face = (on_x_face ? vsize.z : vsize.x) * 0.5;
		float v = vpos.y;

		// 0 = +Z, 1 = -Z, 2 = +X, 3 = -X
		int dd = int(door_dir + 0.5);
		bool facing =
			(dd == 0 && vnorm.z > 0.5) ||
			(dd == 1 && vnorm.z < -0.5) ||
			(dd == 2 && vnorm.x > 0.5) ||
			(dd == 3 && vnorm.x < -0.5);
		bool is_door = facing && (abs(u) < door_w * 0.5) && (v < door_h);

		if (is_door) {
			col = door_color;
		} else if (abs(u) < half_face - face_margin && v < vsize.y - 0.6) {
			// distance from the nearest window centre, in world units
			float du = abs(fract(u / win_spacing_h + 0.5) - 0.5) * win_spacing_h;
			float dv = abs(fract(v / win_spacing_v) - 0.5) * win_spacing_v;
			if (du < win_w * 0.5 && dv < win_h * 0.5) {
				col = mix(window_dark, window_lit, t);
			}
		}
	}

	ALBEDO = col * dim;
	ROUGHNESS = 0.9;
}