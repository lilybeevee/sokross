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
  for i=1,8 do
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
    tile:remove(true)
  end
  if self.exit then
    self.exit.room = nil
  end
end

function Room:getLevel()
  return World:getLevel(self.key)
end

function Room:getParent()
  return self.exit and self.exit.parent
end

function Room:getLayer(recursed)
  recursed = recursed or {}
  recursed[self] = true
  if not self:getParent() or recursed[self:getParent()] then
    return 1
  else
    return self:getParent():getLayer(Utils.copy(recursed)) + 1
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
    if not World.level_exits[self:getLevel()] then
      World.level_exits[self:getLevel()] = {
        player = tile.id,
        exit = self.exit and self.exit.id or nil,
        parent = (self.exit and self.exit.parent) and self.exit.parent.id or nil,
        dir = Dir.reverse(dir) or 1,
        pos = {tile.x, tile.y},
        layer = self:getLayer()
      }
    end
  end
  for level,info in pairs(World.level_exits) do
    if info.layer > self:getLayer() then
      World.level_exits[level] = nil
    end
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

  if not tile.key then
    tile.key = self:getLevel():newTileKey()
  end

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
            Game.update_room[room] = true
          end
        end
      end
    end
  end

  tile:add()
  return tile
end

function Room:removeTile(tile, ignore_persist, ignore_save)
  Utils.removeFromTable(self.tiles, tile)
  Utils.removeFromTable(self.tiles_by_pos[tile.x..","..tile.y], tile)
  Utils.removeFromTable(self.tiles_by_name[tile.name], tile)
  Utils.removeFromTable(self.tiles_by_layer[tile.layer], tile)
  if tile.word and not World.static then
    Game.parse_room[self] = true
  end
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
        Undo:add("remove", linked:save(true), linked.parent.id)
        linked.parent:removeTile(linked, true, true)
      end
    end
  end
  tile:remove(ignore_save)
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

function Room:updateTiles(small)
  local to_destroy = {}
  local moves = {}
  for _,tile in ipairs(self.tiles) do
    local new_to_destroy, new_moves = tile:update(small)
    for _,new in ipairs(new_to_destroy) do
      table.insert(to_destroy, new)
    end
    for _,new in ipairs(new_moves) do
      table.insert(moves, new)
    end
  end
  Game:handleDels(to_destroy)
  Movement.move(moves)
end

function Room:getTilesAt(x, y, use_tele)
  local tiles = {}
  if self.tiles_by_pos[x..","..y] then
    Utils.merge(tiles, self.tiles_by_pos[x..","..y])
    local insert_tele = false
    if use_tele then
      for _,tile in ipairs(self.tiles_by_pos[x..","..y]) do
        if tile:hasRule("tele") then
          insert_tele = true
          break
        end
      end
    end
    if insert_tele then
      for id,_ in pairs(World.teles) do
        if not Utils.contains(tiles, World.tiles_by_id[id]) then
          table.insert(tiles, World.tiles_by_id[id])
        end
      end
    end
  end
  return tiles
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

  for i=1,8 do
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

function Room:checkWin(recursed)
  recursed = recursed or {}
  recursed[self] = true
  local tiles = self:getTilesByName("tile")
  local has_anything = false
  local won = true
  if #tiles > 0 then
    has_anything = true
    local any_won, any_unwon = false, false
    for _,tile in ipairs(tiles) do
      if tile:getActivated() then
        any_won = true
      else
        any_unwon = true
        break
      end
    end
    won = any_won and not any_unwon
  end
  local rooms = self:getTilesByName("room")
  if won and #rooms > 0 then
    for _,tile in ipairs(rooms) do
      if tile.room_key and World:getLevel(tile.room_key) == self:getLevel() then
        if tile.room then
          if not recursed[tile.room] then
            local new_won, new_any = tile.room:checkWin(Utils.copy(recursed))
            won = won and new_won
            has_anything = has_anything or new_any
          end
        elseif World.room_winnable[tile.room_key] then
          won = false
          has_anything = true
        end
        if not won then
          return false, has_anything
        end
      end
    end
  end
  return won, has_anything
end

function Room:isWinnable(recursed)
  if World.room_winnable[self.key] ~= nil then
    return World.room_winnable[self.key]
  end
  recursed = recursed or {}
  recursed[self.key] = true
  if #self:getTilesByName("tile") > 0 then
    World.room_winnable[self.key] = true
    return true
  end
  for _,tile in ipairs(self:getTilesByName("room")) do
    if tile.room_key and not recursed[tile.room_key] and World:getLevel(tile.room_key) == self:getLevel() then
      local room = World:getRoom(tile.room_key)
      if room:isWinnable(Utils.copy(recursed)) then
        World.room_winnable[self.key] = true
        return true
      end
    end
  end
  World.room_winnable[self.key] = false
  return false
end

function Room:win()
  self:getLevel().won = true
  local info = World.level_exits[self:getLevel()]
  World.level_exits[self:getLevel()] = nil
  if info and info.parent and World.rooms_by_id[info.parent] then
    local parent = World.rooms_by_id[info.parent]
    local exit = info.exit and World.tiles_by_id[info.exit] or nil
    local exiter = World.tiles_by_id[info.player]
    if exiter then
      exiter.parent:removeTile(exiter)
    else
      exiter = Tile(parent:getLevel().player, info.pos[1], info.pos[2])
    end
    exiter.dir = info.dir
    if exit and exit.parent and exit.parent.id == info.parent then
      local dx, dy = Dir.toPos(info.dir)
      exiter.x = exit.x + dx
      exiter.y = exit.y + dy
      --exit.room:remove()
      --exit.room = World:getRoom(exit.room_key)
      --exit.room.exit = exit
    end
    self:getLevel():reset()
    parent:addTile(exiter)
    World:changeRoom(parent)
  else
    Gamestate.switch(Editor)
  end
  --[[local has_exit = false
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
    World.level.won = true
    if self:getParent() then
      local dx, dy = Dir.toPos(self.exit_dir)
      local exiter
      if self.exit_as then
        exiter = Tile.load(self.exit_as)
        exiter.dir = self.exit_dir
      else
        exiter = Tile(self:getParent():getLevel().player, self.exit.x+dx, self.exit.y+dy, {dir = self.exit_dir})
      end
      self:getParent():addTile(exiter)
      World:changeRoom(self:getParent())
      self.exit.room = World:getRoom(self.exit.room_key)
      self.exit.room.exit = self.exit
    else -- ideally this can't happen unless you're just playtesting from editor
      Gamestate.switch(Editor)
    end
  end]]
end

function Room:save(clone)
  local tiles = {}
  for _,tile in ipairs(self.tiles) do
    table.insert(tiles, tile:save(false, clone))
  end

  local data = {}
  data.width = self.width
  data.height = self.height
  data.key = self.key
  if self.palette ~= "default" then
    data.palette = self.palette
  end
  data.winnable = self:isWinnable()
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