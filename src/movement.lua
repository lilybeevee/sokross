local Movement = {}

function Movement.turn(dir)
  local moves = {}
  for _,playrule in ipairs(World.room:getRules(nil, "play")) do
    for _,tile in ipairs(World.room:getTilesByName(playrule.target)) do
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
    local effects = {}
    for _,move in ipairs(moves) do
      if move.dir then
        local success, new_movers, new_effects = Movement.canMove(move.tile, move.dir, {reason = "move"})
        if success then
          move_done = false
          Utils.merge(movers, new_movers)
          Utils.merge(effects, new_effects)
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

        if mover.x ~= mover.tile.x or mover.y ~= mover.tile.y or mover.room ~= mover.tile.parent then
          has_moved[mover.tile] = true
        end
        mover.tile:moveTo(mover.x, mover.y, mover.room)
        if mover.vdir then
          mover.tile:rotate(mover.vdir)
        end
        if mover.tile.icy then
          move_done = false
          table.insert(still_moving, {tile = mover.tile, dir = mover.dir})
        end
      end
    end
    for _,mover in ipairs(movers) do
      local new_to_destroy, new_moves = mover.tile:update()
      --Game.updated_tiles[mover.tile] = true
      
      for _,new in ipairs(new_to_destroy) do
        table.insert(to_destroy, new)
      end
      
      if #new_moves > 0 then
        move_done = false
      end
      for _,new in ipairs(new_moves) do
        table.insert(still_moving, new)
      end
    end
    for _,effect in ipairs(effects) do
      local name = effect[1]

      if name == "unlock" then
        Game.sound["unlock"] = true
        table.insert(to_destroy, effect[2])
        table.insert(to_destroy, effect[3])
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

