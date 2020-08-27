local Game = {}

Game.sound = {}

function Game:enter()
  print("Sokoma game")

  Undo:clear()

  self.turn = 0
  self.parse_room = {}

  World.static = false
  World:reset()
  
  World.room:parse()

  self.sound = {}
  self.move_key_buffer = {}
  self.move_timer = 0
  self.undoing = false
  self.undo_timer = 0
  self.undo_timer_mult = 1
  self.update_room = {}

  World.room:updateLines()
  World.room:updateVisuals()
  World.room:updateTiles(true)
  self.sound = {}

  --print(dump(World.room.rules.rules))
end

function Game:keypressed(key)
  for mkey,_ in pairs(MOVE_KEYS) do
    if key == mkey then
      table.insert(self.move_key_buffer, key)
      self.move_timer = 0
    end
  end
  if key == "z" then
    self.undoing = true
  elseif key == "r" then
    World:reset()
    World.room:updateLines()
    World.room:updateVisuals()
  elseif key == "return" then
    Gamestate.switch(Editor)
  elseif key == "`" then -- debug
    self:doTurn()
    for _,tile in ipairs(World.room:getTilesByName("flof")) do
      tile:goToParadox()
    end
  end
end

function Game:keyreleased(key)
  for mkey,_ in pairs(MOVE_KEYS) do
    if key == mkey then
      Utils.removeFromTable(self.move_key_buffer, key)
    end
  end
  if key == "z" then
    self.undoing = false
  end
end

function Game:update(dt)
  if self.undoing then
    self.undo_timer = math.max(0, self.undo_timer - dt)
    if self.undo_timer == 0 then
      self.undo_timer = KEY_REPEAT / self.undo_timer_mult
      self.undo_timer_mult = math.min(3, self.undo_timer_mult + 0.1)
      Undo:back()
      self:reparse()
      World.room:updateTiles(true)
    end
  else
    self.undo_timer = 0
    self.undo_timer_mult = 1
    if #self.move_key_buffer > 0 then
      self.move_timer = math.max(0, self.move_timer - dt)
      if self.move_timer == 0 then 
        self.move_timer = KEY_REPEAT
        local dir = MOVE_KEYS[self.move_key_buffer[#self.move_key_buffer]]
        self:doTurn(dir)
      end
    else
      self.move_timer = 0
    end
  end
end

function Game:doTurn(dir)
  self.update_room = {}
  Undo.enabled = true
  Undo:new()
  self.turn = self.turn + 1
  World.room:updateTiles()
  Movement.turn(dir)
  self:reparse()
  self:doTransitions()
  self:updateTiles()
  self:checkWin()
  --World.room:updateTiles()
  World.room:updateLines()
  World.room:updateVisuals()
  self:playSounds()
  Undo.enabled = false
end

function Game:handleDels(to_destroy)
  for _,tile in ipairs(to_destroy) do
    if tile.parent then
      Undo:add("remove", tile:save(true), tile.parent.id)
      tile.parent:removeTile(tile)
    end
  end
end

function Game:playSounds()
  if self.sound["paradox"] then
    Assets.playSound("paradox")
  elseif self.sound["enter"] then
    Assets.playSound("enter")
  elseif self.sound["exit"] then
    Assets.playSound("exit")
  elseif self.sound["push"] then
    if self.sound["paradox push"] then
      Assets.playSound("paradox push")
    elseif self.sound["click"] or self.sound["unclick"] then
      Assets.playSound("push", 0.75)
    else
      Assets.playSound("push")
    end
  end
  if self.sound["unlock"] then
    Assets.playSound("unlock", 0.4)
    Assets.playSound("click", 0.6)
  elseif self.sound["sink"] then
    Assets.playSound("sink", 0.5)
  elseif self.sound["burn"] then
    Assets.playSound("burn", 0.6)
  elseif self.sound["click"] then
    Assets.playSound("click", 0.75)
  elseif self.sound["unclick"] then
    Assets.playSound("unclick", 0.75)
  end
  self.sound = {}
end

function Game:reparse()
  local parse_list = {}
  for room,_ in pairs(self.parse_room) do
    table.insert(parse_list, room)
  end
  table.sort(parse_list, function(a, b)
    return a:getLayer() < b:getLayer()
  end)
  for _,room in ipairs(parse_list) do
    room:parse()
    for _,lower in ipairs(room.tiles_by_name["room"] or {}) do
      if lower.room and not parse_list[lower.room] then
        lower.room:parse()
      end
    end
  end
  self.parse_room = {}
end

function Game:doTransitions()
  local transitions_done = false
  local moved_tile = {}
  local moved_persist = {}

  local full_update_room = Utils.copy(self.update_room)

  while not transitions_done do
    local rooms = self.update_room
    self.update_room = {}

    transitions_done = true

    for room,_ in pairs(rooms) do
      for _,exitrule in ipairs(room:getRules(nil, "exit")) do
        for _,tile in ipairs(room:getTilesByName(exitrule.target)) do
          if tile.parent.exit then
            for _,other in ipairs(room:getTilesAt(tile.x, tile.y)) do
              if other ~= tile and not other:hasRule("flat") then
                moved_tile[tile] = moved_tile[tile] or {}
                moved_persist[tile] = moved_persist[tile] or {}
                if not moved_tile[tile][other] and (not other.persist or not moved_persist[tile][other.key]) then
                  other:moveTo(tile.parent.exit.x, tile.parent.exit.y, tile.parent:getParent())
                  moved_tile[tile][other] = true
                  if other.persist then
                    moved_persist[tile][other.key] = true
                  end
                else
                  other:goToParadox()
                end
                transitions_done = false
                local to_destroy, moves = other:update()
                Game:handleDels(to_destroy)
                Movement.move(moves)
              end
            end
          end
        end
      end

      for _,tile in ipairs(room:getTilesByName("room")) do
        if tile.room_key then
          for _,other in ipairs(room:getTilesAt(tile.x, tile.y)) do
            if other ~= tile and not other:hasRule("flat") then
              moved_tile[tile] = moved_tile[tile] or {}
              moved_persist[tile] = moved_persist[tile] or {}
              if not moved_tile[tile][other] and (not other.persist or not moved_persist[tile][other.key]) then
                if not tile.room then
                  tile.room = World:getRoom(tile.room_key)
                  tile.room.exit = tile
                  Undo:add("create_room", tile.room.id, tile.id)
                  tile.room:parse()
                end
                local ex, ey = tile.room:getEntry()
                other:moveTo(ex, ey, tile.room)
                moved_tile[tile][other] = true
                if other.persist then
                  moved_persist[tile][other.key] = true
                end
              else
                other:goToParadox()
              end
              transitions_done = false
              local to_destroy, moves = other:update()
              Game:handleDels(to_destroy)
              Movement.move(moves)
            end
          end
        end
      end
    end

    for room,_ in pairs(self.update_room) do
      full_update_room[room] = true
    end
  end

  self.update_room = full_update_room
end

function Game:updateTiles()
  for room,_ in pairs(self.update_room) do
    room:updateTiles()
  end
end

function Game:checkWin()
  if #World.room:getTilesByName("tile") == 0 then return false end
  for _,tile in ipairs(World.room:getTilesByName("tile")) do
    if not tile:getActivated() then return false end
  end
  World.room:win()
  return true
end

function Game:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-World.room.width*TILE_SIZE/2, -World.room.height*TILE_SIZE/2)
  return transform
end

function Game:draw()
  Assets.palettes[World.room.palette]:setColor(8, 0)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  World.room:draw()
end

return Game