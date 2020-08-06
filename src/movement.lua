local Movement = {}

function Movement.turn(dir)
  local moves = {}
  for _,playrule in ipairs(Level.room:getRules(nil, "play")) do
    for _,tile in ipairs(Level.room:getTilesByName(playrule.target)) do
      table.insert(moves, {tile = tile, dir = dir})
    end
  end
  Movement.move(moves)
end

function Movement.move(moves)
  Movement.moved_word = false

  moves = moves or {}
  local has_moved = {}

  local playsound_push = false
  local playsound_enter = false
  local playsound_exit = false

  local move_done = false
  local to_destroy = {}
  while #moves > 0 and not move_done do
    move_done = true

    local still_moving = {}
    local movers = {}
    for _,move in ipairs(moves) do
      if move.dir then
        local success, new_movers = Movement.canMove(move.tile, move.dir, false, "move")
        if success then
          move_done = false
          Utils.merge(movers, new_movers)
        else
          move.tile.belt_start = nil
          table.insert(still_moving, move)
        end
      end
    end

    for _,mover in ipairs(movers) do
      if mover.tile.parent then
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

        --[[local undo_dir = mover.tile.dir ~= mover.dir and mover.tile.dir or nil
        local undo_room = mover.room.id ~= mover.tile.parent.id and mover.tile.parent.id or nil
        Undo:add("move", mover.tile.id, mover.tile.x, mover.tile.y, undo_dir, undo_room)]]

        mover.tile:moveTo(mover.x, mover.y, mover.room, mover.dir)
        has_moved[mover.tile] = true
      end
    end
    for _,mover in ipairs(movers) do
      local new_to_destroy, new_moves = mover.tile:update()
      Game.updated_tiles[mover.tile] = true
      
      for _,new in ipairs(new_to_destroy) do
        table.insert(to_destroy, new)
      end
      
      move_done = #new_moves == 0
      for _,new in ipairs(new_moves) do
        table.insert(still_moving, new)
      end
    end

    moves = still_moving
  end

  for tile,_ in pairs(has_moved) do
    if tile.tile.walk then
      tile.walk_frame = not tile.walk_frame
    end
  end
  
  Game:handleDels(to_destroy)
end

function Movement.canMove(tile, dir, enter, reason, pushing, already_entered)
  if tile.name == "room" then
    local conns = tile:getConnections("line")
    for _,conn in ipairs(conns) do
      if conn[1].name == "line" then
        return false, {}
      end
    end
  end

  local x, y, room
  if not enter then
    local dx, dy = Dir.toPos(dir)
    x, y = tile.x + dx, tile.y + dy
    room = tile.parent
  else
    x, y, room = Movement.getNextTile(tile, dir)
  end
  already_entered = already_entered or {}

  local current_mover = {tile = tile, x = x, y = y, dir = dir, room = room, reason = reason}
  local movers = {}

  if not room.void and not room:inBounds(x, y) and room:hasRule("wall", "stop") then
    return false, {}
  end

  for _,other in ipairs(room:getTilesAt(x, y)) do
    local success, pushable, moveable = false, false, true

    if other:hasRule("push") then
      pushable = true
      if pushing and other:hasRule("heavy") then
        success = false
      else
        local new_movers
        success, new_movers = Movement.canMove(other, dir, false, "push", true)
        if success then
          Utils.merge(movers, new_movers)
        end
      end
    elseif other:hasRule("stop") then
      moveable = false
      success = false
    else
      success = true
    end

    local is_ladder = not tile.room_key and room.exit and tile:hasRule("exit")
    local is_entry = (tile.room_key and not tile.locked) or is_ladder

    local other_ladder = not other.room_key and room.exit and other:hasRule("exit")
    local can_enter = (other.room_key and not other.locked) or other_ladder

    if can_enter and not (success and pushable) then
      local new_movers
      if tile.room and tile.persist and tile.parent:getParent() and tile.parent.exit.key == tile.key then
        -- really hacky solution to just bypass the infloop paradox if we're pushing a persistent room out of itself
        success = true
      elseif already_entered[other] then
        current_mover.x, current_mover.y, current_mover.room = tile.parent:getParadoxEntry(tile)
        success = true
      else
        already_entered[other] = true
        success, new_movers = Movement.canMove(tile, dir, true, other_ladder and "exit" or "enter", pushing, already_entered)
        if success then
          current_mover = table.remove(new_movers, 1)
          Utils.merge(movers, new_movers)
          entered = true
        end
      end
    elseif is_entry and not success and moveable then
      local new_movers
      success, new_movers = Movement.canMove(other, Dir.reverse(dir), true, is_ladder and "exit" or "enter", pushing)
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
        Undo:add("create_room", tile.room.id, tile.id)
        tile.room.exit = tile
        tile.room:parse()
      end
      local ex, ey = tile.room:getEntry()
      return ex, ey, tile.room
    elseif tile.parent.exit and tile:hasRule("exit") then
      if tile.parent:getParent() then
        return tile.parent.exit.x + dx, tile.parent.exit.y + dy, tile.parent:getParent()
      else
        return tile.parent:getParadoxEntry(tile)
      end
    end
  end
  return x, y, tile.parent
end

return Movement