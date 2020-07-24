local Tile = Class{}

function Tile:init(name, x, y, o)
  o = o or {}

  self.name = name
  self.x = x
  self.y = y

  self.dir = o.dir or 1
  if o.word then
    self.wordname = o.word
    self.word = Assets.words[o.word]
  end

  self.tile = Assets.tiles[name]
  self.active = false
end

function Tile:draw(palette)
  local sprites = self.tile.sprites
  local colors = self.tile.colors

  if self.name == "rule" and self.word then
    local text_color = {self.word.color, 0}
    if self.active then
      text_color = {self.word.color, 3}
    end

    if self.word.type == "prop" then
      sprites = {"rule", "rule_connectors", "words/"..self.word.name}
      colors = {{self.word.color, 2}, {self.word.color, 2}, text_color}
    elseif self.word.type == "mod" then
      sprites = {"rule", "rule_connectors", "words/"..self.word.name}
      colors = {{self.word.color, 2}, {self.word.color, 1}, text_color}
    elseif self.word.type == "noun" then
      sprites = {"rule", "words/"..self.word.name}
      colors = {{self.word.color, 2}, text_color}
    end
  end

  for i,spritename in ipairs(sprites) do
    palette:setColor(colors[i][1], colors[i][2])

    local sprite = Assets.sprites["tiles/"..spritename]
    love.graphics.draw(sprite, TILE_SIZE/2 - sprite:getWidth()/2, TILE_SIZE/2 - sprite:getHeight()/2)
  end
end

return Tile