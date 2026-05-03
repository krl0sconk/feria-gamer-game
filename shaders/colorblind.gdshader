// Filtro de daltonización (correction, no simulation): toma la imagen ya
// renderizada del viewport, calcula qué color VE un daltónico, mide la
// diferencia con el original ("info perdida"), y la proyecta sobre los
// canales que SÍ percibe — así rojos y verdes que se confunden quedan
// separables.
//
// Algoritmo: Fidaner-Lin-Ozguven (2005), adaptado de Brettel-Viénot-Mollon
// (1997). Es el mismo que usan League of Legends y Overwatch.
//
// Modos:
//   0 = none         (passthrough, no debería invocarse — el overlay se
//                     oculta cuando mode==0 para ahorrar el shader pass)
//   1 = protanopia   (sin conos rojos)
//   2 = deuteranopia (sin conos verdes — el más común)
//   3 = tritanopia   (sin conos azules — raro)
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform int mode : hint_range(0, 3) = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.5;

// RGB ↔ LMS (espacio de respuesta de los conos de la retina).
const mat3 RGB_TO_LMS = mat3(
	vec3(17.8824,    43.5161,    4.11935),
	vec3( 3.45565,   27.1554,    3.86714),
	vec3( 0.0299566,  0.184309,  1.46709)
);

const mat3 LMS_TO_RGB = mat3(
	vec3( 0.0809444479, -0.130504409,   0.116721066),
	vec3(-0.0102485335,  0.0540193266, -0.113614708),
	vec3(-0.000365296938, -0.00412161469, 0.693511405)
);

// Matrices de simulación: "qué LMS ve el daltónico". Cada una elimina la
// respuesta del cono faltante y la reemplaza por la combinación que un
// dicrómata percibiría en su lugar (planos de Brettel).
const mat3 PROT_SIM = mat3(
	vec3(0.0, 2.02344, -2.52581),
	vec3(0.0, 1.0,      0.0),
	vec3(0.0, 0.0,      1.0)
);

const mat3 DEUT_SIM = mat3(
	vec3(1.0,      0.0, 0.0),
	vec3(0.494207, 0.0, 1.24827),
	vec3(0.0,      0.0, 1.0)
);

const mat3 TRIT_SIM = mat3(
	vec3( 1.0,       0.0,      0.0),
	vec3( 0.0,       1.0,      0.0),
	vec3(-0.395913,  0.801109, 0.0)
);

// Matriz de proyección de la "info perdida" (Daltonization). La info que
// el dicrómata no puede ver en su canal faltante se desplaza a los que SÍ
// percibe. Para deuteranopia (verde-débil) eso significa empujar el verde
// perdido hacia rojo y azul.
const mat3 SHIFT = mat3(
	vec3(0.0, 0.0, 0.0),
	vec3(0.7, 1.0, 0.0),
	vec3(0.7, 0.0, 1.0)
);


void fragment() {
	vec3 rgb = texture(screen_tex, SCREEN_UV).rgb;

	if (mode == 0) {
		COLOR = vec4(rgb, 1.0);
	} else {
		mat3 sim_matrix;
		if (mode == 1) {
			sim_matrix = PROT_SIM;
		} else if (mode == 2) {
			sim_matrix = DEUT_SIM;
		} else {
			sim_matrix = TRIT_SIM;
		}

		// 1) RGB → LMS. 2) Simular pérdida del cono. 3) LMS → RGB.
		vec3 lms = RGB_TO_LMS * rgb;
		vec3 simulated = LMS_TO_RGB * (sim_matrix * lms);
		// 4) Diferencia = info perdida. 5) Proyectar a canales visibles.
		vec3 err = rgb - simulated;
		vec3 corrected = rgb + SHIFT * err;
		COLOR = vec4(clamp(mix(rgb, corrected, strength), vec3(0.0), vec3(1.0)), 1.0);
	}
}
