local World = {}

World.static = false
World.exists = false

function World:new(name)
  if self.mounted then
    love.filesystem.unmount(self.mounted)
    self.mounted = nil
  end

  self:clear()

  self.new = true

  local room = Room(7, 7)
  self:addRoom(room)

  self.start_key = room.key
  self.root = self:getRoom(room.key)
  self.root_key = room.key

  self:traverse(self.start)
  self:spawnPlayer()
end

function World:clear()
  self.exists = true

  self.new = false
  self.name = self.name or ""
  self.player = "flof"
  self.auto_rules = true
  self.rooms = {}
  self.has_room = {}
  self.room_won = {}

  self.start = {}
  self.start_key = nil
  self.root = nil
  self.root_key = nil

  self.tile_key = 1
  self.room_key = 1

  self.tile_id = 1
  self.room_id = 1
  self.tiles_by_id = {}
  self.tiles_by_key = {}
  self.rooms_by_id = {}
  self.rooms_by_key = {}
  self.persists = {}
  self.persists_in_room = {}

  self.paradox_keys = {}
  self.void_room = nil
  self.heaven_key = nil
end

function World:reset()
  self:load(self.name)
end

function World:spawnPlayer()
  if not World.static then
    self.room:addTile(Tile(self.player, self.room:getEntry()))
  end
end

