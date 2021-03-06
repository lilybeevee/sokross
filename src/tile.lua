local Tile = Class{}

function Tile:init(name, x, y, o)
  o = o or {}

  if o.id then
    self.id = o.id
    World.tiles_by_id[self.id] = self
  elseif not World.static then
    self.id = World.tile_id
    World.tile_id = World.tile_id + 1
    World.tiles_by_id[self.id] = self
  else
    self.id = 0
  end

  self.key = o.key
  self.parent = o.parent
  self.name = name
  self.x = x
  self.y = y
  self.tile = Assets.tiles[name]
  self.layer = self.tile.layer

  self.dir = o.dir or 1
  self.room_key = o.room_key
  self.room = o.room
  self.activator = o.activator
  self.locked = o.locked or false
  self.persist = o.persist or false
  self.icy = o.icy or false
  self.savepoint = o.savepoint or nil
  self.saved_tiles = {}
  
  if o.word then
    self.wordname = o.word
    self.word = Assets.words[o.word]

    self.side_type = "none"
    if self.word.type == "noun" then
      self.side_type = "in"
      self.layer = 7
    elseif self.word.type == "prop" then
      self.side_type = "out"
      self.layer = 6
    elseif self.word.type == "mod" then
      self.side_type = "all"
      self.layer = 5
    end

    o.sides = o.sides or {true, true, true, true}

    self.sides = {}
    for i = 1, 4 do
      self.sides[i] = o.sides[i] and self.side_type or "none"
    end
  end

  self.first_update = true
  self.walk_frame = false
  
  self.active = false -- for valid rules
  self.active_sides = {false, false, false, false} -- for side connections
  self.activated = false -- for tiles and rooms
  self.is_tele = false

  if not self.room and o.room_data then
    self.room = Room.load(o.room_data)
    self.room.exit = self
    Undo:add("create_room", self.room.id, self.id)
  end
end

function Tile:updateVisuals()
  if self.room_key and not self.room then
    self.room = World:getRoom(self.room_key)
    Undo:add("create_room", self.room.id, self.id)
    self.room.exit = self
    if not World.static then
      self.room:parse()
    end
  end

  if self.word then
    local prev_active = Utils.copy(self.active_sides)

    self.active_sides = {false, false, false, false}
    for _,conn in ipairs(self:getConnections("out")) do
      self.active_sides[conn[2]] = true
    end

    if not self.first_update then
      for i = 1, 4 do
        if self.active_sides[i] and not prev_active[i] then
          Game.sound["click"] = true
        elseif prev_active[i] and not self.active_sides[i] then
          Game.sound["unclick"] = true
        end
      end
    end
  elseif self.name == "line" then
    self.active_sides = {false, false, false, false}
    for _,conn in ipairs(self:getConnections("line")) do
      self.active_sides[conn[2]] = true
    end
  end

  if self.name == "tile" then
    local prev_active = self.activated
    self.activated = self:getActivated()

    if not self.first_update then
      if self.activated and not prev_active then
        Game.sound["click"] = true
      elseif not self.activated and prev_active then
        Game.sound["unclick"] = true
      end
    end
  end

  self.is_tele = self:hasRule("tele")

  self.first_update = false
end

function Tile:update(small)
  if not self.parent then return {}, {} end

  local to_destroy = {}
  local movers = {}
  local has_belt = false
  local has_tele = false
  for _,other in ipairs(self.parent:getTilesAt(self.x, self.y)) do
    --[[ Large Update ]]
    if not small then
      if other ~= self then
        -- not self
        if other:hasRule("move") then
          has_belt = true
          if not self.belt_start then
            self.belt_moved = false
            self.belt_start = {other.x, other.y}
            table.insert(movers, {tile = self, dir = other.dir})
          else
            if other.x == self.belt_start[1] and other.y == self.belt_start[2] and self.belt_moved then
              self:goToParadox()
              self.belt_start = nil
            else
              self.belt_moved = true
              table.insert(movers, {tile = self, dir = other.dir})
            end
          end
        elseif other:hasRule("sink") then
          Game.sound["sink"] = true
          table.insert(to_destroy, self)
          table.insert(to_destroy, other)
        elseif other:hasRule("burn") then
          Game.sound["burn"] = true
          table.insert(to_destroy, self)
        elseif other:hasRule("save") then
          Undo:add("savepoint", self.id, self.savepoint)
          self.savepoint = other.id
          table.insert(other.saved_tiles, self.id)
        end
      end
      -- can be self
      if (other:hasRule("shut") and self:hasRule("open")) or (other:hasRule("open") and self:hasRule("shut")) then
        Game.sound["unlock"] = true
        table.insert(to_destroy, self)
        table.insert(to_destroy, other)
      elseif other:hasRule("hurt") then
        if self:hasRule("play") then
          table.insert(to_destroy, self)
        end
      end
    end
    --[[ Small Update ]]
    if other ~= self then
      -- not self
      if other:hasRule("tele") then
        has_tele = other.id
      end
    end
  end
  if not has_belt then
    self.belt_start = nil
  end
  if has_tele then
    local ignored = false
    if self.persist then
      local compare = {}
      for _,tile in ipairs(World.tiles_by_key[self.key]) do
        compare[tile.id] = true
      end
      for id,_ in pairs(World.teles) do
        if compare[id] then
          ignored = true
          break
        end
      end
    end
    if not ignored then
      World.teles[self.id] = true
      World.teles_by[has_tele] = World.teles_by[has_tele] or {}
      table.insert(World.teles_by[has_tele], self.id)
    end
  else
    World.teles[self.id] = nil
  end

  return to_destroy, movers
