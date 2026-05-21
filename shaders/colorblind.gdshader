// Filtro de daltonización (corrección): Vienot 1999 / Brettel-Mollon 1997.
// Sin funciones de usuario ni if/else — requerido por el driver GL Compat de este sistema.
// Modos: 0=ninguno, 1=protanopia, 2=deuteranopia, 3=tritanopia
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float mode = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float contrast_boost : hint_range(0.8, 1.4) = 1.08;
uniform float saturation_boost : hint_range(0.8, 1.4) = 1.05;

void fragment() {
	vec3 rgb = texture(screen_tex, SCREEN_UV).rgb;

	// RGB → LMS (Vienot 1999), completamente inline
	float L = 17.8824 * rgb.r    + 43.5161  * rgb.g + 4.11935  * rgb.b;
	float M =  3.45565 * rgb.r   + 27.1554  * rgb.g + 3.86714  * rgb.b;
	float S =  0.0299566 * rgb.r + 0.184309 * rgb.g + 1.46709  * rgb.b;

	// Pesos branchless por modo (step+mix, cero if/else)
	float is_prot   = step(0.5, mode) * (1.0 - step(1.5, mode));
	float is_deut   = step(1.5, mode) * (1.0 - step(2.5, mode));
	float is_trit   = step(2.5, mode);
	float is_active = step(0.5, mode);

	// Simular pérdida del cono: solo el canal afectado se reemplaza
	float Ls = mix(L, 2.02344 * M  - 2.52581 * S,  is_prot);
	float Ms = mix(M, 0.494207 * L + 1.24827  * S,  is_deut);
	float Ss = mix(S, -0.395913 * L + 0.801109 * M, is_trit);

	// LMS → RGB (simulado, clampeado para evitar valores extremos)
	float sr = clamp( 0.0809444479  * Ls - 0.130504409   * Ms + 0.116721066  * Ss, 0.0, 1.0);
	float sg = clamp(-0.0102485335  * Ls + 0.0540193266  * Ms - 0.113614708  * Ss, 0.0, 1.0);
	float sb = clamp(-0.000365296938 * Ls - 0.00412161469 * Ms + 0.693511405  * Ss, 0.0, 1.0);

	// Info perdida entre original y simulado
	float er = rgb.r - sr;
	float eg = rgb.g - sg;
	float eb = rgb.b - sb;

	// Redistribuir error hacia canales perceptibles (branchless)
	vec3 delta_pd   = vec3(0.0, eg + er * 0.7, eb + er * 0.7);
	vec3 delta_trit = vec3(eb * 0.2, eb * 0.25, 0.0);
	vec3 corrected  = clamp(rgb + mix(delta_pd, delta_trit, is_trit), 0.0, 1.0);

	// Blend con strength; mode=0 → is_active=0 → passthrough
	vec3 blended = mix(rgb, corrected, strength * is_active);

	// Boost sutil de contraste y saturación
	float luma     = dot(blended, vec3(0.299, 0.587, 0.114));
	vec3 saturated = mix(vec3(luma), blended, saturation_boost);
	COLOR = vec4(clamp((saturated - 0.5) * contrast_boost + 0.5, 0.0, 1.0), 1.0);
}