function World:traverse(rooms)
  self:changeRoom(self.root_key, #rooms > 0)
  for i,key in ipairs(rooms) do
    for _,tile in ipairs(self.room.tiles_by_name["room"] or {}) do
      if tile.key == key then
        local room = self:getRoom(tile.room_key)
        tile.room = room
        room.exit = tile
        self:changeRoom(room, i ~= #rooms)
        break
      end
    end
  end
end

function World:changeRoom(room, small)
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
        Undo:add("create_room", tile.room.id, tile.id)
        tile.room.exit = tile
        if not self.static then
          tile.room:parse()
        end
      end
    end
  end
end

function World:getRoom(key)
  if self.has_room[key] then
    if self.rooms[key] then
      if not self.static then
        return Room.load(self.rooms[key]:save())
      else
        return self.rooms[key]
      end
    else
      local loadstr = love.filesystem.read("levels/"..Utils.toFileName(self.name).."/"..key..".room")
      local room = Room.load(Utils.loadTable(loadstr))
      if self.static then
        self.rooms[room.key] = room
      end
      return room
    end
  end
end

function World:addRoom(room, level)
  level = level or self.level
  if not room.key then
    room.key = level:newKey()
  end
  self.rooms[room.key] = room
  self.has_room[room.key] = true
  self.persists_in_room[room.key] = {}
  return room.key
end

function World:save(name)
  if not self.root then return end

  local filename = Utils.toFileName(name or self.name)
  local old_name = Utils.toFileName(self.name)
  local changed_name = not self.new and name ~= old_name

  love.filesystem.createDirectory("levels/"..filename)
  local dir = "levels/"..filename.."/"
  
  local function saveRoom(key, room)
    local tree = key:split("/")
    table.remove(tree, #tree)
    local subdir = table.concat(tree)
    if subdir ~= "" then
      love.filesystem.createDirectory(dir..subdir)
    end
    local savestr = Utils.saveTable(room:save())
    love.filesystem.write(dir..key..".room", savestr)
  end

  if not changed_name then
    for key,room in pairs(self.rooms) do
      saveRoom(key, room)
    end
  else
    for key,_ in pairs(self.has_room) do
      local room = self:getRoom(key)
      saveRoom(key, room)
    end
  end

  if name then
    self.name = name
  end

  local info = {
    name = self.name,
    player = self.player,
    auto_rules = self.auto_rules,
    start = self.start,
    start_key = self.start_key,
    root = self.root.key,
    tile_key = self.tile_key,
    room_key = self.room_key
  }
  love.filesystem.write(dir.."level.json", JSON.encode(info))
  self.new = false

  if self.mounted then
    love.filesystem.unmount(self.mounted)
    self.mounted = nil
  end
  if changed_name then
    Utils.removeDirectory("levels/"..old_name)
  end
end

function World:load(name)
  name = Utils.toFileName(name)

  if self.mounted then
    love.filesystem.unmount(self.mounted)
    self.mounted = nil
  end

  if not love.filesystem.getInfo("levels/"..name) and love.filesystem.getInfo("levels/"..name..".zip") then
    self.mounted = "levels/"..name..".zip"
    love.filesystem.mount("levels/"..name..".zip", "levels/"..name)
  end

  if love.filesystem.getInfo("levels/"..name) then
    local dir = "levels/"..name.."/"

    local info = JSON.decode(love.filesystem.read(dir.."level.json"))
    
    self:clear()
    self.name = info.name or name
    self.player = info.player or "flof"
    self.auto_rules = info.auto_rules or false
    self.start = info.start or {}
    self.room_key = info.room_key or 1
    self.tile_key = info.tile_key or 1

    local function findRooms(d)
      local dir = dir
      if d then
        dir = dir .. d .. "/"
      end
      local files = love.filesystem.getDirectoryItems(dir)
      for _,file in ipairs(files) do
        if file:sub(-5) == ".room" then
          local roomkey = (d and (d.."/") or "")..file:sub(1, -6)
          self.has_room[roomkey] = true
          self.persists_in_room[roomkey] = {}
        elseif love.filesystem.getInfo(dir .. file).type == "directory" then
          findRooms((d and (d.."/") or "")..file)
        end
      end
    end
    findRooms()

    self.root = self:getRoom(info.root)
    self.root_key = info.root

    self:traverse(self.start)
    if not self.start_key then
      self.start_key = self.room.key
    end
    self:spawnPlayer()
  end
end

function World:merge(name)
  name = Utils.toFileName(name)
  if love.filesystem.getInfo("levels/"..name) then
    local dir = "levels/"..name.."/"
    local newdir = "levels/"..Utils.toFileName(self.name).."/"..name.."/"

    Utils.removeDirectory(newdir)
    love.filesystem.createDirectory(newdir)

    for k,v in pairs(self.rooms) do
      if k:startsWith(name.."/") then
        self.rooms[k] = nil
      end
    end
    for k,v in pairs(self.has_room) do
      if k:startsWith(name.."/") then
        self.has_room[k] = nil
      end
    end

    local function fixRoom(roomkey)
      local newkey = name.."/"..roomkey

      local loadstr = love.filesystem.read(dir..roomkey..".room")
      print(dir..roomkey..".room")
      local roomdata = Utils.loadTable(loadstr)
      
      roomdata.key = newkey
      roomdata.paradox_key = roomdata.paradox_key and (name.."/"..roomdata.paradox_key) or nil
      roomdata.non_paradox_key = roomdata.non_paradox_key and (name.."/"..roomdata.non_paradox_key) or nil

      if roomdata.tiles then
        for _,tiledata in ipairs(roomdata.tiles) do
          tiledata.key = tiledata.key and (name.."/"..tiledata.key) or nil
          tiledata.room = tiledata.room and (name.."/"..tiledata.room) or nil
        end
      end

      local tree = roomkey:split("/")
      table.remove(tree, #tree)
      local subdir = table.concat(tree)
      if subdir ~= "" then
        love.filesystem.createDirectory(newdir..subdir)
      end
      local savestr = Utils.saveTable(roomdata)
      love.filesystem.write(newdir..roomkey..".room", savestr)

      self.has_room[roomdata.key] = true
    end

    local function fixRooms(d)
      local dir = dir
      if d then
        dir = dir .. d .. "/"
      end
      local files = love.filesystem.getDirectoryItems(dir)
      for _,file in ipairs(files) do
        if file:sub(-5) == ".room" then
          fixRoom((d and (d.."/") or "")..file:sub(1, -6))
        elseif love.filesystem.getInfo(dir .. file).type == "directory" then
          fixRooms((d and (d.."/") or "")..file)
        end
      end
    end
    fixRooms()

    local info = JSON.decode(love.filesystem.read(dir.."level.json"))
    return name.."/"..(info.start_key or info.root_key)
  end
end

function World:getParadox(ref)
  local idstr = ref.width..","..ref.height
  if not self.paradox_keys[idstr] then
    local room = Room(ref.width, ref.height, {paradox = true, palette = "paradox", static = true})
    room:addTile(Tile("tile", math.floor(room.width/2), math.floor(room.height/2), {activator = self.player}))
    self.paradox_keys[idstr] = self:addRoom(room)
  end
  return self:getRoom(self.paradox_keys[idstr])
end

function World:getVoid()
  if not self.void_room then
    self.void_room = Room(0, 0, {void = true, palette = "void"})
    self:addRoom(self.void_room)
  end
  return self.void_room
end

function World:getHeaven()
  if not self.heaven_key then
    local room = Room(9, 5, {heaven = true, static = true})
    room:addTile(Tile("tile", 6, 2, {activator = self.player}))
    self.heaven_key = self:addRoom(room)
  end
  return self:getRoom(self.heaven_key)
end

return World