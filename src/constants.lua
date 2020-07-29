TILE_SIZE = 24

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