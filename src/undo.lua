local Undo = {}

Undo.enabled = false

function Undo:clear()
  self.index = 0
  self.buffer = {}
end

function Undo:new()
  table.insert(self.buffer, {})
  self.index = self.index + 1
end

function Undo:add(...)
  if self.enabled then
    table.insert(self.buffer[self.index], 1, {...})
  end
end

function Undo:goTo(i)
  self:back(self.index - i)
end

function Undo:back(count)
  for i = 1, count or 1 do
    local buffer = self.buffer[self.index]
    if buffer then
      for _,undo in ipairs(buffer) do
        self:doUndo(undo)
      end
      table.remove(self.buffer, self.index)
      self.index = self.index - 1
    end
  end
  World.room:updateVisuals()
  Game:playSounds()
end

function Undo:doUndo(undo)
  local action = undo[1]

  Game.turn = Game.turn - 1

  if action == "move" then
    local tileid, x, y, roomid, dir = undo[2], undo[3], undo[4], undo[5], undo[6]

    local tile = World.tiles_by_id[tileid]
    local room = roomid and World.rooms_by_id[roomid] or nil

    if tile.word then
      Game.parse_room[tile.parent] = true
      if room and room ~= tile.parent then
        Game.parse_room[room] = true
      end
    end

    tile:moveTo(x, y, room, dir, true)
  elseif action == "rotate" then
    local tileid, dir = undo[2], undo[3]

    local tile = World.tiles_by_id[tileid]

    tile:rotate(dir, true)
  elseif action == "remove" then
    local tiledata, roomid = undo[2], undo[3]

    local tile = Tile.load(tiledata)
    local room = World.rooms_by_id[roomid]

    room:addTile(tile, true)

    if tile.word then
      Game.parse_room[room] = true
    end
  elseif action == "add" then
    local tileid = undo[2]

    local tile = World.tiles_by_id[tileid]
    local room = tile.parent

    room:removeTile(tile, true, true)

    if tile.word then
      Game.parse_room[room] = true
    end
  elseif action == "create_room" then
    local roomid, exitid = undo[2], undo[3]

    local room = World.rooms_by_id[roomid]
    local exit = World.tiles_by_id[exitid]

    room:remove()
    if exit then
      exit.room = nil
    end
  elseif action == "create_paradox" then
    local roomid, baseid = undo[2], undo[3]

    local room = World.rooms_by_id[roomid]
    local base = World.rooms_by_id[baseid]

    room:remove()
    base.paradox_room = nil
  elseif action == "update_persist" then
    local key, data = undo[2], undo[3]
    World.persists[key] = data
  elseif action == "savepoint" then
    World.tiles_by_id[undo[2]].savepoint = undo[3]
  end
end

return Undo