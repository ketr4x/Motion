shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

uniform float desaturation : hint_range(0.0, 1.0) = 0.15;
uniform float tint_factor : hint_range(0.0, 1.0) = 0.05;
uniform vec4 tint_color : source_color = vec4(0.95, 0.95, 0.9, 1.0); // old monitor yellow-ish tint
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.001;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.06;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.015;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Chromatic Aberration
    float offset = chromatic_aberration;
    float r = texture(SCREEN_TEXTURE, uv + vec2(offset, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - vec2(offset, 0.0)).b;
    vec3 color = vec3(r, g, b);
    
    // Desaturation
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color, vec3(gray), desaturation);
    
    // Tint
    color = mix(color, tint_color.rgb, tint_factor);
    
    // Scanlines
    // Based on typical internal Y pixel heights, scaled down
    float scanline = sin(uv.y * 400.0 * 3.14159) * 0.5 + 0.5; 
    color -= scanline * scanline_intensity * color;
    
    // Film grain / Noise
    float noise = random(uv + vec2(TIME * 0.1)) * 2.0 - 1.0;
    color += noise * noise_intensity;
    
    COLOR = vec4(color, 1.0);
}
