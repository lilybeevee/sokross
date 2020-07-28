local Tile = Class{}

function Tile:init(name, x, y, o)
  o = o or {}

  if o.id then
    self.id = o.id
  elseif Gamestate.current() == Game then
    self.id = Game.tile_id
    Game.tile_id = Game.tile_id + 1
    Game.tiles_by_id[self.id] = self
  else
    self.id = 0
  end

  self.parent = nil
  self.name = name
  self.x = x
  self.y = y
  self.tile = Assets.tiles[name]
  self.layer = self.tile.layer

  self.dir = o.dir or 1
  self.room = o.room
  
  if o.word then
    self.wordname = o.word
    self.word = Assets.words[o.word]

    local side_type = "none"
    if self.word.type == "noun" then
      side_type = "in"
      self.layer = 7
    elseif self.word.type == "prop" then
      side_type = "out"
      self.layer = 6
    elseif self.word.type == "mod" then
      side_type = "all"
      self.layer = 5
    end

    o.sides = o.sides or {true, true, true, true}

    self.sides = {}
    for i = 1, 4 do
      self.sides[i] = o.sides[i] and side_type or "none"
    end
  end
  
  self.active = false
  self.active_sides = {false, false, false, false}
end

function Tile:remove()
  if Gamestate.current() == Game then
    Game.tiles_by_id[self.id] = nil
  end
end

function Tile:hasRule(effect)
  return self.parent:hasRule(self.name, effect)
end

function Tile:moveTo(x, y, room)
  if room then
    if self:hasRule("play") then
      room:enter()
    end

    self.parent:removeTile(self)
    self.x, self.y = x, y
    room:addTile(self)
  else
    Utils.removeFromTable(self.parent.tiles_by_pos[self.x..","..self.y], self)
    self.x, self.y = x, y
    table.insert(self.parent.tiles_by_pos[self.x..","..self.y], self)
  end

  if self.room then
    self.room.parent = self.parent
    self.room.layer = self.parent.layer + 1
    self.room.x = self.x
    self.room.y = self.y
  end
end

function Tile:getColor()
  if self.word then
    return self.word.color, self.word.dark and 2 or 3
  else
    return unpack(self.tile.colors[1])
  end
end

function Tile:getConnections(type)
  local inputs = {}
  if self.word then
    for dir = 1, 4 do
      local othertype = "all"
      if type == "in" then
        othertype = "out"
      elseif type == "out" then
        othertype = "in"
      end
      if self.sides[dir] ~= "none" and (type == "all" or self.sides[dir] == "all" or self.sides[dir] == type) then
        local dx, dy = Dir.toPos(dir)
        local rdir = Dir.reverse(dir)
        for _,tile in ipairs(self.parent:getTilesAt(self.x+dx, self.y+dy)) do
          if tile.word and tile.sides[rdir] ~= "none" and (type == "all" or tile.sides[rdir] == "all" or tile.sides[rdir] == othertype) then
            table.insert(inputs, tile)
          end
        end
      end
    end
  end
  return inputs
end

function Tile:draw(palette)
  love.graphics.push()
  love.graphics.translate(TILE_SIZE/2, TILE_SIZE/2)

  if self.tile.rotate then
    love.graphics.rotate(math.rad((self.dir-1) * 90))
  end

  if self.name == "room" and self.room then
    local ipalette = Assets.palettes[self.room.palette]
    ipalette:setColor(0, 1)
    love.graphics.rectangle("fill", -TILE_SIZE/2, -TILE_SIZE/2, TILE_SIZE, TILE_SIZE)

    love.graphics.push()
    love.graphics.translate(-self.room.width, -self.room.height)
    ipalette:setColor(0, 4)
    love.graphics.rectangle("fill", 0, 0, self.room.width*2, self.room.height*2)
    for x = 0, self.room.width-1 do
      for y = 0, self.room.height-1 do
        local color
        if self.room.tiles_by_pos[x..","..y] and #self.room.tiles_by_pos[x..","..y] > 0 then
          color = {self.room.tiles_by_pos[x..","..y][1]:getColor()}
        end
        if color then
          ipalette:setColor(color[1], color[2])
          love.graphics.rectangle("fill", x*2, y*2, 2, 2)
        end
      end
    end
    love.graphics.pop()

    palette:setColor(0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -TILE_SIZE/2, -TILE_SIZE/2, TILE_SIZE, TILE_SIZE)
  elseif self.name == "rule" and self.word then
    local rule_base = Assets.sprites["tiles/rule"]
    local word_sprite = Assets.sprites["words/"..self.word.name]
    palette:setColor(self.word.color, self.word.dark and 2 or 3)
    love.graphics.draw(rule_base, -rule_base:getWidth()/2, -rule_base:getHeight()/2)
    --[[if self.active then
      palette:setColor(self.word.color, self.word.dark and 3 or 4)
    else
      palette:setColor(self.word.color, self.word.dark and 0 or 1)
    end]]
    palette:setColor(self.word.color, self.word.dark and 0 or 1)
    love.graphics.draw(word_sprite, -word_sprite:getWidth()/2, -word_sprite:getHeight()/2)

    for i = 1, 4 do
      local rule_side
      if self.sides[i] == "out" or (self.sides[i] == "all" and self.active_sides[i]) then
        palette:setColor(self.word.color, self.word.dark and 2 or 3)
        rule_side = Assets.sprites["tiles/rule_connector"]
      elseif self.sides[i] == "all" then
        palette:setColor(self.word.color, self.word.dark and 1 or 2)
        rule_side = Assets.sprites["tiles/rule_connector"]
      elseif self.sides[i] == "none" then
        palette:setColor(self.word.color, self.word.dark and 2 or 3)
        rule_side = Assets.sprites["tiles/rule_side"]
      end

      if rule_side then
        love.graphics.draw(rule_side, rule_base:getWidth()/2 - rule_side:getWidth()/2, -rule_side:getHeight()/2)
      end
      love.graphics.rotate(math.rad(90))
    end
  else
    local sprites = self.tile.sprites
    local colors = self.tile.colors

    for i,spritename in ipairs(sprites) do
      palette:setColor(colors[i][1], colors[i][2])

      local sprite = Assets.sprites["tiles/"..spritename]
      love.graphics.draw(sprite, -sprite:getWidth()/2, -sprite:getHeight()/2)
    end
  end

  love.graphics.pop()
end

return Tile