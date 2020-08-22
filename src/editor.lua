local Editor = {}

function Editor:enter()
  print("Sokoma editor")

  self.font = love.graphics.newFont(46)

  World.static = true
  if not World.exists then
    World:newLevel("New Level")
  else
    World:reset()
  end
  World.room:updateVisuals()

  self.brush_canvas = love.graphics.newCanvas(TILE_SIZE*4, TILE_SIZE*4)
  self.brush = nil
  self.placing_entrance = false
  self.painting = false

  self.room_tree = {}
  self:buildRoomTree()
end

function Editor:shift(ox, oy)
  for _,tile in ipairs(World.room.tiles) do
    Utils.removeFromTable(World.room.tiles_by_pos[tile.x..","..tile.y], tile)
    tile.x = tile.x + ox
    if not World.room:inBounds(tile.x, tile.y) then
      if ox > 0 then
        tile.x = 0
      else
        tile.x = World.room.width-1
      end
    end
    tile.y = tile.y + oy
    if not World.room:inBounds(tile.x, tile.y) then
      if oy > 0 then
        tile.y = 0
      else
        tile.y = World.room.height-1
      end
    end
    World.room.tiles_by_pos[tile.x..","..tile.y] = World.room.tiles_by_pos[tile.x..","..tile.y] or {}
    table.insert(World.room.tiles_by_pos[tile.x..","..tile.y], tile)
  end
  self:validateTiles()
  if World.room.entry then
    local sx, sy = World.room.entry[1], World.room.entry[2]
    if World.room:inBounds(sx+ox, sy) then
      sx = sx+ox
    else
      if ox > 0 then
        sx = 0
      else
        sx = World.room.width-1
      end
    end
    if World.room:inBounds(sx, sy+oy) then
      sy = sy+oy
    else
      if oy > 0 then
        sy = 0
      else
        sy = World.room.height-1
      end
    end
    World.room.entry = {sx, sy}
  end
end

function Editor:resize(w, h, shiftx, shifty)
  local old_w, old_h = World.room.width, World.room.height
  World.room.width = w
  World.room.height = h
  if shiftx or shifty then
    self:shift(shiftx or 0, shifty or 0)
  end
  self:validateTiles(old_w, old_h)
end

function Editor:validateTiles(width, height)
  -- loop through the whole map up to the specified width and height
  -- to remove oob tiles and create tables for all in-bounds positions
  for x = 0, math.max(width or 0, World.room.width)-1 do
    for y = 0, math.max(height or 0, World.room.height)-1 do
      if not World.room:inBounds(x, y) then
        for _,tile in ipairs(World.room:getTilesAt(x, y)) do
          World.room:removeTile(tile)
        end
      end
    end
  end
  if World.room.entry and not World.room:inBounds(World.room:getEntry()) then
    World.room.entry = nil
  end
end

function Editor:buildRoomTree()
  self.room_tree = {}
  local current_room = World:getRoom(World.main.root)
  for _,key in ipairs(World.main.start) do
    for _,tile in ipairs(current_room.tiles_by_name["room"] or {}) do
      if tile.key == key then
        table.insert(self.room_tree, tile)
        current_room = World:getRoom(tile.room_key)
        break
      end
    end
  end
end

function Editor:merge(name)
  local merged_key = World:merge(name)
  if merged_key then
    self.brush = Tile("room", 0, 0, {room = World:getRoom(merged_key), room_key = merged_key})
  end
  World:save()
  local current_room = World.room.key
  World:reset()
  World:changeRoom(current_room)
  World.room:updateVisuals()
end

