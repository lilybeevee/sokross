local Tile = Class{}

function Tile:init(name, x, y, o)
  o = o or {}

  if o.id then
    self.id = o.id
  elseif not Level.static then
    self.id = Level.tile_id
    Level.tile_id = Level.tile_id + 1
    Level.tiles_by_id[self.id] = self
  else
    self.id = 0
  end

  if o.key then
    self.key = o.key
  else
    self.key = Level.tile_key + 1
    Level.tile_key = Level.tile_key + 1
  end
  Level.tiles_by_key[self.key] = Level.tiles_by_key[self.key] or {}
  table.insert(Level.tiles_by_key[self.key], self)

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
  
  if o.word then
    self.wordname = o.word
    self.word = Assets.words[o.word]

    local side_type = "none"
    if self.word.type == "noun" then
      side_type = "in"
      self.layer = 7
    elseif self.word.type == "prop" then
      side_type = "out"
      self.layer = 6
    elseif self.word.type == "mod" then
      side_type = "all"
      self.layer = 5
    end

    o.sides = o.sides or {true, true, true, true}

    self.sides = {}
    for i = 1, 4 do
      self.sides[i] = o.sides[i] and side_type or "none"
    end
  end

  self.first_update = true
  self.walk_frame = false
  
  self.active = false -- for valid rules
  self.active_sides = {false, false, false, false} -- for side connections
  self.activated = false -- for tiles and rooms
end

function Tile:update()
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
  self.first_update = false
end

function Tile:remove()
  if not Level.static then
    Level.tiles_by_id[self.id] = nil
  end
  Utils.removeFromTable(Level.tiles_by_key[self.key], self)
end

function Tile:hasRule(effect)
  return self.parent:hasRule(self.name, effect)
end

function Tile:moveTo(x, y, room, dir)
  if not dir then
    dir = Dir.fromPos(x-self.x, y-self.y) or self.dir
  end
  self.dir = dir

  if room and self.parent ~= room then
    if self:hasRule("play") then
      room:enter(self, dir)
    end

    self.parent:removeTile(self)
    self.x, self.y = x, y
    room:addTile(self)
  else
    Utils.removeFromTable(self.parent.tiles_by_pos[self.x..","..self.y], self)
    self.x, self.y = x, y
    self.parent.tiles_by_pos[self.x..","..self.y] = self.parent.tiles_by_pos[self.x..","..self.y] or {}
    table.insert(self.parent.tiles_by_pos[self.x..","..self.y], self)
  end
  if room then
    Game.update_room[room] = true
  end
end

function Tile:goToParadox()
  Undo:add("move", self.id, self.x, self.y, self.dir, self.parent.id)
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
    return self.room_key and Level.room_won[self.room_key]
  end
  return false
end

function Tile:draw(palette)
  love.graphics.push()
  love.graphics.translate(TILE_SIZE/2, TILE_SIZE/2)

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

    palette:setColor(8, 0)
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

  love.graphics.pop()
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
  })
  if tile.room_key then
    tile.room = Level:getRoom(tile.room_key)
  end
  return tile
end

function Tile:save()
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

  return data
end

function Tile.load(data)
  return Tile(data.name, data.x, data.y, {
    key = data.key,
    dir = data.dir,
    word = data.word,
    sides = data.sides,
    room_key = data.room,
    activator = data.activator,
    locked = data.locked,
  })
end

return Tile