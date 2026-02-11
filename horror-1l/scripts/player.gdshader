shader_type canvas_item;

uniform float strength : hint_range(0.0, 0.1) = 10.3;
uniform float speed : hint_range(0.0, 10.0) = 10.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    uv.x += sin(TIME * speed + uv.y * 100.0) * strength;
    uv.y += cos(TIME * speed + uv.x * 100.0) * strength;
    COLOR = texture(SCREEN_TEXTURE, uv);
    COLOR.rgb *= vec3(10.0, 30.3, 10.2); // Делаем мир чуть более зеленым/странным
}