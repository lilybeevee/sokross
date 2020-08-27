local SideEditor = {}

function SideEditor:enter(previous, tile)
  self.last_scene = previous
  self.tile = tile
end

function SideEditor:keypressed(key)
  if key == "escape" then
    Gamestate.pop()
  end
end

function SideEditor:mousepressed(x, y, btn)
  local tf = self:getTransform()
  local mx, my = tf:inverseTransformPoint(x, y)

  if btn == 1 then
    if mx >= -TILE_SIZE/2 and my >= -TILE_SIZE/2 and mx < TILE_SIZE + TILE_SIZE/2 and my < TILE_SIZE + TILE_SIZE/2 then
      self:toggleSide(math.floor(((math.atan2(y - love.graphics.getHeight()/2, x - love.graphics.getWidth()/2) / (2*math.pi) + (1/8)) % 1) * 4) + 1)
    else
      Gamestate.pop()
    end
  elseif btn == 2 then
    Gamestate.pop()
  end
end

function SideEditor:toggleSide(dir)
  if self.tile.sides[dir] == "none" then
    self.tile.sides[dir] = self.tile.side_type
  else
    self.tile.sides[dir] = "none"
  end
end

function SideEditor:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(8, 8)
  transform:translate(-TILE_SIZE/2, -TILE_SIZE/2)
  return transform
end

function SideEditor:draw()
  self.last_scene:draw()

  love.graphics.origin()
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  love.graphics.scale(8, 8)
  love.graphics.translate(-TILE_SIZE/2, -TILE_SIZE/2)
  self.tile:draw(Assets.palettes[World.room.palette])
end

return SideEditor