end

function Tile:getHolding(exclude_heavy, x, y, dir, room)
  x = x or self.x
  y = y or self.y
  dir = dir or self.dir
  room = room or self.parent

  local holding = {}
  local dx, dy = Dir.toPos(dir)
  for _,other in ipairs(room:getTilesAt(x+dx, y+dy, true)) do
    if other:hasRule("hold") and other.dir == dir and (not exclude_heavy or not other:hasRule("heavy")) then
      table.insert(holding, other)
    end
  end
  return holding
end

function Tile:remove(ignore_save)
  for _,tileid in ipairs(self.saved_tiles) do
    if World.tiles_by_id[tileid] then
      World.tiles_by_id[tileid].savepoint = nil
    end
  end
  if not World.static then
    if self.savepoint and not ignore_save then
      local save = World.tiles_by_id[self.savepoint]
      --local new_self = Tile(self.name, save.x, save.y, {dir = self.dir, word = self.word and self.word.name or nil, icy = self.icy})
      if save then
        local save_data = self:save(true)
        save_data.id = nil
        local new_self = Tile.load(save_data)
        new_self.x = save.x
        new_self.y = save.y
        save.parent:addTile(new_self)
        Undo:add("add", new_self.id)
      end
    end
    World.tiles_by_id[self.id] = nil
    World.teles[self.id] = nil
    if World.teles_by[self.id] then
      for _,id in ipairs(World.teles_by[self.id]) do
        World.teles[id] = nil
      end
      World.teles_by[self.id] = nil
    end
  end
  Utils.removeFromTable(World.tiles_by_key[self.key], self)
end

function Tile:add()
  if not World.static then
    World.tiles_by_id[self.id] = self

    if World.room and World.room ~= self.parent and self:hasRule("play") then
      local move_needed = true
      for _,rule in ipairs(World.room:getRules(nil, "play")) do
        if #World.room:getTilesByName(rule.target) > 0 then
          move_needed = false
          break
        end
      end
      if move_needed then
        World:changeRoom(self.parent)
      end
    end

    if self.room then
      self.room.exit = self
    end
  end
  World.tiles_by_key[self.key] = World.tiles_by_key[self.key] or {}
  table.insert(World.tiles_by_key[self.key], self)
end

function Tile:hasRule(effect)
  return self.parent:hasRule(self.name, effect)
end

function Tile:moveTo(x, y, room, dir, ignore_persist)
  local undo_move_args = {self.id, self.x, self.y, self.parent.id}

  local last_parent = self.parent

  if x ~= self.x or y ~= self.y or (room and room ~= self.parent) then
    Game.update_room[self.parent] = true
    if room then
      Game.update_room[room] = true
    end
  end

  if room and self.parent ~= room then
    if self:hasRule("play") then
      room:enter(self, dir or self.dir)
    end

    local last_parent_parent = self.parent:getParent()
    if self.persist and not ignore_persist then
      Undo:add("remove", self:save(true), self.parent.id)
      Undo:add("update_persist", self.key, World.persists[self.key])
      self.parent:removeTile(self, ignore_persist, true)
      self.x, self.y = x, y
      World.persists[self.key] = self:save()
      if not (last_parent:getParent() ~= last_parent_parent and last_parent.key == room.key) then -- only fails for a persistent room exiting itself
        local tile = Tile.load(World.persists[self.key])
        Undo:add("add", tile.id)
        room:addTile(tile, ignore_persist)
      else
        Game.sound["paradox push"] = true
      end
    else
      self.parent:removeTile(self, ignore_persist, true)
      self.x, self.y = x, y
      Undo:add("move", unpack(undo_move_args))
      room:addTile(self, ignore_persist)
    end
  else
    Utils.removeFromTable(self.parent.tiles_by_pos[self.x..","..self.y], self)
    self.x, self.y = x, y
    self.parent.tiles_by_pos[self.x..","..self.y] = self.parent.tiles_by_pos[self.x..","..self.y] or {}
    table.insert(self.parent.tiles_by_pos[self.x..","..self.y], self)
    if not ignore_persist then
      self:updatePersistence()
    end
    Undo:add("move", unpack(undo_move_args))
  end
