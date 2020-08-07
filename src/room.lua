local Room = Class{}

function Room:init(width, height, o)
  o = o or {}

  if o.id then
    self.id = o.id
  elseif not World.static then
    self.id = World.room_id
    World.room_id = World.room_id + 1
    World.rooms_by_id[self.id] = self
    if not o.static then
      World.rooms_by_key[o.key] = World.rooms_by_key[o.key] or {}
      table.insert(World.rooms_by_key[o.key], self)
    end
  else
    self.id = 0
  end

  self.width = width
  self.height = height

  self.key = o.key
  self.static = o.static or false
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

function Room:remove()
  if not World.static then
    World.rooms_by_id[self.id] = nil
    if not self.static then
      Utils.removeFromTable(World.rooms_by_key[self.key], self)
    end
  end
  for _,tile in ipairs(self.tiles) do
    tile:remove()
  end
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
  World:changeRoom(self)
  if tile.parent and tile.parent:getLayer() < self:getLayer() then
    if tile then
      self.exit_as = tile:save()
    end
    self.exit_dir = Dir.reverse(dir) or self.exit_dir
  end
  if self.last_parsed == 0 or (self:getParent() and self:getParent().last_parsed > self.last_parsed) then
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

function Room:addTile(tile, ignore_persist)
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

  if tile.persist and not World.static then
    if not Utils.contains(World.persists_in_room[self.key], tile.key) then
      if not World.persists[tile.key] then
        World.persists[tile.key] = tile:save()
      end
      table.insert(World.persists_in_room[self.key], tile.key)

      if not ignore_persist then
        for _,room in ipairs(World.rooms_by_key[self.key] or {}) do
          if room ~= self then
            local tile = Tile.load(World.persists[tile.key])
            Undo:add("add", tile.id)
            room:addTile(tile, true)
            Game.parse_room[room] = true
          end
        end
      end
    end
  end

  tile:add()
  return tile
end

function Room:removeTile(tile, ignore_persist)
  Utils.removeFromTable(self.tiles, tile)
  Utils.removeFromTable(self.tiles_by_pos[tile.x..","..tile.y], tile)
  Utils.removeFromTable(self.tiles_by_name[tile.name], tile)
  Utils.removeFromTable(self.tiles_by_layer[tile.layer], tile)
  if tile.persist and not World.static then
    Utils.removeFromTable(World.persists_in_room[self.key], tile.key)

    if not ignore_persist then
      local to_remove = {}
      for _,linked in ipairs(World.tiles_by_key[tile.key] or {}) do
        if linked ~= tile then
          table.insert(to_remove, linked)
        end
      end
      for _,linked in ipairs(to_remove) do
        Game.parse_room[linked.parent] = true
        Undo:add("remove", linked:save(true), linked.parent.id)
        linked.parent:removeTile(linked, true)
      end
    end
  end
  tile:remove()
  tile.parent = nil
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

function Room:updateVisuals()
  for _,tile in ipairs(self.tiles) do
    tile:updateVisuals()
  end
end

function Room:updateTiles()
  local to_destroy = {}
  local moves = {}
  for _,tile in ipairs(self.tiles) do
    if not Game.updated_tiles[tile] then
      local new_to_destroy, new_moves = tile:update()
      for _,new in ipairs(new_to_destroy) do
        table.insert(to_destroy, new)
      end
      for _,new in ipairs(new_moves) do
        table.insert(moves, new)
      end
    end
  end
  Game:handleDels(to_destroy)
  Movement.move(moves)
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
      if (x+y) % 2 == 0 then
        palette:setColor(8, 1)
      else
        palette:setColor(8, 2)
      end
      love.graphics.rectangle("fill", x*TILE_SIZE, y*TILE_SIZE, TILE_SIZE, TILE_SIZE)
    end
  end

  for i=1,7 do
    for _,tile in ipairs(self.tiles_by_layer[i]) do
      tile:draw(palette)

      love.graphics.push()
      love.graphics.translate(tile.x*TILE_SIZE + TILE_SIZE/2, tile.y*TILE_SIZE + TILE_SIZE/2)
      love.graphics.scale(0.5, 0.5)

      if tile.persist then -- draw greennesss
        palette:setColor(6, 3)
        love.graphics.setShader(OUTLINE_SHADER)
        OUTLINE_SHADER:send("pixelsize", {1/TILE_CANVAS:getWidth(), 1/TILE_CANVAS:getHeight()})
        OUTLINE_SHADER:send("size", 3)
        love.graphics.draw(TILE_CANVAS, -TILE_CANVAS:getWidth()/2, -TILE_CANVAS:getHeight()/2)
        love.graphics.setShader()
      end
      if tile.icy then
        love.graphics.setColor(0, 1, 1)
      else
        love.graphics.setColor(1, 1, 1)
      end
      love.graphics.draw(TILE_CANVAS, -TILE_CANVAS:getWidth()/2, -TILE_CANVAS:getHeight()/2)

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
    local room = World:getRoom(self.paradox_key)
    self.paradox_room = room
    room.exit = self.exit
    Undo:add("create_paradox", room.id, self.id)
    room.rules.inherited_rules = self.rules.inherited_rules
    local x, y = getCoordsTo(room)
    return x, y, room
  else
    if self.paradox then
      local room = World:getVoid()
      room.exit = self.exit
      room.rules.inherited_rules = self.rules.inherited_rules
      local x, y = getCoordsTo(room)
      return x, y, room
    elseif self.void then
      if tile:hasRule("play") then
        local room = World:getHeaven()
        room.exit = self.exit
        room.rules.inherited_rules = self.rules.inherited_rules
        return 2, 2, room
      else
        local room = World:getVoid()
        room.exit = self.exit
        room.rules.inherited_rules = self.rules.inherited_rules
        local x, y = getCoordsTo(room)
        return x, y, room
      end
    else
      local room = World:getParadox(self)
      self.paradox_room = room
      self.paradox_key = room.key
      room.exit = self.exit
      Undo:add("create_paradox", room.id, self.id)
      room.rules.inherited_rules = self.rules.inherited_rules
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
    World:changeRoom(self:getParent())
    World.room:win()
  else
    World.room_won[self.key] = true
    if self.exit then
      local dx, dy = Dir.toPos(self.exit_dir)
      local exiter
      if self.exit_as then
        exiter = Tile.load(self.exit_as)
        exiter.dir = self.exit_dir
      else
        exiter = Tile(World.player, self.exit.x+dx, self.exit.y+dy, {dir = self.exit_dir})
      end
      self:getParent():addTile(exiter)
      World:changeRoom(self:getParent())
      self.exit.room = World:getRoom(self.exit.room_key)
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

  local already_added = {}
  for _,tiledata in ipairs(data.tiles) do
    if World.static or not tiledata.persist or not World.persists[tiledata.key] then
      already_added[tiledata.key] = true
      room:addTile(Tile.load(tiledata))
    end
  end

  for _,persisted in ipairs(World.persists_in_room[room.key] or {}) do
    if not already_added[persisted] then
      room:addTile(Tile.load(World.persists[persisted]), true)
    end
  end

  return room
end

return Room