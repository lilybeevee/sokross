local Undo = {}

function Undo:clear()
  self.index = 0
  self.buffer = {}
end

function Undo:new()
  table.insert(self.buffer, {})
  self.index = self.index + 1
end

function Undo:add(...)
  table.insert(self.buffer[self.index], 1, {...})
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
end

function Undo:doUndo(undo)
  local action = undo[1]

  Game.turn = Game.turn - 1

  if action == "move" then
    local tileid, x, y, dir, roomid = undo[2], undo[3], undo[4], undo[5], undo[6]

    local tile = Game.tiles_by_id[tileid]
    local room = roomid and Game.rooms_by_id[roomid] or nil

    if tile.word then
      Game.parse_room[tile.parent] = true
      if room and room ~= tile.parent then
        Game.parse_room[room] = true
      end
    end

    tile:moveTo(x, y, room)
    tile.dir = dir or tile.dir
  end
end

return Undo