local Movement = {}

function Movement.move(dir)
  Movement.moved_word = false

  local moves = {}
  local has_moved = {}

  local playsound_push = false
  local playsound_enter = false
  local playsound_exit = false

  for _,playrule in ipairs(Level.room:getRules(nil, "play")) do
    for _,tile in ipairs(Level.room:getTilesByName(playrule.target)) do
      table.insert(moves, {tile = tile, dir = dir})
    end
  end

  local move_done = false
  while #moves > 0 and not move_done do
    move_done = true

    local still_moving = {}
    local movers = {}
    for _,move in ipairs(moves) do
      local success, new_movers = Movement.canMove(move.tile, move.dir, false, "move")
      if success then
        move_done = false
        Utils.merge(movers, new_movers)
      else
        table.insert(still_moving, move)
      end
    end

    for _,mover in ipairs(movers) do
      if mover.tile.word then
        Game.parse_room[mover.room] = true
        if mover.room ~= mover.tile.parent then
          Game.parse_room[mover.tile.parent] = true
        end
      end

      if mover.reason == "enter" then
        Game.sound["enter"] = true
      elseif mover.reason == "exit" then
        Game.sound["exit"] = true
      elseif mover.reason == "push" then
        Game.sound["push"] = true
      end

      local undo_dir = mover.tile.dir ~= mover.dir and mover.tile.dir or nil
      local undo_room = mover.room.id ~= mover.tile.parent.id and mover.tile.parent.id or nil
      Undo:add("move", mover.tile.id, mover.tile.x, mover.tile.y, undo_dir, undo_room)

      mover.tile:moveTo(mover.x, mover.y, mover.room)
      mover.tile.dir = mover.dir

      has_moved[mover.tile] = true
      
      for _,other in ipairs(mover.room:getTilesAt(mover.x, mover.y)) do
        if other:hasRule("move") then
          if not mover.tile.belt_start then
            mover.tile.belt_start = {other.x, other.y}
            move_done = false
            table.insert(still_moving, {tile = mover.tile, dir = other.dir})
          else
            if other.x == mover.tile.belt_start[1] and other.y == mover.tile.belt_start[2] then
              mover.tile:goToParadox()
              mover.tile.belt_start = nil
            else
              move_done = false
              table.insert(still_moving, {tile = mover.tile, dir = other.dir})
            end
          end
        end
      end
    end

    moves = still_moving
  end

  for tile,_ in pairs(has_moved) do
    if tile.tile.walk then
      tile.walk_frame = not tile.walk_frame
    end
  end
end

function Movement.canMove(tile, dir, enter, reason)
  local x, y, room
  if not enter then
    local dx, dy = Dir.toPos(dir)
    x, y = tile.x + dx, tile.y + dy
    room = tile.parent
  else
    x, y, room = Movement.getNextTile(tile, dir)
  end

  local current_mover = {tile = tile, x = x, y = y, dir = dir, room = room, reason = reason}
  local movers = {current_mover}

  if not room:inBounds(x, y) and room:hasRule("wall", "stop") then
    return false, {}
  end

  for _,other in ipairs(room:getTilesAt(x, y)) do
    local success, pushable, moveable = false, false, true
    if other:hasRule("push") then
      pushable = true

      local new_movers
      success, new_movers = Movement.canMove(other, dir, false, "push")
      if success then
        Utils.merge(movers, new_movers)
      end
    elseif other:hasRule("stop") then
      moveable = false
      success = false
    else
      success = true
    end

    local is_ladder = not tile.room_key and room.exit and tile:hasRule("exit")
    local is_entry = tile.room_key or is_ladder

    local other_ladder = not other.room_key and room.exit and other:hasRule("exit")
    local can_enter = other.room_key or other_ladder

    if can_enter and not (success and pushable) then
      local new_movers
      success, new_movers = Movement.canMove(tile, dir, true, other_ladder and "exit" or "enter")
      if success then
        current_mover = table.remove(new_movers, 1)
        Utils.merge(movers, new_movers)
        entered = true
      end
    elseif is_entry and ((not success) or (success and not pushable)) and moveable then
      local new_movers
      success, new_movers = Movement.canMove(other, Dir.reverse(dir), true, is_ladder and "exit" or "enter")
      if success then
        Utils.merge(movers, new_movers)
      end
    end
    if not success then
      return false, {}
    end
  end

  table.insert(movers, 1, current_mover)
  return true, movers
end

function Movement.getNextTile(tile, dir)
  local dx, dy = Dir.toPos(dir)
  local x, y = tile.x + dx, tile.y + dy
  
  for _,tile in ipairs(tile.parent:getTilesAt(x, y)) do
    if tile.room_key then
      if not tile.room then
        tile.room = Level:getRoom(tile.room_key)
        tile.room.exit = tile
        tile.room:parse()
      end
      local ex, ey = tile.room:getEntry()
      return ex, ey, tile.room
    elseif tile.parent.exit and tile:hasRule("exit") then
      return tile.parent.exit.x + dx, tile.parent.exit.y + dy, tile.parent:getParent()
    end
  end
  return x, y, tile.parent
end

return Movement