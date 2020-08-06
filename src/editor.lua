local Editor = {}

function Editor:enter()
  print("Sokoma editor")

  self.font = love.graphics.newFont(46)

  Level.static = true
  if not Level.exists then
    Level:new("new level")
  else
    Level:reset()
  end
  Level.room:updateVisuals()

  self.brush_canvas = love.graphics.newCanvas(TILE_SIZE*4, TILE_SIZE*4)
  self.brush = nil
  self.placing_entrance = false
  self.painting = false

  self.room_tree = {}
  self:buildRoomTree()
end

function Editor:shift(ox, oy)
  local new_tiles = {}
  for x = 0, Level.room.width-1 do
    for y = 0, Level.room.height-1 do
      new_tiles[x+ox..","..y+oy] = Level.room.tiles[x..","..y]
      for _,tile in ipairs(Level.room.tiles[x..","..y]) do
        tile.x = tile.x + ox
        tile.y = tile.y + oy
      end
    end
  end
  self:validateTiles()
end

function Editor:resize(w, h, shiftx, shifty)
  local old_w, old_h = Level.room.width, Level.room.height
  Level.room.width = w
  Level.room.height = h
  if shiftx or shifty then
    self:shift(shiftx or 0, shifty or 0)
  end
  self:validateTiles(old_w, old_h)
end

function Editor:validateTiles(width, height)
  -- loop through the whole map up to the specified width and height
  -- to remove oob tiles and create tables for all in-bounds positions
  for x = 0, math.max(width or 0, Level.room.width)-1 do
    for y = 0, math.max(height or 0, Level.room.height)-1 do
      if not Level.room:inBounds(x, y) then
        for _,tile in ipairs(Level.room:getTilesAt(x, y)) do
          Level.room:removeTile(tile)
        end
      end
    end
  end
  if Level.room.entry and not Level.room:inBounds(Level.room:getEntry()) then
    Level.room.entry = nil
  end
end

function Editor:buildRoomTree()
  self.room_tree = {}
  local current_room = Level.room
  while current_room.exit do
    table.insert(self.room_tree, 1, current_room.exit)
    current_room = current_room.exit.parent
  end
end

function Editor:merge(name)
  local merged_key = Level:merge(name)
  if merged_key then
    self.brush = Tile("room", 0, 0, {room = Level:getRoom(merged_key), room_key = merged_key})
  end
  Level:save()
  local current_room = Level.room.key
  Level:reset()
  Level:changeRoom(current_room)
  Level.room:updateVisuals()
end

