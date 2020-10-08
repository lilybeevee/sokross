local Level = Class{}

function Level:init(o)
  o = o or {}

  self.uuid = o.uuid or Utils.createUUID()
  self.name = o.name or ""
  self.player = o.player or "flof"

  self.start = o.start or {}
  self.root = o.root

  self.next_tile_key = o.next_tile_key or o.tile_key or 1
  self.next_room_key = o.next_room_key or o.room_key or 1

  if o.auto_rules == nil then
    self.auto_rules = true
  else
    self.auto_rules = o.auto_rules
  end

  self.won = false
  self.path = {}
  self.rooms = {}
  self.sublevels = {}
end

function Level:newRoomKey()
  local key = self.uuid..":"..string.format("room%04d", self.next_room_key)
  self.next_room_key = self.next_room_key + 1
  return key
end

function Level:newTileKey()
  local key = self.uuid..":"..self.next_tile_key
  self.next_tile_key = self.next_tile_key + 1
  return key
end

function Level:reset()
  local remove_persists = Utils.copy(World.persists)
  for key,_ in pairs(remove_persists) do
    if World:getLevel(key) == self then
      World.persists[key] = nil
      local to_remove = Utils.copy(World.tiles_by_key[key])
      for _,tile in ipairs(to_remove) do
        if tile.parent then
          tile.parent:removeTile(tile, true)
        end
      end
    end
  end
  for _,roomkey in ipairs(self.rooms) do
    local to_remove = Utils.copy(World.rooms_by_key[roomkey] or {})
    for _,room in pairs(to_remove) do
      room:remove()
    end
  end
end

function Level:win()
  self.won = true
  local info = World.level_exits[self]
  World.level_exits[self] = nil
  if info and info.parent and World.rooms_by_id[info.parent] then
    local parent = World.rooms_by_id[info.parent]
    local exit = info.exit and World.tiles_by_id[info.exit] or nil
    local exiter = World.tiles_by_id[info.player]
    if exiter then
      exiter.parent:removeTile(exiter)
    else
      exiter = Tile(parent:getLevel().player, info.pos[1], info.pos[2])
    end
    exiter.dir = info.dir
    if exit and exit.parent and exit.parent.id == info.parent then
      local dx, dy = Dir.toPos(info.dir)
      exiter.x = exit.x + dx
      exiter.y = exit.y + dy
      --exit.room:remove()
      --exit.room = World:getRoom(exit.room_key)
      --exit.room.exit = exit
    end
    self:reset()
    parent:addTile(exiter)
    World:changeRoom(parent)
    Undo:clear()
    Undo.enabled = false
  else
    Gamestate.switch(Editor)
  end
end

function Level:rename(name, copy)
  local filename = Utils.toFileName(name)

  local path_index = #self.path
  if filename ~= self.path[path_index] then
    local function replacePath(level)
      level.path[path_index] = filename
      for _,subkey in ipairs(level.sublevels) do
        replacePath(World.levels[subkey])
      end
    end

    local old_dir = table.concat({"levels", unpack(self.path)}, "/")
    replacePath(self)
    local new_dir = table.concat({"levels", unpack(self.path)}, "/")

    Utils.removeDirectory(new_dir)
    if copy then
      Utils.copyDirectory(old_dir, new_dir)
    else
      Utils.moveDirectory(old_dir, new_dir)
    end
  end

  self.name = name
  World:save()
end

function Level:save()
  return {
    uuid = self.uuid,
    name = self.name,
    player = self.player,
    auto_rules = self.auto_rules,
    start = self.start,
    root = self.root,
    next_tile_key = self.next_tile_key,
    next_room_key = self.next_room_key
  }
end

return Level