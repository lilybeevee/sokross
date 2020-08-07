local Selector = {}

function Selector:enter(from, list, func)
  self.from = from
  self.tiles = list
  self.func = func
  self.width = math.min(#list, 12)
  self.height = math.floor((#list-1) / 12) + 1
  self.grid = 28
end

function Selector:keypressed(key)
  if key == "tab" or key == "escape" then
    Gamestate.pop()
  end
end

function Selector:mousepressed(x, y, btn)
  if self.selected and self.tiles[self.selected] and btn == 1 then
    if self.func then
      self.func(self.tiles[self.selected])
    end
    Gamestate.pop()
  end
end

function Selector:update()
  local tf = self:getTransform()
  self.mx, self.my = tf:inverseTransformPoint(love.mouse.getPosition())
  self.mx = math.floor(self.mx / self.grid)
  self.my = math.floor(self.my / self.grid)

  if self.mx >= 0 and self.mx < self.width and self.my >= 0 and self.my < self.height then
    self.selected = self.my*self.width + self.mx + 1
  else
    self.selected = nil
  end
end

function Selector:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate((-self.width/2) * self.grid, (-self.height/2) * self.grid)
  return transform
end

function Selector:draw()
  self.from:draw()
  love.graphics.origin()

  love.graphics.applyTransform(self:getTransform())
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", -TILE_SIZE/2, -TILE_SIZE/2, self.grid*self.width + TILE_SIZE, self.grid*self.height + TILE_SIZE)

  local palette = Assets.palettes[World.room.palette]

  for i,tile in ipairs(self.tiles) do
    local x, y = ((i-1) % self.width) * self.grid, math.floor((i-1) / self.width) * self.grid
    love.graphics.push()
    love.graphics.translate(x, y)
    if self.selected == i then
      love.graphics.setColor(1, 1, 1, 0.2)
      love.graphics.rectangle("fill", 0, 0, self.grid, self.grid)
    end

    tile:draw(palette)
    love.graphics.translate(self.grid/2, self.grid/2)
    love.graphics.scale(0.5, 0.5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(TILE_CANVAS, -TILE_CANVAS:getWidth()/2, -TILE_CANVAS:getHeight()/2)
    love.graphics.pop()
  end
end

return Selector