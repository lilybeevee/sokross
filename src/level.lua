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

function Level:rename(name)
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
    Utils.moveDirectory(old_dir, new_dir)
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