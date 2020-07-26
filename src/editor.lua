local Editor = {}

Editor.selector_groups = {
  {}
}

function Editor:enter()
  print("Sokoma editor")
  Level:init()
end

function Editor:shift(ox, oy)
  local new_tiles = {}
  for x = 0, Level.width-1 do
    for y = 0, Level.height-1 do
      new_tiles[x+ox..","..y+oy] = Level.tiles[x..","..y]
      for _,tile in ipairs(Level.tiles[x..","..y]) do
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
  local old_w, old_h = Level.width, Level.height
  Level.width = w
  Level.height = h
  if shiftx or shifty then
    self:shift(shiftx or 0, shifty or 0)
  end
  self:validateTiles(old_w, old_h)
end

function Editor:validateTiles(width, height)
  for x = 0, math.max(width or 0, Level.width)-1 do
    for y = 0, math.max(height or 0, Level.height)-1 do
      if not Level:inBounds(x, y) then
        Level.tiles[x..","..y] = nil
      elseif not Level.tiles[x..","..y] then
        Level.tiles[x..","..y] = {}
      end
    end
  end
  self.max_width = Level.width
  self.max_height = Level.height
end

function Editor:keypressed(key)
  if key == "right" and love.keyboard.isDown("lctrl") then
    self:resize(Level.width+1, Level.height)
  elseif key == "left" and love.keyboard.isDown("lctrl") then
    self:resize(Level.width-1, Level.height)
  elseif key == "down" and love.keyboard.isDown("lctrl") then
    self:resize(Level.width, Level.height+1)
  elseif key == "up" and love.keyboard.isDown("lctrl") then
    self:resize(Level.width, Level.height-1)
  elseif key == "=" then
    self:resize(Level.width+1, Level.height+1)
  elseif key == "-" then
    self:resize(Level.width-1, Level.height-1)
  elseif key == "`" then --debug
    print(dump(Level.tiles_by_layer))
  end
end

function Editor:update(dt)
  local tf = Level:getTransform()
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
  if Level:inBounds(x,y) then
    Level.tiles[x..","..y] = {Tile(name,x,y,o)}
  end
end

function Editor:eraseTile(x,y)
  if Level:inBounds(x,y) then
    for _,tile in ipairs(Level.tiles[x..","..y]) do
      Level.tiles_by_layer[tile.layer][tile] = nil
    end
    Level.tiles[x..","..y] = {}
  end
end

function Editor:draw()
  Level:draw()
end

return Editor