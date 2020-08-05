Gamestate = require "lib.hump.gamestate"
Class = require "lib.hump.class"
Timer = require "lib.hump.timer"
Vector = require "lib.hump.vector-light"
JSON = require "lib.json"
require "lib.slam"

require "src.constants"
Utils = require "src.utils"
Assets = require "src.assets"
Dir = require "src.dir"

Game = require "src.game"
Editor = require "src.editor"
Selector = require "src.selector"
Level = require "src.level"
Tile = require "src.tile"
Room = require "src.room"
Rules = require "src.rules"
Movement = require "src.movement"
Undo = require "src.undo"
TextInput = require "src.textinput"

function love.load()
  print("Sokoma? What's that")

  love.graphics.setDefaultFilter("nearest","nearest")
  Assets.load()
  Gamestate.registerEvents()
  Gamestate.switch(Editor)
end