local Editor = {}

Editor.selector_groups = {
  {}
}

function Editor:enter()
  print("Sokoma editor")

  self.font = love.graphics.newFont(46)
  self.room = Room(7, 7)

  self.room:addTile(Tile("rule", 1, 1, {word = "flof"}))
  self.room:addTile(Tile("rule", 2, 1, {word = "play"}))

  self.room:addTile(Tile("rule", 1, 3, {word = "wall"}))
  self.room:addTile(Tile("rule", 2, 3, {word = "stop"}))

  self.room:addTile(Tile("flof", 2, 5, {dir = 2}))
end

function Editor:shift(ox, oy)
  local new_tiles = {}
  for x = 0, self.room.width-1 do
    for y = 0, self.room.height-1 do
      new_tiles[x+ox..","..y+oy] = self.room.tiles[x..","..y]
      for _,tile in ipairs(self.room.tiles[x..","..y]) do
        tile.x = tile.x + ox
        tile.y = tile.y + oy
      end
    end
  end
  self.max_width = math.max(self.max_width, x+ox)
  self.max_height = math.max(self.max_height, y+ox)
  self:validateTiles()
end

function Editor:resize(w, h, shiftx, shifty)
  local old_w, old_h = self.room.width, self.room.height
  self.room.width = w
  self.room.height = h
  if shiftx or shifty then
    self:shift(shiftx or 0, shifty or 0)
  end
  self:validateTiles(old_w, old_h)
end

function Editor:validateTiles(width, height)
  -- loop through the whole map up to the specified width and height
  -- to remove oob tiles and create tables for all in-bounds positions
  for x = 0, math.max(width or 0, self.room.width)-1 do
    for y = 0, math.max(height or 0, self.room.height)-1 do
      if not self.room:inBounds(x, y) then
        for _,tile in ipairs(self.room:getTilesAt(x, y)) do
          self.room:removeTile(tile)
        end
      end
    end
  end
end

function Editor:keypressed(key)
  if key == "right" and love.keyboard.isDown("lctrl") then
    self:resize(self.room.width+1, self.room.height)
  elseif key == "left" and love.keyboard.isDown("lctrl") then
    self:resize(self.room.width-1, self.room.height)
  elseif key == "down" and love.keyboard.isDown("lctrl") then
    self:resize(self.room.width, self.room.height+1)
  elseif key == "up" and love.keyboard.isDown("lctrl") then
    self:resize(self.room.width, self.room.height-1)
  elseif key == "=" then
    self:resize(self.room.width+1, self.room.height+1)
  elseif key == "-" then
    self:resize(self.room.width-1, self.room.height-1)
  elseif key == "`" then --debug
    print(dump(self.room.tiles_by_layer))
  end
end

function Editor:update(dt)
  local tf = self:getTransform()
  self.mx, self.my = tf:inverseTransformPoint(love.mouse.getPosition())
  self.mx = math.floor(self.mx / TILE_SIZE)
  self.my = math.floor(self.my / TILE_SIZE)

  if love.mouse.isDown(1) then
    self:placeTile(self.mx, self.my, "wall")
  elseif love.mouse.isDown(2) then
    self:eraseTile(self.mx, self.my)
  end
end

function Editor:placeTile(x,y,name,o)
  self:eraseTile(x,y)
  if self.room:inBounds(x,y) then
    self.room:addTile(Tile(name,x,y,o))
  end
end

function Editor:eraseTile(x,y)
  if self.room:inBounds(x,y) then
    for _,tile in ipairs(self.room:getTilesAt(x,y)) do
      self.room:removeTile(tile)
    end
  end
end

function Editor:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-self.room.width*TILE_SIZE/2, -self.room.height*TILE_SIZE/2)
  return transform
end

function Editor:draw()
  love.graphics.setColor(0.75, 0.75, 0.75, 0.2)
  love.graphics.setFont(self.font)
  local text = "What is sokoma? Like what is that"
  love.graphics.print(text, love.graphics.getWidth()/2 - self.font:getWidth(text)/2, love.graphics.getHeight()/2 - self.font:getHeight()/2)
  
  Assets.palettes[self.room.palette]:setColor(0, 1)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  self.room:draw()
end

return Editor