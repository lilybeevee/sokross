local Movement = {}

function Movement.move(dir)
  Movement.moved_word = false

  local moves = {}

  for _,playrule in ipairs(Game.room:getRules(nil, "play")) do
    for _,tile in ipairs(Game.room:getTilesByName(playrule.target)) do
      table.insert(moves, {tile = tile, dir = dir})
    end
  end

  local move_done = false
  while #moves > 0 and not move_done do
    move_done = true

    local still_moving = {}
    local movers = {}
    for _,move in ipairs(moves) do
      local success, new_movers = Movement.canMove(move.tile, move.dir)
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
      mover.tile:moveTo(mover.x, mover.y, mover.room)
      mover.tile.dir = mover.dir
    end

    moves = still_moving
  end
end

function Movement.canMove(tile, dir, enter)
  local x, y, room
  if not enter then
    local dx, dy = Dir.toPos(dir)
    x, y = tile.x + dx, tile.y + dy
    room = tile.parent
  else
    x, y, room = Movement.getNextTile(tile, dir)
  end

  local current_mover = {tile = tile, x = x, y = y, dir = dir, room = room}
  local movers = {current_mover}

  if not room:inBounds(x, y) and room:hasRule("wall", "stop") then
    return false, {}
  end

  for _,other in ipairs(room:getTilesAt(x, y)) do
    local success, pushable, moveable = false, false, true
    if other:hasRule("push") then
      pushable = true

      local new_movers
      success, new_movers = Movement.canMove(other, dir)
      if success then
        Utils.merge(movers, new_movers)
      end
    elseif other:hasRule("stop") then
      moveable = false
      success = false
    else
      success = true
    end

    local is_entry = tile.room or tile:hasRule("exit")
    local can_enter = other.room or other:hasRule("exit")

    if can_enter and not (success and pushable) then
      local new_movers
      success, new_movers = Movement.canMove(tile, dir, true)
      if success then
        current_mover = table.remove(new_movers, 1)
        Utils.merge(movers, new_movers)
        entered = true
      end
    end
    if is_entry and not success and moveable then
      local new_movers
      success, new_movers = Movement.canMove(other, Dir.reverse(dir), true)
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
    if tile.room then
      local ex, ey = tile.room:getEntry()
      return ex, ey, tile.room
    elseif tile.parent.parent and tile:hasRule("exit") then
      return tile.parent.x + dx, tile.parent.y + dy, tile.parent.parent
    end
  end
  return x, y, tile.parent
end

return Movement