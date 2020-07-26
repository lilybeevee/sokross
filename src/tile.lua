local Tile = Class{}

function Tile:init(name, x, y, o)
  o = o or {}

  self.name = name
  self.x = x
  self.y = y
  self.tile = Assets.tiles[name]
  self.layer = self.tile.layer
  self.dir = o.dir or 1
  
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

    self.sides = o.sides or {}
    for i = 1, 4 do
      self.sides[i] = self.sides[i] or side_type
    end
  end
  
  Level.tiles_by_layer[self.layer][self] = true
  
  self.active = false
end

function Tile:draw(palette)
  love.graphics.push()
  love.graphics.translate(TILE_SIZE/2, TILE_SIZE/2)

  if self.tile.rotate then
    love.graphics.rotate(math.rad(self.dir-1 * -90))
  end

  if self.name == "rule" and self.word then
    local rule_base = Assets.sprites["tiles/rule"]
    local word_sprite = Assets.sprites["words/"..self.word.name]
    palette:setColor(self.word.color, self.word.dark and 2 or 3)
    love.graphics.draw(rule_base, -rule_base:getWidth()/2, -rule_base:getHeight()/2)
    palette:setColor(self.word.color, self.word.dark and 0 or 1)
    love.graphics.draw(word_sprite, -word_sprite:getWidth()/2, -word_sprite:getHeight()/2)

    for i = 1, 4 do
      local rule_side
      if self.sides[i] == "out" then
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