end

function Tile:setPos(x, y, room)
  if room and room ~= self.parent then
    self.parent:removeTile(self, true)
    self.x, self.y = x, y
    room:addTile(self, true)
  else
    Utils.removeFromTable(self.parent.tiles_by_pos[self.x..","..self.y], self)
    self.x, self.y = x, y
    self.parent.tiles_by_pos[self.x..","..self.y] = self.parent.tiles_by_pos[self.x..","..self.y] or {}
    table.insert(self.parent.tiles_by_pos[self.x..","..self.y], self)
  end
end

function Tile:rotate(dir, ignore_persist)
  if self.dir ~= dir then
    Undo:add("rotate", self.id, self.dir)
    self.dir = dir
    if not ignore_persist then
      self:updatePersistence()
    end
  end
end

function Tile:updatePersistence()
  if World.persists[self.key] and not World.static then
    if self.persist then
      Undo:add("update_persist", self.key, World.persists[self.key])
      World.persists[self.key] = self:save()
      for _,tile in ipairs(World.tiles_by_key[self.key] or {}) do
        if tile ~= self then
          tile:rotate(self.dir, true)
          tile:moveTo(self.x, self.y, nil, self.dir, true)
          tile.locked = self.locked
          if tile.word then
            Game.parse_room[tile.parent] = true
          end
        end
      end
    else
      Undo:add("update_persist", self.key, World.persists[self.key])
      World.persists[self.key] = nil
      local to_remove = {}
      for _,tile in ipairs(World.tiles_by_key[self.key] or {}) do
        if tile ~= self then
          table.insert(to_remove, tile)
        end
      end
      for _,tile in ipairs(to_remove) do
        if tile.word then
          Game.parse_room[tile.parent] = true
        end
        Undo:add("remove", tile:save(true), tile.parent.id)
        tile.parent:removeTile(tile, true)
      end
    end
  end
end

function Tile:goToParadox()
  if self:hasRule("play") then
    Game.sound["paradox"] = true
  else
    Game.sound["paradox push"] = true
  end
  self:moveTo(self.parent:getParadoxEntry(self))
end

function Tile:getColor()
  if self.word then
    return self.word.color, self.word.dark and 2 or 3
  else
    return unpack(self.tile.colors[1])
  end
end

function Tile:getConnections(type)
  local inputs = {}
  local word_check = self.word
  local line_check = type == "line"
  if word_check or line_check then
    for dir = 1, 4 do
      local othertype = "all"
      if type == "in" then
        othertype = "out"
      elseif type == "out" then
        othertype = "in"
      end
      if type == "line" or (self.sides[dir] ~= "none" and (type == "all" or self.sides[dir] == "all" or self.sides[dir] == type)) then
        local dx, dy = Dir.toPos(dir)
        local rdir = Dir.reverse(dir)
        for _,tile in ipairs(self.parent:getTilesAt(self.x+dx, self.y+dy)) do
          if (type == "line" and (tile.name == "line" or tile.name == "room")) or (type ~= "line" and tile.word and tile.sides[rdir] ~= "none" and (type == "all" or tile.sides[rdir] == "all" or tile.sides[rdir] == othertype)) then
            table.insert(inputs, {tile, dir})
          end
        end
      end
    end
  end
  return inputs
end

function Tile:getActivated()
  if self.name == "tile" then
    local tiles = self.parent:getTilesAt(self.x, self.y)
    for _,tile in ipairs(tiles) do
      if tile ~= self and (not self.activator or tile.name == self.activator) then
        return true
      end
    end
  elseif self.name == "room" then
    return self.room_key and World:getLevel(self.room_key).won
  end
  return false
