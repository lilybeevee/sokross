TILE_SIZE = 24
KEY_REPEAT = 0.21

DIR_POS = {
  [1] = { 1,  0},
  [2] = { 0,  1},
  [3] = {-1,  0},
  [4] = { 0, -1}
}
DIR_REVERSE = {
  [1] = 3,
  [2] = 4,
  [3] = 1,
  [4] = 2
}

MOVE_KEYS = {
  d     = 1,
  s     = 2,
  a     = 3,
  w     = 4,
  right = 1,
  down  = 2,
  left  = 3,
  up    = 4,
}

DEFAULT_RULES = {
  {"flof", "play"},
  {"wall", "stop"},
  {"box", "push"},
  {"ladder", "exit"},
  {"belt", "move"},
  {"belt", "flat"},
  {"room", "push"},
  {"rule", "push"},
  {"tile", "flat"},
}

TILE_ACTIVATORS = {"box", "flof", "ladder", "room", "rule", "wall"}


TILE_CANVAS = love.graphics.newCanvas(TILE_SIZE*4, TILE_SIZE*4)

OUTLINE_SHADER = love.graphics.newShader([[
	extern vec2 pixelsize;
	extern float size = 1;

	vec4 effect(vec4 color, Image texture, vec2 uv, vec2 fc) {
    float a = 0;
    if(Texel(texture, uv).a == 0) {
      for(float y = -size; y <= size; ++y) {
        for(float x = -size; x <= size; ++x) {
          a += Texel(texture, uv + vec2(x * pixelsize.x, y * pixelsize.y)).a;
        }
      }
    }
    a = color.a * min(1, a);

		return vec4(color.rgb, a);
	}
]])