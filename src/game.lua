local Game = {}

function Game:enter()
  print("Sokoma game")

  Undo:clear()

  self.turn = 0
  self.sound = {}
  self.parse_room = {}

  Level.static = false
  Level:reset()
  
  Level.room:parse()
  Level.room:updateLines()
  Level.room:updateTiles()
  self.sound = {}

  --print(dump(Level.room.rules.rules))
end

function Game:keypressed(key)
  if key == "d" then
    self:doTurn(1)
  elseif key == "s" then
    self:doTurn(2)
  elseif key == "a" then
    self:doTurn(3)
  elseif key == "w" then
    self:doTurn(4)
  elseif key == "z" then
    Undo:back()
    self:reparse()
  elseif key == "r" then
    Level:reset()
    Level.room:updateLines()
    Level.room:updateTiles()
  elseif key == "return" then
    Gamestate.switch(Editor)
  elseif key == "`" then -- debug
    self:doTurn()
    for _,tile in ipairs(Level.room:getTilesByName("flof")) do
      tile:goToParadox()
    end
  end
end

function Game:doTurn(dir)
  self.update_room = {}
  Undo:new()
  self.turn = self.turn + 1
  Movement.move(dir)
  self:reparse()
  self:doTransitions()
  self:checkWin()
  Level.room:updateLines()
  Level.room:updateTiles()
  self:playSounds()
end

function Game:playSounds()
  if self.sound["enter"] then
    Assets.playSound("enter")
  elseif self.sound["exit"] then
    Assets.playSound("exit")
  elseif self.sound["push"] then
    if self.sound["click"] or self.sound["unclick"] then
      Assets.playSound("push", 0.75)
    else
      Assets.playSound("push")
    end
  end
  if self.sound["click"] then
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
                if not moved_tile[tile][other] then
                  other:moveTo(tile.parent.exit.x, tile.parent.exit.y, tile.parent:getParent())
                  moved_tile[tile][other] = true
                else
                  other:goToParadox()
                end
                transitions_done = false
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
              if not moved_tile[tile][other] then
                if not tile.room then
                  tile.room = Level:getRoom(tile.room_key)
                  tile.room.exit = tile
                  tile.room:parse()
                end
                local ex, ey = tile.room:getEntry()
                other:moveTo(ex, ey, tile.room)
                moved_tile[tile][other] = true
              else
                other:goToParadox()
              end
              transitions_done = false
            end
          end
        end
      end
    end
  end
end

function Game:checkWin()
  if #Level.room:getTilesByName("tile") == 0 then return end
  for _,tile in ipairs(Level.room:getTilesByName("tile")) do
    if not tile:getActivated() then return end
  end
  Level.room:win()
end

function Game:getTransform()
  local transform = love.math.newTransform()
  transform:translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  transform:scale(2, 2)
  transform:translate(-Level.room.width*TILE_SIZE/2, -Level.room.height*TILE_SIZE/2)
  return transform
end

function Game:draw()
  Assets.palettes[Level.room.palette]:setColor(8, 0)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.applyTransform(self:getTransform())

  Level.room:draw()
end

return Game