end

function Tile:draw(palette, alpha, recursed)
  Utils.pushCanvas(TILE_CANVAS)
  love.graphics.clear()
  love.graphics.origin()
  love.graphics.translate(TILE_SIZE*2, TILE_SIZE*2)
  love.graphics.scale(2, 2)

  if self.tile.rotate then
    love.graphics.rotate(math.rad((self.dir-1) * 90))
  end

  if self.name == "room" then
    local ipalette = Assets.palettes[self.room and self.room.palette or (self.parent and self.parent.palette or "default")]
    ipalette:setColor(8, 0)
    love.graphics.rectangle("fill", -TILE_SIZE/2, -TILE_SIZE/2, TILE_SIZE, TILE_SIZE)

    if self.room and (not self.locked or Gamestate.current() == Editor) then
      love.graphics.push()
      love.graphics.translate(-self.room.width, -self.room.height)
      ipalette:setColor(8, 2)
      love.graphics.rectangle("fill", 0, 0, self.room.width*2, self.room.height*2)
      for x = 0, self.room.width-1 do
        for y = 0, self.room.height-1 do
          local color
          if self.room.tiles_by_pos[x..","..y] and #self.room.tiles_by_pos[x..","..y] > 0 then
            color = {self.room.tiles_by_pos[x..","..y][1]:getColor()}
          end
          if color then
            ipalette:setColor(color[1], color[2])
            love.graphics.rectangle("fill", x*2, y*2, 2, 2)
          end
        end
      end
      love.graphics.pop()

      if self.locked then
        love.graphics.setColor(0, 0, 0, 0.33)
        love.graphics.rectangle("fill", -TILE_SIZE/2, -TILE_SIZE/2, TILE_SIZE, TILE_SIZE)
      end
    else
      palette:setColor(8, 2)
      local sprite
      if not self.locked then
        sprite = Assets.sprites["tiles/room"]
      else
        sprite = Assets.sprites["tiles/room_locked"]
      end
      love.graphics.draw(sprite, -sprite:getWidth()/2, -sprite:getHeight()/2)
    end

    ipalette:setColor(8, 0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -TILE_SIZE/2, -TILE_SIZE/2, TILE_SIZE, TILE_SIZE)
  elseif self.name == "line" then
    palette:setColor(0, 2)
    if self.active_sides[1] or self.active_sides[2] or self.active_sides[3] or self.active_sides[4] then
      local sprite = Assets.sprites["tiles/line_connection"..(self.locked and "_locked" or "")]
      for i = 1, 4 do
        if self.active_sides[i] then
          love.graphics.draw(sprite, -sprite:getWidth()/2, -sprite:getHeight()/2)
        end
        love.graphics.rotate(math.rad(90))
      end
    else
      local sprite = Assets.sprites["tiles/line"..(self.locked and "_locked" or "")]
      love.graphics.draw(sprite, -sprite:getWidth()/2, -sprite:getHeight()/2)
    end
  elseif self.name == "rule" and self.word then
    local rule_base = Assets.sprites["tiles/rule"]
    local word_sprite = Assets.sprites["words/"..self.word.name]
    palette:setColor(self.word.color, self.word.dark and 2 or 3)
    love.graphics.draw(rule_base, -rule_base:getWidth()/2, -rule_base:getHeight()/2)
    --[[if self.active then
      palette:setColor(self.word.color, self.word.dark and 3 or 4)
    else
      palette:setColor(self.word.color, self.word.dark and 0 or 1)
    end]]
    palette:setColor(self.word.color, self.word.dark and 0 or 1)
    love.graphics.draw(word_sprite, -word_sprite:getWidth()/2, -word_sprite:getHeight()/2)

    for i = 1, 4 do
      local rule_side
      if self.sides[i] == "out" or (self.sides[i] == "all" and self.active_sides[i]) then
        palette:setColor(self.word.color, self.word.dark and 2 or 3)
        rule_side = Assets.sprites["tiles/rule_connector"]
      elseif self.sides[i] == "all" then
        palette:setColor(self.word.color, self.word.dark and 1 or 2)
        rule_side = Assets.sprites["tiles/rule_connector"]
      elseif self.sides[i] == "none" then
        palette:setColor(self.word.color, self.word.dark and 2 or 3)
        rule_side = Assets.sprites["tiles/rule_side"]
      end

      if rule_side then
        love.graphics.draw(rule_side, rule_base:getWidth()/2 - rule_side:getWidth()/2, -rule_side:getHeight()/2)
      end
      love.graphics.rotate(math.rad(90))
    end
  else
    local sprites = self.tile.sprites
    local colors = self.tile.colors

    if self.name == "tile" then
      if self.activator then
        sprites = {"tile_"..self.activator}
      end
      if self.activated then
        colors = {{5, 3}}
      end
    end

    for i,spritename in ipairs(sprites) do
      palette:setColor(colors[i][1], colors[i][2])
      local sprite = Assets.sprites["tiles/"..spritename]
      if self.tile.walk and self.walk_frame then
        sprite = Assets.sprites["tiles/"..spritename.."_walk"]
      end
      love.graphics.draw(sprite, -sprite:getWidth()/2, -sprite:getHeight()/2)
    end
  end

  Utils.popCanvas()

  -- actually draw
  love.graphics.push()
  love.graphics.translate(TILE_SIZE/2, TILE_SIZE/2)
  love.graphics.scale(0.5, 0.5)
  alpha = alpha or 1

  if self.persist then -- draw greennesss
    palette:setColor(6, 3)
    love.graphics.setShader(OUTLINE_SHADER)
    OUTLINE_SHADER:send("pixelsize", {1/TILE_CANVAS:getWidth(), 1/TILE_CANVAS:getHeight()})
    OUTLINE_SHADER:send("size", 3)
    love.graphics.draw(TILE_CANVAS, -TILE_CANVAS:getWidth()/2, -TILE_CANVAS:getHeight()/2)
    love.graphics.setShader()
  end
  if self.icy then
    love.graphics.setColor(0, 1, 1, alpha)
  else
    love.graphics.setColor(1, 1, 1, alpha)
  end

  love.graphics.draw(TILE_CANVAS, -TILE_CANVAS:getWidth()/2, -TILE_CANVAS:getHeight()/2)
  love.graphics.pop()

  if self.is_tele and not recursed then
    Utils.pushCanvas(HOLO_CANVAS)
    love.graphics.clear()
    love.graphics.origin()
    love.graphics.translate(HOLO_CANVAS:getWidth()/2 - TILE_SIZE/2, HOLO_CANVAS:getHeight()/2 - TILE_SIZE/2)

    for id,_ in pairs(World.teles) do
      if World.tiles_by_id[id] then
        World.tiles_by_id[id]:draw(palette, 1, true)
      end
    end

    Utils.popCanvas()

    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    love.graphics.draw(HOLO_CANVAS, TILE_SIZE/2 - HOLO_CANVAS:getWidth()/2, TILE_SIZE/2 - HOLO_CANVAS:getHeight()/2)
  end
