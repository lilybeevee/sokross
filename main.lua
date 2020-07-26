Gamestate = require "lib.hump.gamestate"
Class = require "lib.hump.class"
Timer = require "lib.hump.timer"
Vector = require "lib.hump.vector-light"

require "src.utils"
require "src.constants"
Assets = require "src.assets"
Tile = require "src.tile"

Game = require "src.game"
Editor = require "src.editor"
Level = require "src.level"

function love.load()
  print("Sokoma? What's that")

  love.graphics.setDefaultFilter("nearest","nearest")
  Assets.load()
  Gamestate.registerEvents()
  Gamestate.switch(Editor)
end