function Editor:keypressed(key)
  if key == "tab" then
    self:openTileSelector()
  elseif key == "d" and self.brush then
    self.brush.dir = 1
  elseif key == "s" and self.brush and not love.keyboard.isDown("ctrl") then
    self.brush.dir = 2
  elseif key == "a" and self.brush then
    self.brush.dir = 3
  elseif key == "w" and self.brush then
    self.brush.dir = 4
  elseif key == "right" and love.keyboard.isDown("ctrl") then
    self:resize(Level.room.width+1, Level.room.height)
  elseif key == "left" and love.keyboard.isDown("ctrl") then
    self:resize(Level.room.width-1, Level.room.height)
  elseif key == "down" and love.keyboard.isDown("ctrl") then
    self:resize(Level.room.width, Level.room.height+1)
  elseif key == "up" and love.keyboard.isDown("ctrl") then
    self:resize(Level.room.width, Level.room.height-1)
  elseif key == "=" then
    self:resize(Level.room.width+1, Level.room.height+1)
  elseif key == "-" then
    self:resize(Level.room.width-1, Level.room.height-1)
  elseif key == "c" then
    -- feature: good coding
    if Level.room.palette == "default" then
      Level.room.palette = "blue"
    elseif Level.room.palette == "blue" then
      Level.room.palette = "pink"
    elseif Level.room.palette == "pink" then
      Level.room.palette = "default"
    end
  elseif key == "q" then
    if love.keyboard.isDown("ctrl") then
      if not Level.room.paradox then
        Level.start = {}
        for _,tile in ipairs(self.room_tree) do
          table.insert(Level.start, tile.key)
        end
        Level.start_key = Level.room.key
      end
    else
      self.placing_entrance = not self.placing_entrance
    end
  elseif key == "p" and love.keyboard.isDown("ctrl") then
    if not Level.room.paradox_key then
      if Level.room.paradox then
        print("leaving paradox")
        local non_paradox_room = Level:getRoom(Level.room.non_paradox_key)
        Level:changeRoom(non_paradox_room)
        Level.room:updateVisuals()
      else
        print("creating paradox")
        local new_paradox_room = Room(Level.room.width, Level.room.height, {
          paradox = true,
          palette = "paradox",
          non_paradox_room = Level.room,
          non_paradox_key = Level.room.key,
          exit = Level.room.exit}
        )
        Level:addRoom(new_paradox_room)
        Level.room.paradox_room = new_paradox_room
        Level.room.paradox_key = new_paradox_room.key
        Level:changeRoom(new_paradox_room)
        Level.room:updateVisuals()
      end
    else
      print("going to paradox")
      local paradox_room = Level:getRoom(Level.room.paradox_key)
      Level:changeRoom(paradox_room)
      Level.room:updateVisuals()
    end
  elseif key == "p" then
    self.brush.persist = not self.brush.persist
  elseif key == "l" then
    if self.brush.name == "room" or self.brush.name == "line" then
      self.brush.locked = not self.brush.locked
    end
  elseif key == "i" then
    self.brush.icy = not self.brush.icy
  elseif key == "s" and love.keyboard.isDown("ctrl") then
    if Level.new or love.keyboard.isDown("shift") then
      Gamestate.push(TextInput, "File to save level as:", not Level.new and Level.name or "", function(text)
        Level.name = text
        Level:save()
      end)
    else
      Level:save()
    end
  elseif key == "o" and love.keyboard.isDown("ctrl") then
    Gamestate.push(TextInput, "Enter file name to load:", "", function(text)
      print("Loading "..text)
      Level:load(text)
      Level.room:updateVisuals()
      self:buildRoomTree()
    end)
  elseif key == "m" and love.keyboard.isDown("ctrl") then
    Gamestate.push(TextInput, "Level name to merge:", "", function(text)
      self:merge(text)
    end)
  elseif key == "escape" then
    if #self.room_tree > 0 then
      Level:changeRoom(table.remove(self.room_tree, #self.room_tree).parent)
    end
  elseif key == "return" then
    if not Level.mounted then
      Level:save()
    end
    Gamestate.switch(Game)
  elseif key == "`" then --debug
    print("nya")
  end
end

function Editor:filedropped(file)
  local path = file:getFilename()
  local pathtree = path:split("/\\")
  local filename = pathtree[#pathtree]

  if filename:sub(-4) == ".zip" then
    local lvlname = filename:sub(1, -5)
    love.filesystem.mount(path, "levels/"..lvlname)
    self:merge(lvlname)
    love.filesystem.unmount(path)
  end
end

function Editor:directorydropped(path)
  local pathtree = path:split("/\\")
  local lvlname = pathtree[#pathtree]

  love.filesystem.mount(path, "levels/"..lvlname)
  self:merge(lvlname)
  love.filesystem.unmount(path)
end

function Editor:mousepressed(x, y, btn)
  if btn == 1 then
    if self.placing_entrance then
      Level.room.entry = {self.mx, self.my}
      self.placing_entrance = false
      return
    else
      if not love.keyboard.isDown("shift") then
        local tiles = Level.room:getTilesAt(self.mx, self.my)
        for _,tile in ipairs(tiles) do
          if tile.name == "room" then
            if not tile.room_key then
              local room = Room(7, 7, {
                paradox = Level.room.paradox,
                palette = Level.room.palette
              })
              tile.room_key = Level:addRoom(room)
            end
            table.insert(self.room_tree, tile)
            Level:changeRoom(tile.room_key)
            Level.room:updateVisuals()
            return
          elseif tile.name == "tile" then
            self:selectTileActivator(tile)
            return
          end
        end
      end
    end
  elseif btn == 3 or (btn == 2 and love.keyboard.isDown("shift")) then
    local tiles = Level.room:getTilesAt(self.mx, self.my)
    if #tiles > 0 then
      self.brush = tiles[1]:copy()
      return
    end
  end
  painting = true
end

function Editor:mousereleased(x, y, btn)
  painting = false
end

function Editor:update(dt)
  local tf = self:getTransform()
  self.mx, self.my = tf:inverseTransformPoint(love.mouse.getPosition())
  self.mx = math.floor(self.mx / TILE_SIZE)
  self.my = math.floor(self.my / TILE_SIZE)

  if painting and love.mouse.isDown(1) and self.brush then
    self:placeTile(self.mx, self.my)
  elseif painting and love.mouse.isDown(2) and not love.keyboard.isDown("shift") then
    self:eraseTile(self.mx, self.my)
  end
end

function Editor:placeTile(x,y,stack)
  if not stack then
    self:eraseTile(x,y)
  end
  if Level.room:inBounds(x,y) then
    local success = true
    if stack then
      for _,tile in ipairs(Level.room:getTilesAt(x,y)) do
        if tile.name == self.brush.name and tile.word == self.brush.word then
          success = false
          break
        end
      end
    end
    if success then
      local new_tile = self.brush:copy()
      new_tile.x = x
      new_tile.y = y
      Level.room:addTile(new_tile)
      Level.room:updateVisuals()
    end
  end
end

function Editor:eraseTile(x,y)
  if Level.room:inBounds(x,y) then
    for _,tile in ipairs(Level.room:getTilesAt(x,y)) do
      Level.room:removeTile(tile)
    end
    Level.room:updateVisuals()
  end
end

function Editor:isStart()
  if Level.room.paradox or #Level.start ~= #self.room_tree then
    return false
  end
  for i,key in ipairs(Level.start) do
    if key ~= self.room_tree[i].key then
      return false
    end
  end
  return true
end

function Editor:selectTileActivator(maintile)
  local tiles = {}

  table.insert(tiles, Tile("tile", 0, 0, {parent = Level.room}))
  for _,activator in ipairs(TILE_ACTIVATORS) do
    table.insert(tiles, Tile("tile", 0, 0, {activator = activator, parent = Level.room}))
  end

  Gamestate.push(Selector, tiles, function(tile)
    maintile.activator = tile.activator
  end)
end

function Editor:openTileSelector()
  local tiles = {}
  local added_word = {}

  local function addTile(name, word)
    if word and added_word[word] then
      return
    elseif word then
      added_word[word] = true
    end
    local tile = Tile(name, 0, 0, {word = word, parent = Level.room})
    table.insert(tiles, tile)
  end

  for _,data in ipairs(Assets.tiles_list) do
    local name = data.name
    if not data.unselectable then
      addTile(name)
      if Assets.words[name] then
        addTile("rule", name)
      end
      if data.property then
        addTile("rule", data.property)
      end
    end
  end
  for _,data in ipairs(Assets.words_list) do
    local name = data.name
    if not data.unselectable then
      addTile("rule", name)
    end
  end

  Gamestate.push(Selector, tiles, function(tile)
    self.brush = tile:copy()
  end)
end

function Editor:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-Level.room.width*TILE_SIZE/2, -Level.room.height*TILE_SIZE/2)
  return transform
end

function Editor:draw()
  love.graphics.setColor(0.75, 0.75, 0.75, 0.2)
  love.graphics.setFont(self.font)
  local text = "What is sokoma? Like what is that"
  love.graphics.print(text, love.graphics.getWidth()/2 - self.font:getWidth(text)/2, love.graphics.getHeight()/2 - self.font:getHeight()/2)
  
  local palette = Assets.palettes[Level.room.palette]
  palette:setColor(8, 0)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  Level.room:draw()

  local starsprite = Assets.sprites["tiles/star"]
  love.graphics.push()
  love.graphics.translate(Vector.mul(TILE_SIZE, Level.room:getEntry()))
  local r, g, b
  if self:isStart() then
    r,g,b = palette:getColor(7, 3)  
  else
    r,g,b = palette:getColor(6, 3)
  end
  love.graphics.setColor(r,g,b,0.5)
  love.graphics.draw(starsprite)
  love.graphics.pop()

  if self.placing_entrance then
    love.graphics.translate(self.mx*TILE_SIZE, self.my*TILE_SIZE)
    love.graphics.setColor(r,g,b,0.5)
    love.graphics.draw(starsprite)
  elseif self.brush then
    self.brush:draw(palette)

    love.graphics.translate(self.mx*TILE_SIZE + TILE_SIZE/2, self.my*TILE_SIZE + TILE_SIZE/2)
    love.graphics.scale(0.5, 0.5)

    if self.brush.persist then -- draw greennesss
      local r,g,b = palette:getColor(6, 3)
      love.graphics.setColor(r, g, b, 0.5)
      love.graphics.setShader(OUTLINE_SHADER)
      OUTLINE_SHADER:send("pixelsize", {1/TILE_CANVAS:getWidth(), 1/TILE_CANVAS:getHeight()})
      OUTLINE_SHADER:send("size", 3)
      love.graphics.draw(TILE_CANVAS, -TILE_CANVAS:getWidth()/2, -TILE_CANVAS:getHeight()/2)
      love.graphics.setShader()
    end
    if self.brush.icy then
      love.graphics.setColor(0, 1, 1, 0.5)
    else
      love.graphics.setColor(1, 1, 1, 0.5)
    end
    love.graphics.draw(TILE_CANVAS, -TILE_CANVAS:getWidth()/2, -TILE_CANVAS:getHeight()/2)
  end
end

return Editor