end

function Tile:getHasSides()
  if self.sides then
    local has_sides = {}
    for i = 1, 4 do
      has_sides[i] = self.sides[i] ~= "none"
    end
    return has_sides
  end
end

function Tile:copy()
  local tile = Tile(self.name, self.x, self.y, {
    dir = self.dir,
    word = self.word and self.word.name or nil,
    sides = self:getHasSides(),
    room_key = self.room_key,
    activator = self.activator,
    locked = self.locked,
    persist = self.persist,
    icy = self.icy,
    savepoint = self.savepoint,
  })
  if tile.room_key then
    tile.room = World:getRoom(tile.room_key)
  end
  return tile
end

function Tile:save(instance, clone)
  local data = {}

  data.name = self.name
  data.key = self.key
  data.x = self.x
  data.y = self.y
  if self.dir ~= 1 then
    data.dir = self.dir
  end
  if self.word then
    data.word = self.word.name
    data.sides = self:getHasSides()
  end
  if self.room_key then
    data.room = self.room_key
  end
  data.activator = self.activator
  data.locked = self.locked
  data.persist = self.persist
  data.icy = self.icy
  data.savepoint = self.savepoint

  if instance then
    data.id = self.id
    if self.room then
      data.room_id = self.room.id
    end
  elseif clone then
    if self.room then
      data.room_data = self.room:save(true)
    end
  end

  return data
end

function Tile.load(data)
  local room
  if data.room_id then
    room = World.rooms_by_id[data.room_id]
  end
  return Tile(data.name, data.x, data.y, {
    id = data.id,
    key = data.key,
    dir = data.dir,
    word = data.word,
    sides = data.sides,
    room = room,
    room_key = data.room,
    room_data = data.room_data,
    activator = data.activator,
    locked = data.locked,
    persist = data.persist,
    icy = data.icy,
    savepoint = data.savepoint,
  })
end

return Tile