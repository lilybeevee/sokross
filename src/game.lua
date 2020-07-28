local Game = {}

function Game:enter()
  print("Sokoma game")

  self.turn = 0
  self.room = Room(0, 0, 9, 9)

  self.room:addTile(Tile("box", 3, 2))
  self.room:addTile(Tile("box", 5, 2))
  self.room:addTile(Tile("box", 5, 4))

  self.room:addTile(Tile("flof", 3, 4))

  self.room:addTile(Tile("rule", 1, 6, {word = "box"}))
  self.room:addTile(Tile("rule", 3, 7, {word = "push"}))
  self.room:addTile(Tile("rule", 1, 3, {word = "not"}))

  local inner_room = Room(7, 7, 6, 5, self.room, 2)
  inner_room:addTile(Tile("ladder", 1, 1))

  self.room:addTile(Tile("room", 7, 7, {room = inner_room}))

  self.parse_room = {}
  self.room:parse()

  --print(dump(self.room.rules.rules))
end

function Game:keypressed(key)
  if key == "d" then
    self:doTurn(1)
  elseif key == "s" then
    self:doTurn(2)
  elseif key == "a" then
    self:doTurn(3)
  elseif key == "w" then
    self:doTurn(4)
  end
end

function Game:doTurn(dir)
  self.turn = self.turn + 1
  Movement.move(dir)
  self:reparse()
end

function Game:reparse()
  local parse_list = {}
  for room,_ in pairs(self.parse_room) do
    table.insert(parse_list, room)
  end
  table.sort(parse_list, function(a, b)
    return a.layer < b.layer
  end)
  for _,room in ipairs(parse_list) do
    room:parse()
  end
  self.parse_room = {}
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