local Room = Class{}

function Room:init(width, height, o)
  o = o or {}

  if o.id then
    self.id = o.id
  elseif not Level.static then
    self.id = Level.room_id
    Level.room_id = Level.room_id + 1
    Level.rooms_by_id[self.id] = self
  else
    self.id = 0
  end

  self.width = width
  self.height = height

  self.key = o.key
  self.palette = o.palette or "default"
  self.exit = o.exit
  self.entry = o.entry

  self.exit_as = o.exit_as
  self.exit_dir = o.exit_dir or 2
  
  self.paradox = o.paradox or false
  self.paradox_room = o.paradox_room
  self.paradox_key = o.paradox_key
  self.non_paradox_room = o.non_paradox_room
  self.non_paradox_key = o.non_paradox_key
  
  self.void = o.void
  self.heaven = o.heaven

  self.tiles = {}
  self.tiles_by_pos = {}
  self.tiles_by_name = {}
  self.tiles_by_layer = {}
  for i=1,7 do
    self.tiles_by_layer[i] = {}
  end

  self.rules = Rules(self)
  self.rules:addInherents()
  self.last_parsed = 0
end

function Room:getParent()
  return self.exit and self.exit.parent
end

function Room:getLayer()
  if not self:getParent() then
    return 1
  else
    return self:getParent():getLayer() + 1
  end
end

function Room:parse()
  self.rules:parse()
  self.last_parsed = Game.turn
end

function Room:parseIfNecessary()
  if self.last_parsed == 0 then
    self:parse()
  end
end

function Room:enter(tile, dir)
  Level:changeRoom(self)
  if tile.parent and tile.parent:getLayer() < self:getLayer() then
    if tile then
      self.exit_as = tile:save()
    end
    self.exit_dir = Dir.reverse(dir) or self.exit_dir
  end
  if self.last_parsed == 0 or (self.exit and self:getParent().last_parsed > self.last_parsed) then
    self:parse()
  end
end

function Room:getEntry()
  if not self.entry then
    return math.ceil(self.width/2)-1, math.ceil(self.height/2)-1
  else
    return unpack(self.entry)
  end
end

function Room:addTile(tile)
  table.insert(self.tiles, tile)

  tile.parent = self

  if not self.tiles_by_pos[tile.x..","..tile.y] then
    self.tiles_by_pos[tile.x..","..tile.y] = {tile}
  else
    table.insert(self.tiles_by_pos[tile.x..","..tile.y], tile)
  end

  if not self.tiles_by_name[tile.name] then
    self.tiles_by_name[tile.name] = {tile}
  else
    table.insert(self.tiles_by_name[tile.name], tile)
  end

  table.insert(self.tiles_by_layer[tile.layer], tile)
end

function Room:removeTile(tile)
  Utils.removeFromTable(self.tiles, tile)
  Utils.removeFromTable(self.tiles_by_pos[tile.x..","..tile.y], tile)
  Utils.removeFromTable(self.tiles_by_name[tile.name], tile)
  Utils.removeFromTable(self.tiles_by_layer[tile.layer], tile)
end

function Room:updateLines()
  local already_checked = {}
  local function unlockAround(x,y)
    for i = 1, 4 do
      local dx, dy = Dir.toPos(i)
      if not already_checked[x+dx..","..y+dy] then
        already_checked[x+dx..","..y+dy] = true

        local has_room = false
        local has_line = false
        for _,tile in ipairs(self:getTilesAt(x+dx, y+dy)) do
          if tile.name == "room" then
            has_room = true
            tile.locked = false
          elseif tile.name == "line" then
            has_line = true
            tile.locked = false
          end
        end
        if not has_room and has_line then
          unlockAround(x+dx, y+dy)
        end
      end
    end
  end
  for _,tile in ipairs(self.tiles) do
    if tile.name == "room" then
      if tile:getActivated() then
        tile.locked = false
        unlockAround(tile.x, tile.y)
      end
    end
  end
end

function Room:updateTiles()
  for _,tile in ipairs(self.tiles) do
    tile:update()
  end
end

function Room:getTilesAt(x, y)
  if self.tiles_by_pos[x..","..y] then
    return Utils.copy(self.tiles_by_pos[x..","..y])
  else
    return {}
  end
end

function Room:getTilesByName(name)
  return self.tiles_by_name[name] or {}
end

function Room:inBounds(x, y)
  return x >= 0 and x < self.width and y >= 0 and y < self.height
end

function Room:getRules(...)
  return self.rules:get(...)
end

function Room:hasRule(...)
  return #self:getRules(...) > 0
