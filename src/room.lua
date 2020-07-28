local Room = Class{}

function Room:init(width, height, o)
  o = o or {}

  if o.id then
    self.id = o.id
  elseif Gamestate.current() == Game then
    self.id = Game.room_id
    Game.room_id = Game.room_id + 1
    Game.rooms_by_id[self.id] = self
  else
    self.id = 0
  end

  self.width = width
  self.height = height

  self.palette = o.palette or "default"
  self.x = o.x or 0
  self.y = o.y or 0
  self.parent = o.parent
  self.layer = o.layer or 1

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

end

function Room:parse()
  self.rules:parse()
  self.last_parsed = Game.turn
end

function Room:enter()
  Game.room = self
  if self.parent and self.parent.last_parsed > self.last_parsed then
    self.rules:parse()
  end
end

function Room:getEntry()
  return math.ceil(self.width/2)-1, math.ceil(self.height/2)-1
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

return Room