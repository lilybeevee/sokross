local World = {}

World.static = false
World.exists = false

function World:newLevel(name)
  self:clear()

  self.new = true --fun story: lily initially named this function World:new(). then she set self.new to be true. this was in the code for a long time because we only ever called this function once
  self.level = self:createLevel(name)
  self.main = self.level

  self:traverse(self.main.start)
end

function World:clear()
  self.exists = true
  self.new = false

  self.main = Level()
  self.level = nil
  self.levels = {}
  self.room = nil
  self.rooms = {}
  self.has_room = {}

  self.tile_id = 1
  self.room_id = 1
  self.tiles_by_id = {}
  self.tiles_by_key = {}
  self.rooms_by_id = {}
  self.rooms_by_key = {}
  self.persists = {}
  self.persists_in_room = {}
  self.room_winnable = {}
  self.teles = {}
  self.teles_by = {}
  self.level_exits = {}

  self.paradox_keys = {}
  self.void_room = nil
  self.heaven_key = nil
end

function World:reset()
  self:load(self.main.path[1])
end

function World:smallReset()
  local info = self.level_exits[self.level]
  if info and info.exit and self.tiles_by_id[info.exit] then
    local exit = self.tiles_by_id[info.exit]
    self.level:reset()
    self:changeRoom(self:getRoom(exit.room_key))
    exit.room = self.room
    self.room.exit = exit
    self:spawnPlayer()
  else
    self:reset()
  end
end

function World:spawnPlayer()
  if not World.static then
    return self.room:addTile(Tile(self.level.player, self.room:getEntry()))
  end
end

