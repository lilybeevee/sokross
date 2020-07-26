local Editor = {}

Editor.selector_groups = {
  {}
}

function Editor:enter()
  print("Sokoma editor")

  self.font = love.graphics.newFont(46)

  self.width = 0
  self.height = 0
  self.tiles = {}
  self:resize(7, 7)

  self.tiles["1,1"] = {Tile("rule", 1, 1, {word = "flof"})}
  self.tiles["2,1"] = {Tile("rule", 2, 1, {word = "play"})}

  self.tiles["1,3"] = {Tile("rule", 1, 3, {word = "wall"})}
  self.tiles["2,3"] = {Tile("rule", 2, 3, {word = "stop"})}

  self.tiles["2,5"] = {Tile("flof", 2, 5, {dir = 2})}
end

function Editor:inBounds(x, y)
  return x >= 0 and x < self.width and y >= 0 and y < self.height
end

function Editor:shift(ox, oy)
  local new_tiles = {}
  for x = 0, self.width-1 do
    for y = 0, self.height-1 do
      new_tiles[x+ox..","..y+oy] = self.tiles[x..","..y]
      for _,tile in ipairs(self.tiles[x..","..y]) do
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
  local old_w, old_h = self.width, self.height
  self.width = w
  self.height = h
  if shiftx or shifty then
    self:shift(shiftx or 0, shifty or 0)
  end
  self:validateTiles(old_w, old_h)
end

function Editor:validateTiles(width, height)
  for x = 0, math.max(width or 0, self.width)-1 do
    for y = 0, math.max(height or 0, self.height)-1 do
      if not self:inBounds(x, y) then
        self.tiles[x..","..y] = nil
      elseif not self.tiles[x..","..y] then
        self.tiles[x..","..y] = {}
      end
    end
  end
  self.max_width = self.width
  self.max_height = self.height
end

function Editor:keypressed(key)
  if key == "right" and love.keyboard.isDown("lctrl") then
    self:resize(self.width+1, self.height)
  elseif key == "left" and love.keyboard.isDown("lctrl") then
    self:resize(self.width-1, self.height)
  elseif key == "down" and love.keyboard.isDown("lctrl") then
    self:resize(self.width, self.height+1)
  elseif key == "up" and love.keyboard.isDown("lctrl") then
    self:resize(self.width, self.height-1)
  end

  if key == "=" then
    self:resize(self.width+1, self.height+1)
  elseif key == "-" then
    self:resize(self.width-1, self.height-1)
  end
end

function Editor:update(dt)
  local tf = self:getTransform()
  self.mx, self.my = tf:inverseTransformPoint(love.mouse.getPosition())
  self.mx = math.floor(self.mx / TILE_SIZE)
  self.my = math.floor(self.my / TILE_SIZE)

  if love.mouse.isDown(1) then
    if self:inBounds(self.mx, self.my) then
      self.tiles[self.mx..","..self.my] = {Tile("wall", self.mx, self.my)}
    end
  elseif love.mouse.isDown(2) then
    if self:inBounds(self.mx, self.my) then
      self.tiles[self.mx..","..self.my] = {}
    end
  end
end

function Editor:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-self.width*TILE_SIZE/2, -self.height*TILE_SIZE/2)
  return transform
end

function Editor:draw()
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

  for x = 0, self.width-1 do
    for y = 0, self.height-1 do
      love.graphics.push()
      love.graphics.translate(x*TILE_SIZE, y*TILE_SIZE)

      for _,tile in ipairs(self.tiles[x..","..y]) do
        tile:draw(palette)
      end

      love.graphics.pop()
    end
  end

  love.graphics.origin()
  love.graphics.setColor(0.75, 0.75, 0.75, 0.2)
  love.graphics.setFont(self.font)
  local text = "shutterstock"
  love.graphics.print(text, love.graphics.getWidth()/2 - self.font:getWidth(text)/2, love.graphics.getHeight()/2 - self.font:getHeight()/2)
end

return Editor