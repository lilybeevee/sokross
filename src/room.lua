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

function Room:enter()
  Level:changeRoom(self)
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
      if (x+y) % 2 == 0 then
        palette:setColor(0, 3)
      else
        palette:setColor(0, 4)
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

function Room:win()
  local has_exit = false
  for _,exitrule in ipairs(self:getRules(nil, "exit")) do
    if #self:getTilesByName(exitrule.target) > 0 then
      has_exit = true
      break
    end
  end
  if has_exit then
    Level:changeRoom(self:getParent())
    Level.room:win()
  else
    self.won = true
    --temporary, just return to editor
    Gamestate.switch(Editor)
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
  data.entry = self.entry
  data.tiles = tiles
  
  return data
end

function Room.load(data)
  local room = Room(data.width, data.height, {
    key = data.key,
    palette = data.palette,
    entry = data.entry,
  })

  for _,tiledata in ipairs(data.tiles) do
    room:addTile(Tile.load(tiledata))
  end

  return room
end

return Room