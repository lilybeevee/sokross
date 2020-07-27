local Room = Class{}

function Room:init(width, height, parent)
  self.palette = "default"
  self.width = width
  self.height = height
  self.parent = parent

  self.tiles = {}
  self.tiles_by_pos = {}
  self.tiles_by_name = {}
  self.tiles_by_layer = {}
  for i=1,7 do
    self.tiles_by_layer[i] = {}
  end

  self.rules = Rules(self)
end

function Room:addTile(tile)
  table.insert(self.tiles, tile)

  tile.room = self

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

function Room:inBounds(x, y)
  return x >= 0 and x < self.width and y >= 0 and y < self.height
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