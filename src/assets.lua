local Assets = {}
Assets.sprites = {}
Assets.palettes = {}
Assets.sounds = {}

function Assets.load()
  Assets.addSprites()
  Assets.addPalettes()
  Assets.addSounds()
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
      palette.getColor = function(self, x, y)
        return unpack(self[x][y])
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

function Assets.addSounds(d)
  local dir = "assets/sounds"
  if d then
    dir = dir .. "/" .. d
  end
  local files = love.filesystem.getDirectoryItems(dir)
  for _,file in ipairs(files) do
    if string.sub(file, -4) == ".wav" or string.sub(file, -4) == ".ogg" then
      local soundname = string.sub(file, 1, -5)
      if d then
        soundname = d .. "/" .. soundname
      end
      Assets.sounds[soundname] = love.audio.newSource(dir .. "/" .. file, "static")
    elseif love.filesystem.getInfo(dir .. "/" .. file).type == "directory" then
      local newdir = file
      if d then
        newdir = d .. "/" .. newdir
      end
      Assets.addSounds(newdir)
    end
  end
end

function Assets.playSound(sound, vol)
  local instance = Assets.sounds[sound]:play()
  instance:setVolume(vol or 1)
  return instance
end

function Assets.addTiles()
  Assets.tiles_list = {
    {
      name = "rule",
      sprites = {"rule"},
      colors = {{0, 3}},
      layer = 5,
      unselectable = true,
    },
    {
      name = "wall",
      sprites = {"rect"},
      colors = {{8, 0}},
      layer = 1,
      property = "stop",
    },
    {
      name = "flof",
      sprites = {"flof_body", "flof_eyes"},
      colors = {{1, 3}, {1, 1}},
      layer = 4,
      walk = true,
      rotate = true,
      property = "play",
    },
    {
      name = "box",
      sprites = {"box_base", "box_shade"},
      colors = {{3, 2}, {3, 1}},
      layer = 3,
      property = "push",
    },
    {
      name = "crate",
      sprites = {"crate", "crate_shade"},
      colors = {{0, 2}, {0, 1}},
      layer = 3,
      property = "heavy",
    },
    {
      name = "ladder",
      sprites = {"ladder"},
      colors = {{3, 2}},
      layer = 2,
      property = "exit",
    },
    {
      name = "belt",
      sprites = {"belt"},
      colors = {{8, 3}},
      layer = 2,
      rotate = true,
      property = "move",
    },
    {
      name = "water",
      sprites = {"water_shade", "water"},
      colors = {{7, 3}, {7, 4}},
      layer = 1,
      property = "sink",
    },
    {
      name = "lava",
      sprites = {"water_shade", "water"},
      colors = {{3, 2}, {3, 3}},
      layer = 1,
      property = "burn",
    },
    {
      name = "spike",
      sprites = {"spike"},
      colors = {{8, 3}},
      layer = 2,
      property = "hurt",
    },
    {
      name = "flag",
      sprites = {"flag"},
      colors = {{2, 3}},
      layer = 2,
      property = "save",
    },
    {
      name = "fork",
      sprites = {"fork"},
      colors = {{8, 0}},
      layer = 4,
      rotate = true,
      property = "hold",
    },
    {
      name = "ring",
      sprites = {"ring"},
      colors = {{8, 0}},
      layer = 2,
      property = "tele",
    },
    {
      name = "key",
      sprites = {"key"},
      colors = {{3, 3}},
      layer = 3,
      rotate = true,
      property = "open"
    },
    {
      name = "lock",
      sprites = {"door"},
      colors = {{2, 2}},
      layer = 8,
      property = "shut"
    },
    {
      name = "brick",
      sprites = {"brick"},
      colors = {{8, 0}},
      layer = 8,
      property = "stop",
    },
    {
      name = "arrow",
      sprites = {"arrow"},
      colors = {{4, 3}},
      layer = 3,
      rotate = true,
    },
    {
      name = "object",
      sprites = {"perfectly_generic_object_front", "perfectly_generic_object_side", "perfectly_generic_object_top"},
      colors = {{6, 3}, {6, 2}, {6, 4}},
      layer = 3
    },
    {
      name = "room",
      sprites = {"rect"},
      colors = {{8, 0}},
      layer = 3,
    },
    {
      name = "line",
      sprites = {"line"},
      colors = {{8, 3}},
      layer = 2,
    },
    {
      name = "tile",
      sprites = {"tile"},
      colors = {{8, 3}},
      layer = 1,
    },
  }

  Assets.tiles = {}
  for _,tile in ipairs(Assets.tiles_list) do
    Assets.tiles[tile.name] = tile
  end
end

function Assets.addWords()
  Assets.words_list = {
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
      name = "crate",
      type = "noun",
      color = 4,
      dark = true,
    },
    {
      name = "heavy",
      type = "prop",
      color = 0,
      dark = true,
    },
    {
      name = "ladder",
      type = "noun",
      color = 3,
      dark = true,
    },
    {
      name = "exit",
      type = "prop",
      color = 5,
      dark = true,
    },
    {
      name = "belt",
      type = "noun",
      color = 7,
    },
    {
      name = "move",
      type = "prop",
      color = 4,
    },
    {
      name = "water",
      type = "noun",
      color = 7,
    },
    {
      name = "sink",
      type = "prop",
      color = 7,
      dark = true,
    },
    {
      name = "lava",
      type = "noun",
      color = 3,
    },
    {
      name = "burn",
      type = "prop",
      color = 3,
      dark = true,
    },
    {
      name = "spike",
      type = "noun",
      color = 0,
      dark = true,
    },
    {
      name = "hurt",
      type = "prop",
      color = 1,
      dark = true,
    },
    {
      name = "flag",
      type = "noun",
      color = 2,
    },
    {
      name = "save",
      type = "prop",
      color = 5,
    },
    {
      name = "fork",
      type = "noun",
      color = 0,
      dark = true
    },
    {
      name = "hold",
      type = "prop",
      color = 6,
      dark = true
    },
    {
      name = "ring",
      type = "noun",
      color = 2
    },
    {
      name = "tele",
      type = "prop",
      color = 7
    },
    {
      name = "key",
      type = "noun",
      color = 3
    },
    {
      name = "open",
      type = "prop",
      color = 5
    },
    {
      name = "lock",
      type = "noun",
      color = 2,
      dark = true
    },
    {
      name = "shut",
      type = "prop",
      color = 1,
    },
    {
      name = "brick",
      type = "noun",
      color = 0,
      dark = true,
    },
    {
      name = "arrow",
      type = "noun",
      color = 6,
      dark = true,
    },
    {
      name = "object",
      type = "noun",
      color = 6,
      dark = true,
    },
    {
      name = "rule",
      type = "noun",
      color = 2,
    },
    {
      name = "tile",
      type = "noun",
      color = 0,
      dark = true,
    },
    {
      name = "room",
      type = "noun",
      color = 1,
    },
    {
      name = "line",
      type = "noun",
      color = 6,
      dark = true,
    },
    {
      name = "flat",
      type = "prop",
      color = 2,
      dark = true,
    },
    {
      name = "not",
      type = "mod",
      color = 3,
    },
    {
      name = "plus",
      type = "mod",
      color = 0,
      dark = true,
    }
  }

  Assets.words = {}
  for _,word in ipairs(Assets.words_list) do
    Assets.words[word.name] = word
  end
end

return Assets