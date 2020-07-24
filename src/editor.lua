local Editor = {}

function Editor:enter()
  print("Sokoma editor")

  self.font = love.graphics.newFont(46)
  self.test1 = Tile("rule", 0, 0, {word = "flof"})
  self.test2 = Tile("flof", 1, 0)
  self.test3 = Tile("rule", 0, 1, {word = "not"})
  self.test4 = Tile("rule", 1, 1, {word = "play"})
end

function Editor:draw()
  love.graphics.setColor(1, 1, 1, 0.2)
  love.graphics.setFont(self.font)
  local text = "What is Sokoma. Like what is that"
  love.graphics.print(text, love.graphics.getWidth()/2 - self.font:getWidth(text)/2, love.graphics.getHeight()/2 - self.font:getHeight()/2)

  love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  love.graphics.scale(2, 2)

  love.graphics.translate(-TILE_SIZE, -TILE_SIZE)
  self.test1:draw(Assets.palettes["default"])
  love.graphics.translate(TILE_SIZE, 0)
  self.test2:draw(Assets.palettes["default"])
  love.graphics.translate(-TILE_SIZE, TILE_SIZE)
  self.test3:draw(Assets.palettes["default"])
  love.graphics.translate(TILE_SIZE, 0)
  self.test4:draw(Assets.palettes["default"])
end

return Editor