function Editor:keypressed(key)
  local up    = key == "w" or key == "up"
  local left  = key == "a" or key == "left"
  local down  = key == "s" or key == "down"
  local right = key == "d" or key == "right"
  if key == "tab" then
    self:openTileSelector()
  elseif key == "s" and love.keyboard.isDown("ctrl") then
    if World.new or love.keyboard.isDown("shift") then
      Gamestate.push(TextInput, "New level name:", not World.new and World.main.name or "", function(text)
        if text ~= "" then
          World.main:rename(text)
        end
      end)
    else
      World:save()
    end
  elseif key == "o" and love.keyboard.isDown("ctrl") then
    Gamestate.push(TextInput, "Enter file name to load:", "", function(text)
      print("Loading "..text)
      World:load(text)
      World.room:updateVisuals()
      self:buildRoomTree()
    end)
  elseif key == "r" and love.keyboard.isDown("ctrl") then
    Gamestate.push(TextInput, "New sublevel name:", World.level.name, function(text)
      if text ~= "" then
        World.level:rename(text)
      end
    end)
  elseif key == "m" and love.keyboard.isDown("ctrl") then
    Gamestate.push(TextInput, "Merge level into current sublevel:", "", function(text)
      self:merge(text)
    end)
  elseif key == "n" and love.keyboard.isDown("ctrl") then
    World:newLevel("New Level")
  elseif key == "p" and love.keyboard.isDown("ctrl") then
    if not World.room.paradox_key then
      if World.room.paradox then
        print("leaving paradox")
        local non_paradox_room = World:getRoom(World.room.non_paradox_key)
        World:changeRoom(non_paradox_room)
        World.room:updateVisuals()
      else
        print("creating paradox")
        local new_paradox_room = Room(World.room.width, World.room.height, {
          paradox = true,
          palette = "paradox",
          non_paradox_room = World.room,
          non_paradox_key = World.room.key,
          exit = World.room.exit}
        )
        World:addRoom(new_paradox_room)
        World.room.paradox_room = new_paradox_room
        World.room.paradox_key = new_paradox_room.key
        World:changeRoom(new_paradox_room)
        World.room:updateVisuals()
      end
    else
      print("going to paradox")
      local paradox_room = World:getRoom(World.room.paradox_key)
      World:changeRoom(paradox_room)
      World.room:updateVisuals()
    end
  elseif key == "a" and love.keyboard.isDown("ctrl") then
    World.main.auto_rules = not World.main.auto_rules
  elseif right and love.keyboard.isDown("shift") then
    self:shift(1,0)
  elseif down and love.keyboard.isDown("shift") then
    self:shift(0,1)
  elseif left and love.keyboard.isDown("shift") then
    self:shift(-1,0)
  elseif up and love.keyboard.isDown("shift") then
    self:shift(0,-1)
  elseif right and love.keyboard.isDown("ctrl") then
    self:resize(World.room.width+1, World.room.height)
  elseif down and love.keyboard.isDown("ctrl") then
    self:resize(World.room.width, World.room.height+1)
  elseif left and love.keyboard.isDown("ctrl") then
    self:resize(World.room.width-1, World.room.height)
  elseif up and love.keyboard.isDown("ctrl") then
    self:resize(World.room.width, World.room.height-1)
  elseif right and self.brush then
    self.brush.dir = 1
  elseif down and self.brush then
    self.brush.dir = 2
  elseif left and self.brush then
    self.brush.dir = 3
  elseif up and self.brush then
    self.brush.dir = 4
  elseif key == "=" then
    self:resize(World.room.width+1, World.room.height+1)
  elseif key == "-" then
    self:resize(World.room.width-1, World.room.height-1)
  elseif key == "c" then
    Assets.addPalettes() --reload palettes ingame so you don't have to close and reopen to see changes
    Gamestate.push(TextInput, "Enter palette name:", "", function(text)
      if Assets.palettes[text] then
        World.room.palette = text
      else
        print("Palette "..text.." doesn't exist!")
        World.room.palette = "default"
      end
    end)
  elseif key == "q" then
    if love.keyboard.isDown("ctrl") then
      if not World.room.paradox then
        World.main.start = {}
        for _,tile in ipairs(self.room_tree) do
          table.insert(World.main.start, tile.key)
        end
      end
    else
      self.placing_entrance = not self.placing_entrance
    end
  elseif key == "p" then
    self.brush.persist = not self.brush.persist
  elseif key == "l" then
    if self.brush.name == "room" or self.brush.name == "line" then
      self.brush.locked = not self.brush.locked
    end
  elseif key == "i" then
    self.brush.icy = not self.brush.icy
  elseif key == "escape" then
    if #self.room_tree > 0 then
      World:changeRoom(table.remove(self.room_tree, #self.room_tree).parent)
    end
  elseif key == "return" then
    World:save()
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
      World.room.entry = {self.mx, self.my}
      self.placing_entrance = false
      return
    else
      if not love.keyboard.isDown("shift") then
        local tiles = World.room:getTilesAt(self.mx, self.my)
        for _,tile in ipairs(tiles) do
          if tile.name == "room" then
            local function enterTile()
              table.insert(self.room_tree, tile)
              World:changeRoom(tile.room_key)
              World.room:updateVisuals()
            end
            if not tile.room_key then
              if not love.keyboard.isDown("ctrl") then
                local room = Room(7, 7, {
                  paradox = World.room.paradox,
                  palette = World.room.palette
                })
                tile.room_key = World:addRoom(room)
                enterTile()
              else
                Gamestate.push(TextInput, "New sublevel name:", "", function(text)
                  if text ~= "" then
                    local level = World:createLevel(text, World.level)
                    tile.room_key = level.root
                    enterTile()
                    World:save()
                  end
                end)
              end
            else
              enterTile()
            end
            return
          elseif tile.name == "tile" then
            self:selectTileActivator(tile)
            return
          end
        end
      end
    end
  elseif btn == 3 or (btn == 2 and love.keyboard.isDown("shift")) then
    local tiles = World.room:getTilesAt(self.mx, self.my)
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
    self:placeTile(self.mx, self.my, love.keyboard.isDown("shift"), love.keyboard.isDown("ctrl"))
  elseif painting and love.mouse.isDown(2) and not love.keyboard.isDown("shift") then
    self:eraseTile(self.mx, self.my)
  end
end

function Editor:placeTile(x,y,stack,superstack)
  if not stack then
    self:eraseTile(x,y)
  end
  if World.room:inBounds(x,y) then
    local success = true
    if stack and not superstack then
      for _,tile in ipairs(World.room:getTilesAt(x,y)) do
        if tile.name == self.brush.name and tile.word == self.brush.word then
          success = false
          break
        end
      end
    elseif stack and superstack then
      painting = false
    end
    if success then
      local new_tile = self.brush:copy()
      new_tile.x = x
      new_tile.y = y
      World.room:addTile(new_tile)
      World.room:updateVisuals()
    end
  end
end

function Editor:eraseTile(x,y)
  if World.room:inBounds(x,y) then
    for _,tile in ipairs(World.room:getTilesAt(x,y)) do
      World.room:removeTile(tile)
    end
    World.room:updateVisuals()
  end
end

function Editor:isStart()
  if World.room.paradox or #World.main.start ~= #self.room_tree then
    return false
  end
  for i,key in ipairs(World.main.start) do
    if key ~= self.room_tree[i].key then
      return false
    end
  end
  return true
end

function Editor:selectTileActivator(maintile)
  local tiles = {}

  table.insert(tiles, Tile("tile", 0, 0, {parent = World.room}))
  for _,activator in ipairs(TILE_ACTIVATORS) do
    table.insert(tiles, Tile("tile", 0, 0, {activator = activator, parent = World.room}))
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
    local tile = Tile(name, 0, 0, {word = word, parent = World.room})
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
  transform:translate(-World.room.width*TILE_SIZE/2, -World.room.height*TILE_SIZE/2)
  return transform
end

function Editor:draw()
  love.graphics.setColor(0.75, 0.75, 0.75, 0.2)
  love.graphics.setFont(self.font)
  local text = "What is sokoma? Like what is that"
  love.graphics.print(text, love.graphics.getWidth()/2 - self.font:getWidth(text)/2, love.graphics.getHeight()/2 - self.font:getHeight()/2)
  
  local palette = Assets.palettes[World.room.palette]
  palette:setColor(8, 0)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  World.room:draw()

  local starsprite = Assets.sprites["tiles/star"]
  love.graphics.push()
  love.graphics.translate(Vector.mul(TILE_SIZE, World.room:getEntry()))
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

  if World.main.auto_rules then
    love.graphics.origin()
    love.graphics.scale(1.5, 1.5)
    local r,g,b = palette:getColor(8, 2)
    love.graphics.setColor(r, g, b, 0.5)
    love.graphics.draw(Assets.sprites["ui/auto_rules"], 4, 4)
  end
end

return Editor