function Movement.canMove(tile, dir, o)
  if tile.name == "room" then
    local conns = tile:getConnections("line")
    for _,conn in ipairs(conns) do
      if conn[1].name == "line" then
        return false, {}
      end
    end
  end

  local x, y, room
  if not o.enter then
    local dx, dy = Dir.toPos(dir)
    x, y = (o.x or tile.x) + dx, (o.y or tile.y) + dy
    room = o.room or tile.parent
  else
    x, y, room = Movement.getNextTile(o.x or tile.x, o.y or tile.y, dir, o.room or tile.parent)
  end
  local prevx, prevy = Vector.sub(x, y, Dir.toPos(dir))
  local vdir = o.vdir or dir
  local already_entered = o.already_entered or {}
  local ignored = o.ignored or {}

  local current_mover = {moved = true, tile = tile, x = x, y = y, dir = dir, vdir = vdir, room = room, reason = o.reason or "unknown"}
  local movers = {}
  local effects = {}

  if not room.void and not room:inBounds(x, y) and room:hasRule("wall", "stop") then
    return false, {}, {}
  end

  local holding = tile:getHolding(o.reason == "hold")

  if o.reason ~= "hold" and #holding > 0 then
    local straight = false -- i;m gay
    if dir == tile.dir or dir == Dir.reverse(tile.dir) then
      straight = true -- fuck
    end

    local function moveHeld(holder, held, offset)
      local success, new_movers, new_effects = true, {}, {}
      local mx, my, pdir, vdir
      if straight then
        success, new_movers, new_effects = Movement.canMove(held, dir, {vdir = tile.dir, reason = "hold", pushing = true, ignored = {[holder] = true}})
      else
        local mx, my = Vector.add(prevx, prevy, Vector.mul(offset, Dir.toPos(dir)))
        local pushdir
        if dir == Dir.rotateCW(tile.dir) then
          pushdir = Dir.rotateCW(dir)
        else
          pushdir = Dir.rotateCCW(dir)
        end
        mx, my = Vector.sub(mx, my, Dir.toPos(pushdir))
        success, new_movers, new_effects = Movement.canMove(held, pushdir, {x = mx, y = my, room = room, vdir = dir, reason = "hold", pushing = true, ignored = {[holder] = true}})
      end
      if success then
        for _,other in ipairs(held:getHolding(true)) do
          local held_success, held_movers, held_effects = moveHeld(held, other, offset + 1)
          success = success and held_success
          if not success then
            return false, {}, {}
          else
            Utils.merge(new_movers, held_movers)
            Utils.merge(new_effects, held_effects)
          end
        end
      end
      return success, new_movers, new_effects
    end

    if straight then
      current_mover.vdir = tile.dir
    else
      current_mover.moved = false
      current_mover.x = tile.x
      current_mover.y = tile.y
    end
    for _,other in ipairs(holding) do
      local held_success, held_movers, held_effects = moveHeld(tile, other, 1)
      if not held_success then
        return false, {}, {}
      else
        Utils.merge(movers, held_movers)
        Utils.merge(effects, held_effects)
      end
    end
  end

  if current_mover.moved then
    for _,other in ipairs(room:getTilesAt(x, y, true)) do
      if not ignored[other] and not Utils.contains(holding, other) then
        local success, pushable, moveable = false, false, true
        if other:hasRule("push") or (other.dir == dir and other:hasRule("hold")) then
          pushable = true
          if o.pushing and other:hasRule("heavy") then
            success = false
          else
            local new_movers, new_effects
            success, new_movers, new_effects = Movement.canMove(other, dir, {x=x, y=y, room=room, reason = "push", pushing = true})
            if success then
              Utils.merge(movers, new_movers)
              Utils.merge(effects, new_effects)
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

        if not success and ((tile:hasRule("open") and other:hasRule("shut")) or (tile:hasRule("shut") and other:hasRule("open"))) then
          table.insert(effects, {"unlock", tile, other})
          success = true
        elseif can_enter and not (success and pushable) then
          local new_movers, new_effects
          if tile.room and tile.persist and tile.parent:getParent() and tile.parent.exit.key == tile.key then
            -- really hacky solution to just bypass the infloop paradox if we're pushing a persistent room out of itself
            success = true
          elseif already_entered[other] then
            current_mover.x, current_mover.y, current_mover.room = tile.parent:getParadoxEntry(tile)
            success = true
          else
            already_entered[other] = true
            success, new_movers, new_effects = Movement.canMove(tile, dir, {x = prevx, y = prevy, room = room, vdir = o.vdir, reason = other_ladder and "exit" or "enter", enter = true, pushing = o.pushing, already_entered = already_entered})
            if success then
              current_mover = table.remove(new_movers, 1)
              Utils.merge(movers, new_movers)
              Utils.merge(effects, new_effects)
              entered = true
            end
          end
        elseif is_entry and not success and moveable then
          local new_movers, new_effects
          success, new_movers, new_effects = Movement.canMove(other, Dir.reverse(dir), {x=x, y=y, room=room, reason = is_ladder and "exit" or "enter", enter = true, pushing = o.pushing})
          if success then
            Utils.merge(movers, new_movers)
            Utils.merge(effects, new_effects)
          end
        end
        if not success then
          return false, {}, {}
        end
      end
    end
  end

  for _,mover in ipairs(movers) do
    if not mover.moved then
      current_mover.moved = false
      current_mover.x = tile.x
      current_mover.y = tile.y
      current_mover.room = tile.parent
      if #holding > 0 or o.reason == "hold" then
        current_mover.vdir = tile.dir
      end
      break
    end
  end

  table.insert(movers, 1, current_mover)
  return true, movers, effects
end

function Movement.getNextTile(sx, sy, dir, room, entered)
  local dx, dy = Dir.toPos(dir)
  local x, y = sx + dx, sy + dy

  local entered = entered or {}
  
  for _,tile in ipairs(room:getTilesAt(x, y)) do
    if entered[tile] then
      return tile.parent:getParadoxEntry(tile)
    else
      if tile.room_key then
        if not tile.room then
          tile.room = World:getRoom(tile.room_key)
          Undo:add("create_room", tile.room.id, tile.id)
          tile.room.exit = tile
          tile.room:parse()
        end
        local ex, ey = tile.room:getEntry()
        --[[local new_entered = Utils.copy(entered)
        new_entered[tile] = true
        return Movement.getNextTile(ex, ey, 0, tile.room, new_entered)]]
        return ex, ey, tile.room
      elseif tile.parent.exit and tile:hasRule("exit") then
        if tile.parent:getParent() then
          --[[local new_entered = Utils.copy(entered)
          new_entered[tile] = true
          return Movement.getNextTile(tile.parent.exit.x, tile.parent.exit.y, dir, tile.parent:getParent(), new_entered)]]
          return tile.parent.exit.x + dx, tile.parent.exit.y + dy, tile.parent:getParent()
        else
          return tile.parent:getParadoxEntry(tile)
        end
      end
    end
  end
  return x, y, room
end

return Movement