function World:traverse(rooms)
  self:changeRoom(self.main.root, #rooms > 0)
  World.level_exits[self.main] = {layer = 1}
  local player = self:spawnPlayer()
  for i,key in ipairs(rooms) do
    for _,tile in ipairs(self.room.tiles_by_name["room"] or {}) do
      if tile.key == key then
        local room = self:getRoom(tile.room_key)
        tile.room = room
        room.exit = tile

        if not World.static then
          local best_dir = 0
          local best_empty = false
          for i = 4,1,-1 do
            local dir = Dir.rotateCW(i)
            local ox, oy = Dir.toPos(dir)
            if self.room:inBounds(tile.x - ox, tile.y - oy) then
              local stopped = false
              local empty = true
              for _,other in ipairs(self.room:getTilesAt(tile.x - ox, tile.y - oy)) do
                empty = false
                for _,effect in ipairs(SOLID_EFFECTS) do
                  if other:hasRule(effect) then
                    stopped = true
                    break
                  end
                end
              end
              if not stopped and (best_dir == 0 or (not best_empty and empty)) then
                best_dir = dir
                best_empty = empty
              end
            end
          end
          local ox, oy = Dir.toPos(best_dir)
          player:setPos(tile.x - ox, tile.y - oy, self.room)
          player.dir = best_dir
          room:enter(player, best_dir)
          if i == #rooms then
            local x, y = room:getEntry()
            player:setPos(x, y, room)
            player.dir = 1
          end
        else
          self:changeRoom(room, i ~= #rooms)
        end
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
  self.level = room:getLevel()
  if Gamestate.current() == Game then
    self.room:parse()
  end
  --[[if not small then
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
  end]]
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
      local levelkey, roomkey = unpack(key:split(":"))
      local dir = table.concat({"levels", unpack(self.levels[levelkey].path)}, "/")
      local loadstr = love.filesystem.read(dir.."/"..roomkey..".room")
      local room = Room.load(Utils.loadTable(loadstr))
      if self.static then
        self.rooms[room.key] = room
      end
      return room
    end
  end
end

function World:getLevel(key)
  local keys = key:split(":")
  return self.levels[keys[1]]
end

function World:addRoom(room, level)
  level = level or self.level
  if not room.key then
    room.key = level:newRoomKey()
  end
  if not self.has_room[room.key] then
    table.insert(level.rooms, room.key)
  end
  self.rooms[room.key] = room
  self.has_room[room.key] = true
  self.persists_in_room[room.key] = {}
  return room.key
end

function World:createLevel(name, parent)
  local level = Level{name = name}
  self.levels[level.uuid] = level

  local room = Room(7, 7)
  self:addRoom(room, level)

  level.root = room.key

  if parent then
    level.path = Utils.copy(parent.path)
    table.insert(parent.sublevels, level.uuid)
  end
  table.insert(level.path, Utils.toFileName(level.name))

  return level
end

function World:save()
  self.new = false

  for key,level in pairs(self.levels) do
    local dir = table.concat({"levels", unpack(level.path)}, "/")
    love.filesystem.createDirectory(dir)
    love.filesystem.write(dir.."/level.json", JSON.encode(level:save()))
  end

  self.room_winnable = {}
  for key,room in pairs(self.rooms) do
    local levelkey, roomkey = unpack(key:split(":"))
    local dir = table.concat({"levels", unpack(self.levels[levelkey].path)}, "/")
    local savestr = Utils.saveTable(room:save())
    love.filesystem.write(dir.."/"..roomkey..".room", savestr)
  end
end

function World:load(name)
  name = Utils.toFileName(name)

  if not love.filesystem.getInfo("levels/"..name) and love.filesystem.getInfo("levels/"..name..".zip") then
    love.filesystem.mount("levels/"..name..".zip", "levels/"..name)
  end

  if love.filesystem.getInfo("levels/"..name) then
    self:clear()

    self.main = self:loadLevel{name}
    self.level = self.main

    self:traverse(self.main.start)
  end
end

function World:loadLevel(path)
  local dir = table.concat({"levels", unpack(path)}, "/")
  if not love.filesystem.getInfo(dir.."/".."level.json") then print("failed "..dir) return end

  local level = Level(JSON.decode(love.filesystem.read(dir.."/".."level.json")))
  level.path = path
  self.levels[level.uuid] = level

  for _,file in ipairs(love.filesystem.getDirectoryItems(dir)) do
    local info = love.filesystem.getInfo(dir.."/"..file)

    if info.type == "file" and file:sub(-5) == ".room" then
      local loadstr = love.filesystem.read(dir.."/"..file)
      local roomdata = Utils.loadTable(loadstr)
      self.has_room[roomdata.key] = true
      self.persists_in_room[roomdata.key] = {}
      self.room_winnable[roomdata.key] = roomdata.winnable or false
      table.insert(level.rooms, roomdata.key)

    elseif info.type == "directory" then
      local new_path = Utils.copy(path)
      table.insert(new_path, file)
      local new_level = self:loadLevel(new_path)
      if new_level then
        table.insert(level.sublevels, new_level.uuid)
      end
    end
  end

  return level
end

function World:merge(name)
  name = Utils.toFileName(name)

  if self.main and name == Utils.toFileName(self.main.name) then
    return self.main.root
  end

  if love.filesystem.getInfo("levels/"..name) then
    local new_path = Utils.copy(self.level.path)
    table.insert(new_path, name)

    local new_dir = table.concat({"levels", unpack(new_path)}, "/")

    Utils.removeDirectory(new_dir)
    print(Utils.copyDirectory("levels/"..name, new_dir))

    local level = self:loadLevel(new_path)
    table.insert(self.level.sublevels, level.uuid)

    return level.root
  end
end

function World:getParadox(ref)
  local idstr = ref.width..","..ref.height
  if not self.paradox_keys[idstr] then
    local room = Room(ref.width, ref.height, {paradox = true, palette = "paradox", static = true})
    self.paradox_keys[idstr] = self:addRoom(room, ref:getLevel())
    room:addTile(Tile("tile", math.floor(room.width/2), math.floor(room.height/2), {activator = self.player}))
  end
  return self:getRoom(self.paradox_keys[idstr])
end

function World:getVoid()
  if not self.void_room then
    self.void_room = Room(0, 0, {void = true, palette = "void", static = true})
    self:addRoom(self.void_room, self.main)
  end
  return self.void_room
end

function World:getHeaven()
  if not self.heaven_key then
    local room = Room(9, 5, {heaven = true, palette = "heaven", static = true})
    self.heaven_key = self:addRoom(room, self.main)
    room:addTile(Tile("tile", 6, 2, {activator = self.player}))
  end
  return self:getRoom(self.heaven_key)
end

return World