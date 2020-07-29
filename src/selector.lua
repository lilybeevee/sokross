local Selector = {}

function Selector:enter(from)
  self.from = from
  self.tiles = {}
  self.width = 12
  self.height = 6
  self.grid = 28
  
  self.added_word = {}
  for _,data in ipairs(Assets.tiles_list) do
    local name = data.name
    if not data.unselectable then
      self:addTile(name)
      if Assets.words[name] then
        self:addTile("rule", name)
      end
      if data.property then
        self:addTile("rule", data.property)
      end
    end
  end
  for _,data in ipairs(Assets.words_list) do
    local name = data.name
    if not data.unselectable then
      self:addTile("rule", name)
    end
  end
end

function Selector:addTile(name, word)
  if word and self.added_word[word] then
    return
  elseif word then
    self.added_word[word] = true
  end
  local tile = Tile(name, 0, 0, {word = word, parent = Level.room})
  table.insert(self.tiles, tile)
end

function Selector:keypressed(key)
  if key == "tab" or key == "escape" then
    Gamestate.pop()
  end
end

function Selector:mousereleased(x, y, btn)
  if self.selected and self.tiles[self.selected] and btn == 1 then
    self.from.brush = self.tiles[self.selected]:copy()
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
  love.graphics.rectangle("fill", 0, 0, self.grid*self.width, self.grid*self.height)

  local palette = Assets.palettes[Level.room.palette]

  for i,tile in ipairs(self.tiles) do
    local x, y = ((i-1) % self.width) * self.grid, math.floor((i-1) / self.width) * self.grid
    love.graphics.push()
    love.graphics.translate(x, y)
    if self.selected == i then
      love.graphics.setColor(1, 1, 1, 0.5)
      love.graphics.rectangle("fill", 0, 0, self.grid, self.grid)
    end
    love.graphics.translate(self.grid/2 - TILE_SIZE/2, self.grid/2 - TILE_SIZE/2)
    tile:draw(palette)
    love.graphics.pop()
  end
end

return Selector