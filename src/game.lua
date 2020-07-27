local Game = {}

function Game:enter()
  print("Sokoma game")

  self.room = Room(7, 7)

  self.room:addTile(Tile("rule", 2, 2, {word = "flof"}))
  --self.room:addTile(Tile("rule", 3, 2, {word = "play"}))
  self.room:addTile(Tile("rule", 1, 2, {word = "not"}))
  self.room:addTile(Tile("rule", 1, 1, {word = "not"}))
  self.room:addTile(Tile("rule", 1, 3, {word = "stop"}))
  self.room:addTile(Tile("rule", 2, 1, {word = "stop"}))
  self.room:addTile(Tile("rule", 1, 4, {word = "wall"}))

  self.room:addTile(Tile("rule", 4, 4, {word = "flof", sides={true, true, false, false}}))
  self.room:addTile(Tile("rule", 5, 4, {word = "play"}))
  self.room:addTile(Tile("rule", 6, 4, {word = "plus"}))
  self.room:addTile(Tile("rule", 4, 5, {word = "plus"}))
  self.room:addTile(Tile("rule", 5, 5, {word = "plus"}))
  self.room:addTile(Tile("rule", 6, 5, {word = "plus"}))
  self.room:addTile(Tile("rule", 4, 6, {word = "plus"}))
  self.room:addTile(Tile("rule", 5, 6, {word = "plus"}))
  self.room:addTile(Tile("rule", 6, 6, {word = "plus"}))

  self.room:addTile(Tile("flof", 2, 5, {dir = 2}))


  self.room.rules:parse()

  for _,tile in ipairs(self.room.tiles) do
    tile:update()
  end

  print(dump(self.room.rules.rules))
end

function Game:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-self.room.width*TILE_SIZE/2, -self.room.height*TILE_SIZE/2)
  return transform
end

function Game:draw()
  Assets.palettes[self.room.palette]:setColor(0, 1)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  self.room:draw()
end

return Game