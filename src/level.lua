local Level = Class{}

function Level:init(o)
  o = o or {}

  self.uuid = o.uuid or Utils.createUUID()
  self.name = o.name or ""
  self.player = o.player or "flof"
  self.won = o.won or false

  self.start = o.start or {}
  self.start_key = o.start_key or {}
  self.root_key = o.root_key or {}

  self.next_tile_key = o.next_tile_key or o.tile_key or 1
  self.next_room_Key = o.next_room_Key or o.room_key or 1

  if o.auto_rules == nil then
    self.auto_rules = true
  else
    self.auto_rules = o.auto_rules
  end

  self.path = {}
  self.rooms = {}
  self.sublevels = {}
end

function Level:newKey()
  local key = self.uuid..":"..string.format("room%04d", self.room_key)
  self.room_key = self.room_key + 1
  return key
end

function Level:save()
  return {
    uuid = self.uuid,
    name = self.name,
    player = self.player,
    won = self.won,
    auto_rules = self.auto_rules,
    start = self.start,
    start_key = self.start_key,
    root = self.root_key,
    next_tile_key = self.next_tile_key,
    next_room_key = self.next_room_key
  }
end

return Level