end

function Room:draw()
  local palette = Assets.palettes[self.palette]

  for x = 0, self.width-1 do
    for y = 0, self.height-1 do
      if self.void then
        love.graphics.setColor(0, 0, 0)
      else
        if (x+y) % 2 == 0 then
          palette:setColor(8, 1)
        else
          palette:setColor(8, 2)
        end
      end
      love.graphics.rectangle("fill", x*TILE_SIZE, y*TILE_SIZE, TILE_SIZE, TILE_SIZE)
    end
  end

  for i=1,7 do
    for _,tile in ipairs(self.tiles_by_layer[i]) do
      love.graphics.push()
      love.graphics.translate(tile.x*TILE_SIZE, tile.y*TILE_SIZE)
      tile:draw(palette)
      love.graphics.pop()
    end
  end
end

function Room:getParadoxEntry(tile)
  local function getCoordsTo(room)
    local tf = Game:getTransform()
    local old_x, old_y = tf:transformPoint(tile.x*TILE_SIZE, tile.y*TILE_SIZE)
    local new_tf = love.math.newTransform()
    new_tf:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
    new_tf:scale(2, 2)
    new_tf:translate(-room.width*TILE_SIZE/2, -room.height*TILE_SIZE/2)
    local new_x, new_y = new_tf:inverseTransformPoint(old_x, old_y)
    return math.floor(new_x/TILE_SIZE), math.floor(new_y/TILE_SIZE)
  end
  if self.paradox_room then
    local x, y = getCoordsTo(self.paradox_room)
    return x, y, self.paradox_room
  elseif self.paradox_key then
    local room = Level:getRoom(self.paradox_key)
    self.paradox_room = room
    local x, y = getCoordsTo(room)
    return x, y, room
  else
    if self.paradox then
      local room = Level:getVoid()
      room.exit = self.exit
      local x, y = getCoordsTo(room)
      return x, y, room
    elseif self.void then
      if tile:hasRule("play") then
        local room = Level:getHeaven()
        room.exit = self.exit
        return 2, 2, room
      else
        local room = Level:getVoid()
        room.exit = self.exit
        local x, y = getCoordsTo(room)
        return x, y, room
      end
    else
      local room = Level:getParadox(self)
      self.paradox_room = room
      self.paradox_key = room.key
      room.exit = self.exit
      local x, y = getCoordsTo(room)
      return x, y, room
    end
  end
end

function Room:win()
  local has_exit = false
  for _,exitrule in ipairs(self:getRules(nil, "exit")) do
    if #self:getTilesByName(exitrule.target) > 0 then
      has_exit = true
      break
    end
  end
  if has_exit and self:getParent() then
    Level:changeRoom(self:getParent())
    Level.room:win()
  else
    Level.room_won[self.key] = true
    if self.exit then
      local dx, dy = Dir.toPos(self.exit_dir)
      local exiter
      if self.exit_as then
        exiter = Tile.load(self.exit_as)
        exiter.dir = self.exit_dir
      else
        exiter = Tile(Level.player, self.exit.x+dx, self.exit.y+dy, {dir = self.exit_dir})
      end
      self:getParent():addTile(exiter)
      Level:changeRoom(self:getParent())
      self.exit.room = Level:getRoom(self.key)
      self.exit.room.exit = self.exit
    else -- ideally this can't happen unless you're just playtesting from editor
      Gamestate.switch(Editor)
    end
  end
end

function Room:save()
  local tiles = {}
  for _,tile in ipairs(self.tiles) do
    table.insert(tiles, tile:save())
  end

  local data = {}
  data.width = self.width
  data.height = self.height
  data.key = self.key
  if self.palette ~= "default" then
    data.palette = self.palette
  end
  if self.paradox then data.paradox = self.paradox end
  data.paradox_key = self.paradox_key
  data.non_paradox_key = self.non_paradox_key
  if self.void then data.void = self.void end
  if self.heaven then data.heaven = self.heaven end
  data.entry = self.entry
  data.tiles = tiles
  
  return data
end

function Room.load(data)
  local room = Room(data.width, data.height, {
    key = data.key,
    palette = data.palette,
    paradox = data.paradox,
    paradox_key = data.paradox_key or data.paradox_room_key,
    non_paradox_key = data.non_paradox_key or data.non_paradox_room_key,
    void = data.void,
    heaven = data.heaven,
    entry = data.entry,
  })

  for _,tiledata in ipairs(data.tiles) do
    room:addTile(Tile.load(tiledata))
  end

  return room
end

return Room