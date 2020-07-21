Gamestate = require "lib.hump.gamestate"
Class = require "lib.hump.class"
Timer = require "lib.hump.timer"
Vector = require "lib.hump.vector-light"

Assets = require "src.assets"

Game = require "src.game"
Editor = require "src.editor"

function love.load()
  print("Sokoma? What's that")

  Assets.load()
  Gamestate.registerEvents()
  Gamestate.switch(Editor)
end