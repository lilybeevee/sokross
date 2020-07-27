Gamestate = require "lib.hump.gamestate"
Class = require "lib.hump.class"
Timer = require "lib.hump.timer"
Vector = require "lib.hump.vector-light"

require "src.constants"
Utils = require "src.utils"
Assets = require "src.assets"
Tile = require "src.tile"

Game = require "src.game"
Editor = require "src.editor"
Room = require "src.room"
Rules = require "src.rules"

function love.load()
  print("Sokoma? What's that")

  love.graphics.setDefaultFilter("nearest","nearest")
  Assets.load()
  Gamestate.registerEvents()
  Gamestate.switch(Game)
end