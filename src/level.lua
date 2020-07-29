local Level = {}

Level.static = false

function Level:new(name)
  self.name = name
  self.next_key = 1
  self.rooms = {}
  self.has_room = {}

  self.tile_id = 1
  self.room_id = 1
  self.tiles_by_id = {}
  self.rooms_by_id = {}

  self.root = Room(7, 7)
  self.root_key = self:addRoom(self.root)

  self:changeRoom(self:getRoom(self.root_key))
end

function Level:reset()
  if not self.static then
    local static_root = self.rooms[self.root_key]
    self.rooms = {}
    self.rooms[self.root_key] = static_root
  end

  self.tile_id = 1
  self.room_id = 1
  self.tiles_by_id = {}
  self.rooms_by_id = {}

  self:changeRoom(self:getRoom(self.root_key))
end

function Level:changeRoom(room)
  self.room = room
  for _,tile in ipairs(room.tiles_by_name["room"] or {}) do
    if tile.room_key and not tile.room then
      tile.room = self:getRoom(tile.room_key)
      tile.room.exit = tile
    end
  end
end

function Level:getRoom(key)
  print("Getting room: "..key)
  if self.has_room[key] then
    if self.rooms[key] then
      if not self.static then
        return Room.load(self.rooms[key]:save())
      else
        return self.rooms[key]
      end
    else
      print("Loading room: "..key)
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
    print("Generating key: "..room.key)
  end
  self.rooms[room.key] = room
  self.has_room[room.key] = true
  return room.key
end

function Level:newKey()
  local key = string.format("room%04d", self.next_key)
  self.next_key = self.next_key + 1
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
    root = self.root.key,
    next_key = self.next_key
  }
  love.filesystem.write(dir.."level.json", JSON.encode(info))
end

function Level:load(name)
  if love.filesystem.getInfo("levels/"..name) then
    local dir = "levels/"..name.."/"

    local info = JSON.decode(love.filesystem.read(dir.."level.json"))
    self.name = info.name or name
    self.next_key = info.next_key or 1

    self.rooms = {}
    self.has_room = {}

    self.tile_id = 1
    self.room_id = 1
    self.tiles_by_id = {}
    self.rooms_by_id = {}

    for _,file in ipairs(love.filesystem.getDirectoryItems(dir)) do
      if file:sub(-5) == ".room" then
        self.has_room[file:sub(1, -6)] = true
      end
    end

    self.root = self:getRoom(info.root)
    self.root_key = info.root
    self:changeRoom(self.root)
  end
end

return Level