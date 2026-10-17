shader_type canvas_item;

uniform vec2 speed = vec2(-0.15, 0.25); 

void fragment() {
	vec2 uv = UV + speed * TIME;
	COLOR = texture(TEXTURE, uv);
}
