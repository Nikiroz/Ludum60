shader_type canvas_item;

uniform float game_time = 0.0;
uniform vec2 speed = vec2(-0.15, 0.25);

void fragment() {
    vec2 uv = UV + speed * game_time;
    COLOR = texture(TEXTURE, uv);
}