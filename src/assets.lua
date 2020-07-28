local Assets = {}
Assets.sprites = {}
Assets.palettes = {}

function Assets.load()
  Assets.addSprites()
  Assets.addPalettes()
  Assets.addTiles()
  Assets.addWords()
end

function Assets.addSprites(d)
  local dir = "assets/graphics"
  if d then
    dir = dir .. "/" .. d
  end
  local files = love.filesystem.getDirectoryItems(dir)
  for _,file in ipairs(files) do
    if string.sub(file, -4) == ".png" then
      local spritename = string.sub(file, 1, -5)
      local sprite = love.graphics.newImage(dir .. "/" .. file)
      if d then
        spritename = d .. "/" .. spritename
      end
      Assets.sprites[spritename] = sprite
    elseif love.filesystem.getInfo(dir .. "/" .. file).type == "directory" then
      local newdir = file
      if d then
        newdir = d .. "/" .. newdir
      end
      Assets.addSprites(newdir)
    end
  end
end

function Assets.addPalettes(d)
  local dir = "assets/palettes"
  if d then
    dir = dir .. "/" .. d
  end
  local files = love.filesystem.getDirectoryItems(dir)
  for _,file in ipairs(files) do
    if string.sub(file, -4) == ".png" then
      local palettename = string.sub(file, 1, -5)
      local palettedata = love.image.newImageData(dir .. "/" .. file)
      if d then
        palettename = d .. "/" .. palettename
      end
      local palette = {}
      for x = 0, palettedata:getWidth()-1 do
        palette[x] = {}
        for y = 0, palettedata:getHeight()-1 do
          palette[x][y] = {palettedata:getPixel(x, y)}
        end
      end
      palette.setColor = function(self, x, y)
        love.graphics.setColor(unpack(self[x][y]))
      end
      Assets.palettes[palettename] = palette
    elseif love.filesystem.getInfo(dir .. "/" .. file).type == "directory" then
      local newdir = file
      if d then
        newdir = d .. "/" .. newdir
      end
      Assets.addPalettes(newdir)
    end
  end
end

function Assets.addTiles()
  local tiles = {
    {
      name = "rule",
      sprites = {"rule"},
      colors = {{0, 3}},
      layer = 5,
    },
    {
      name = "room",
      sprites = {"rect"},
      colors = {{4, 2}},
      layer = 1,
    },
    {
      name = "wall",
      sprites = {"rect"},
      colors = {{0, 1}},
      layer = 1,
    },
    {
      name = "flof",
      sprites = {"flof_body", "flof_eyes"},
      colors = {{1, 3}, {1, 1}},
      layer = 4,
      walk = true,
      rotate = true,
    },
    {
      name = "box",
      sprites = {"box_base", "box_shade"},
      colors = {{3, 2}, {3, 1}},
      layer = 3,
    },
    {
      name = "ladder",
      sprites = {"ladder"},
      colors = {{3, 2}},
      layer = 2,
    },
  }

  Assets.tiles = {}
  for _,tile in ipairs(tiles) do
    Assets.tiles[tile.name] = tile
  end
end

function Assets.addWords()
  local words = {
    {
      name = "flof",
      type = "noun",
      color = 1,
    },
    {
      name = "play",
      type = "prop",
      color = 2,
    },
    {
      name = "wall",
      type = "noun",
      color = 0,
      dark = true,
    },
    {
      name = "stop",
      type = "prop",
      color = 4,
    },
    {
      name = "box",
      type = "noun",
      color = 3,
      dark = true,
    },
    {
      name = "push",
      type = "prop",
      color = 5,
    },
    {
      name = "not",
      type = "mod",
      color = 3,
    },
    {
      name = "plus",
      type = "mod",
      color = 3,
    }
  }

  Assets.words = {}
  for _,word in ipairs(words) do
    Assets.words[word.name] = word
  end
end

return Assets