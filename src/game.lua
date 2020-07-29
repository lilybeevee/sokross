local Game = {}

function Game:enter()
  print("Sokoma game")

  Undo:clear()

  self.turn = 0
  self.sound = {}
  self.parse_room = {}

  Level.static = false
  Level:reset()
  --[[Level:new("test")

  local room1 = Room(9, 9, {key = "room1"})
  Level:addRoom(room1)

  room1:addTile(Tile("box", 3, 2))
  room1:addTile(Tile("box", 5, 2))
  room1:addTile(Tile("box", 6, 2))
  room1:addTile(Tile("box", 5, 4))

  room1:addTile(Tile("rule", 1, 6, {word = "box"}))
  room1:addTile(Tile("rule", 3, 7, {word = "push"}))
  room1:addTile(Tile("rule", 1, 3, {word = "not"}))
  room1:addTile(Tile("rule", 2, 1, {word = "exit"}))
  room1:addTile(Tile("rule", 1, 1, {word = "wall"}))

  room1:addTile(Tile("room", 7, 7, {room_key = "room2"}))

  local room2 = Room(6, 5, {key = "room2"})
  Level:addRoom(room2)

  room2:addTile(Tile("ladder", 1, 1))
  room2:addTile(Tile("room", 4, 3, {room_key = "room1"}))


  Level:changeRoom(Level:getRoom("room1"))
  Level.room:addTile(Tile("flof", 3, 4))

  --[[Level.room = Room(9, 9)

  Level.room:addTile(Tile("box", 3, 2))
  Level.room:addTile(Tile("box", 5, 2))
  Level.room:addTile(Tile("box", 6, 2))
  Level.room:addTile(Tile("box", 5, 4))

  Level.room:addTile(Tile("flof", 3, 4))

  Level.room:addTile(Tile("rule", 1, 6, {word = "box"}))
  Level.room:addTile(Tile("rule", 3, 7, {word = "push"}))
  Level.room:addTile(Tile("rule", 1, 3, {word = "not"}))
  Level.room:addTile(Tile("rule", 2, 1, {word = "stop"}))
  Level.room:addTile(Tile("rule", 1, 1, {word = "wall"}))

  local inner_room = Room(6, 5, {x=7, y=7, parent=Level.room, layer=2})
  inner_room:addTile(Tile("ladder", 1, 1))

  Level.room:addTile(Tile("room", 7, 7, {room = inner_room}))]]
  
  Level.room:parse()
  Level.room:updateTiles()
  self.sound = {}

  --print(dump(Level.room.rules.rules))
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
  elseif key == "z" then
    Undo:back()
    self:reparse()
  elseif key == "r" then
    Level:reset()
  elseif key == "f2" then
    Gamestate.switch(Editor)
  end
end

function Game:doTurn(dir)
  Undo:new()
  self.turn = self.turn + 1
  Movement.move(dir)
  self:reparse()
  Level.room:updateTiles()
  self:playSounds()
end

function Game:playSounds()
  if self.sound["enter"] then
    Assets.playSound("enter")
  elseif self.sound["exit"] then
    Assets.playSound("exit")
  elseif self.sound["push"] then
    if self.sound["click"] or self.sound["unclick"] then
      Assets.playSound("push", 0.75)
    else
      Assets.playSound("push")
    end
  end
  if self.sound["click"] then
    Assets.playSound("click", 0.75)
  elseif self.sound["unclick"] then
    Assets.playSound("unclick", 0.75)
  end
  self.sound = {}
end

function Game:reparse()
  local parse_list = {}
  for room,_ in pairs(self.parse_room) do
    table.insert(parse_list, room)
  end
  table.sort(parse_list, function(a, b)
    return a:getLayer() < b:getLayer()
  end)
  for _,room in ipairs(parse_list) do
    room:parse()
    for _,lower in ipairs(room.tiles_by_name["room"] or {}) do
      if lower.room and not parse_list[lower.room] then
        lower.room:parse()
      end
    end
  end
  self.parse_room = {}
end

function Game:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-Level.room.width*TILE_SIZE/2, -Level.room.height*TILE_SIZE/2)
  return transform
end

function Game:draw()
  Assets.palettes[Level.room.palette]:setColor(0, 1)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  Level.room:draw()
end

return Game