local Level = {}

Level.static = false

function Level:new(name)
  self.name = name
  self.player = "flof"
  self.rooms = {}
  self.has_room = {}
  self.start = {}

  self.tile_key = 1
  self.room_key = 1

  self.tile_id = 1
  self.room_id = 1
  self.tiles_by_id = {}
  self.tiles_by_key = {}
  self.rooms_by_id = {}

  self:generateDefaults()

  self:traverse(self.start)
  self:spawnPlayer()
end

function Level:reset()
  if not self.static then
    local static_root = self.rooms[self.root_key]
    self.rooms = {}
    self.rooms[self.root_key] = static_root
    self.tiles_by_key = {}
  end

  self.tile_id = 1
  self.room_id = 1
  self.tiles_by_id = {}
  self.rooms_by_id = {}

  self:traverse(self.start)
  self:spawnPlayer()
end

function Level:spawnPlayer()
  if not Level.static then
    self.room:addTile(Tile(self.player, self.room:getEntry()))
  end
end

function Level:traverse(rooms)
  self:changeRoom(self.root_key, #rooms > 0)
  for i,key in ipairs(rooms) do
    for _,tile in ipairs(self.room.tiles_by_name["room"] or {}) do
      if tile.key == key then
        local room = self:getRoom(tile.room_key)
        room.exit = tile
        self:changeRoom(room, i ~= #rooms)
        break
      end
    end
  end
end

function Level:changeRoom(room, small)
  if type(room) == "string" then
    room = self:getRoom(room)
  end
  self.room = room
  if Gamestate.current() == Game then
    self.room:parse()
  end
  if not small then
    for _,tile in ipairs(room.tiles_by_name["room"] or {}) do
      if tile.room_key and not tile.room then
        tile.room = self:getRoom(tile.room_key)
        tile.room.exit = tile
      end
    end
  end
end

function Level:getRoom(key)
  if self.has_room[key] then
    if self.rooms[key] then
      if not self.static then
        return Room.load(self.rooms[key]:save())
      else
        return self.rooms[key]
      end
    else
      local loadstr = love.filesystem.read("levels/"..self.name.."/"..key..".room")
      local room = Room.load(Utils.loadTable(loadstr))
      if self.static then
        self.rooms[room.key] = room
      end
      return room
    end
  end
end

function Level:addRoom(room)
  if not room.key then
    room.key = self:newKey()
  end
  self.rooms[room.key] = room
  self.has_room[room.key] = true
  return room.key
end

function Level:newKey()
  local key = string.format("room%04d", self.room_key)
  self.room_key = self.room_key + 1
  return key
end

function Level:save()
  if not self.root then return end

  love.filesystem.createDirectory("levels/"..self.name)
  local dir = "levels/"..self.name.."/"
  
  for key,room in pairs(self.rooms) do
    local savestr = Utils.saveTable(room:save())
    love.filesystem.write(dir..key..".room", savestr)
  end

  local info = {
    name = self.name,
    player = self.player,
    start = self.start,
    root = self.root.key,
    tile_key = self.tile_key,
    room_key = self.room_key
  }
  love.filesystem.write(dir.."level.json", JSON.encode(info))
end

function Level:load(name)
  if love.filesystem.getInfo("levels/"..name) then
    local dir = "levels/"..name.."/"

    local info = JSON.decode(love.filesystem.read(dir.."level.json"))
    self.name = info.name or name
    self.player = info.player or "flof"
    self.start = info.start or {}
    self.room_key = info.room_key or 1
    self.tile_key = info.tile_key or 1

    self.rooms = {}
    self.has_room = {}

    self.tile_id = 1
    self.room_id = 1
    self.tiles_by_key = {}
    self.tiles_by_id = {}
    self.rooms_by_id = {}

    for _,file in ipairs(love.filesystem.getDirectoryItems(dir)) do
      if file:sub(-5) == ".room" then
        self.has_room[file:sub(1, -6)] = true
      end
    end

    self.root = self:getRoom(info.root)
    self.root_key = info.root

    self:traverse(self.start)
    self:spawnPlayer()
  end
end

function Level:generateDefaults()
  local room1 = Room(12, 12, {entry = {0, 11}})
  self:addRoom(room1)

  local x, y = 0, 0
  for _,rule in ipairs(DEFAULT_RULES) do
    if x+#rule-1 >= room1.width then
      x = 0
      y = y + 1
    end
    for i,word in ipairs(rule) do
      local sides = {true, false, true, false} -- center (mod)
      if i == 1 then
        sides = {true, false, false, false} -- left (noun)
      elseif i == #rule then
        sides = {false, false, true, false} -- right (prop)
      end
      room1:addTile(Tile("rule", x, y, {word = word, sides = sides}))
      x = x + 1
    end
  end
  
  self.paradox_room = Room(7, 7, {paradox = true, palette = "paradox"})
  self:addRoom(self.paradox_room)
  self.paradox_room_key = self.paradox_room.key

  local room2 = Room(7, 7)
  self:addRoom(room2)

  local room2_portal = Tile("room", 11, 11, {room_key = room2.key})
  room1:addTile(room2_portal)

  self.start = {room2_portal.key}
  self.root = room1
  self.root_key = room1.key
end

return Level