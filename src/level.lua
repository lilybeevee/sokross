local Level = Class{}

function Level:init(uuid, o)
  o = o or {}

  self.uuid = uuid
  self.name = o.name or ""
  self.player = o.player or "flof"
  self.rooms = {}
  self.has_room = {}
  self.room_won = {}

  self.start = o.start or {}
  self.start_key = o.start_key or {}
  self.root = nil
  self.root_key = o.root_key or {}

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