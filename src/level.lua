local Level = {}

function Level:init()
  self.font = love.graphics.newFont(46)

  self.width = 7
  self.height = 7
  self.tiles = {}
  for x=0,self.width-1 do
    for y=0,self.height-1 do
      self.tiles[x..","..y] = {}
    end
  end
  self.tiles_by_layer = {}
  for i=1,7 do
    Level.tiles_by_layer[i] = {}
  end

  self.tiles["1,1"] = {Tile("rule", 1, 1, {word = "flof"})}
  self.tiles["2,1"] = {Tile("rule", 2, 1, {word = "play"})}

  self.tiles["1,3"] = {Tile("rule", 1, 3, {word = "wall"})}
  self.tiles["2,3"] = {Tile("rule", 2, 3, {word = "stop"})}

  self.tiles["2,5"] = {Tile("flof", 2, 5, {dir = 2})}
end

function Level:inBounds(x, y)
  return x >= 0 and x < self.width and y >= 0 and y < self.height
end

function Level:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-self.width*TILE_SIZE/2, -self.height*TILE_SIZE/2)
  return transform
end

function Level:draw()
  love.graphics.setColor(0.75, 0.75, 0.75, 0.2)
  love.graphics.setFont(self.font)
  local text = "What is sokoma? Like what is that"
  love.graphics.print(text, love.graphics.getWidth()/2 - self.font:getWidth(text)/2, love.graphics.getHeight()/2 - self.font:getHeight()/2)
  
  local palette = Assets.palettes["default"]
  palette:setColor(0, 1)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  for x = 0, self.width-1 do
    for y = 0, self.height-1 do
      if (x+y) % 2 == 0 then
        palette:setColor(0, 3)
      else
        palette:setColor(0, 4)
      end
      love.graphics.rectangle("fill", x*TILE_SIZE, y*TILE_SIZE, TILE_SIZE, TILE_SIZE)
    end
  end

  for i=1,7 do
    for tile,_ in pairs(self.tiles_by_layer[i]) do
      love.graphics.push()
      love.graphics.translate(tile.x*TILE_SIZE, tile.y*TILE_SIZE)
      tile:draw(palette)
      love.graphics.pop()
    end
  end
end

return Level