local Utils = {}

--extend isDown to allow checking for both kinds of a key at once
love.keyboard.orig_isDown = love.keyboard.isDown
function love.keyboard.isDown(key)
  if key == "ctrl" then
    return love.keyboard.orig_isDown("lctrl") or love.keyboard.orig_isDown("rctrl")
  elseif key == "shift" then
    return love.keyboard.orig_isDown("lshift") or love.keyboard.orig_isDown("rshift")
  elseif key == "alt" then
    return love.keyboard.orig_isDown("lalt") or love.keyboard.orig_isDown("ralt")
  else
    return love.keyboard.orig_isDown(key)
  end
end

function string:split(sep)
  if sep == nil then
    sep = "%s"
  end
  local t={}
  for str in string.gmatch(self, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

function string:trim()
  return (self:gsub("^%s*(.-)%s*$", "%1"))
end

function string:startsWith(start)
  return self:sub(1, start:len()) == start
end

function string:endsWith(ending)
  return ending == "" or self:sub(-#ending) == ending
end

function dump(o)
  if type(o) == 'table' then
    if o.__index == Tile then
      return "("..o.name..":"..o.id..","..o.x..","..o.y..")"
    else
      local s = '{'
      local cn = 1
      if #o ~= 0 then
        for _,v in ipairs(o) do
          if cn > 1 then s = s .. ',' end
          s = s .. dump(v)
          cn = cn + 1
        end
      else
        for k,v in pairs(o) do
          if cn > 1 then s = s .. ',' end
          s = s .. dump(k) .. ' = ' .. dump(v)
          cn = cn + 1
        end
      end
      return s .. '}'
    end
  elseif type(o) == 'string' then
    return '"' .. o .. '"'
  else
    return tostring(o)
  end
end

function Utils.encodeNum(n)
  n = math.floor(n)
  local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  local t = {}
  local sign = ""
  if n < 0 then
      sign = "-"
  n = -n
  end
  repeat
      local d = (n % #digits) + 1
      n = math.floor(n / #digits)
      table.insert(t, 1, digits:sub(d,d))
  until n == 0
  return sign .. table.concat(t,"")
end

function Utils.isEmpty(v)
  if type(v) == "nil" then
    return true
  elseif type(v) == "string" then
    return v == ""
  elseif type(v) == "table" then
    return #v == 0
  end
  return false
end

function Utils.copy(obj, deep)
  if type(obj) == "table" then
    local ret = {}
    for k,v in pairs(obj) do
      if deep then
        ret[k] = Utils.copy(v, true)
      else
        ret[k] = v
      end
    end
    return ret
  else
    return obj
  end
end

function Utils.merge(t1, t2)
  for _,v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end

function Utils.removeFromTable(t, value)
  for i,v in ipairs(t) do
    if v == value then
      table.remove(t, i)
      return
    end
  end
end

function Utils.contains(t, value)
  for k,v in pairs(t) do
    if v == value then
      return true
    end
  end
  return false
end

function Utils.saveTable(t)
  --this table contains all the lua values that are reasonable to be saved to a file.
  
  --possible lua types:  nil, boolean, number, string, userdata, function, thread, and table
  
  --userdata, function, and thread are unable to be written to and loaded from a file, so the
  --save code errors if you try to save any of them.
  
  --nil, number, boolean, and string and each be written to a single value, and
  --table can be written by calling the saveTable function recursively.
  
  local valid_type = {
    ["nil"] = true,
    ["number"] = true,
    ["boolean"] = true,
    ["string"] = true,
    ["table"] = true,
  }

  local length = 0
  for k,v in pairs(t) do
    if not valid_type[type(k)] then error("Cannot save type: "..type(k)) end
    if not valid_type[type(v)] then error("Cannot save type: "..type(v)) end
    length = length + 1
  end
  local dictionary = #t ~= length

  local data = love.data.pack("string", "BH", dictionary and 1 or 0, length)

  local function saveVar(v)
    if type(v) == "number" then
      -- type 1
      data = data..love.data.pack("string", "Bn", 1, v)
    elseif type(v) == "string" then
      -- type 2
      data = data..love.data.pack("string", "Bz", 2, v)
    elseif type(v) == "boolean" then
      -- type 3
      data = data..love.data.pack("string", "BB", 3, v and 1 or 0)
    elseif type(v) == "table" then
      -- type 4
      data = data..love.data.pack("string", "B", 4) .. Utils.saveTable(v)
    else
      -- type 0 (nil)
      data = data..love.data.pack("string", "B", 0)
    end
  end

  if not dictionary then
    for _,v in ipairs(t) do
      saveVar(v)
    end
  else
    for k,v in pairs(t) do
      saveVar(k)
      saveVar(v)
    end
  end

  return data
end

function Utils.loadTable(data, pos)
  local dict_byte, length, pos = love.data.unpack("BH", data, pos or 1)
  local dictionary = dict_byte == 1

  local t = {}

  local function loadVar()
    local type, var
    type, pos = love.data.unpack("B", data, pos)

    if type == 1 then
      -- number
      var, pos = love.data.unpack("n", data, pos)
    elseif type == 2 then
      -- string
      var, pos = love.data.unpack("z", data, pos)
    elseif type == 3 then
      -- boolean
      local byte_var
      byte_var, pos = love.data.unpack("B", data, pos)
      var = byte_var > 0
    elseif type == 4 then
       -- table
      var, pos = Utils.loadTable(data, pos)
    else
      -- nil
      var = nil
    end

    return var
  end

  for i = 1, length do
    if not dictionary then
      table.insert(t, loadVar())
    else
      local key = loadVar()
      t[key] = loadVar()
    end
  end

  return t, pos
end

function Utils.removeDirectory(dir)
  if love.filesystem.getInfo(dir, "directory") then
    for _,file in ipairs(love.filesystem.getDirectoryItems(dir)) do
      local info = love.filesystem.getInfo(dir.."/"..file)
      if info.type == "file" then
        love.filesystem.remove(dir.."/"..file)
      else
        Utils.removeDirectory(dir.."/"..file)
      end
    end
    love.filesystem.remove(dir)
    return true
  end
  return false
end

function Utils.copyDirectory(dir, target, force)
  if love.filesystem.getInfo(dir, "directory") and (force or not love.filesystem.getInfo(target, "directory")) then
    for _,file in ipairs(love.filesystem.getDirectoryItems(dir)) do
      local info = love.filesystem.getInfo(dir.."/"..file)
      if info.type == "file" then
        love.filesystem.write(target.."/"..file, love.filesystem.read(dir.."/"..file))
      else
        Utils.copy(dir.."/"..file, target.."/"..file)
      end
    end
    return true
  end
  return false
end

function Utils.moveDirectory(dir, target)
  if Utils.copyDirectory(dir, target) then
    Utils.removeDirectory(dir)
    return true
  end
  return false
end

function Utils.toFileName(str)
  str = str:trim()
  str = str:gsub("[%p%c]", "")
  str = str:lower()
  return str
end

function Utils.createUUID()
  local full_time = os.time()
  local micro_time = love.timer.getTime()
  micro_time = math.floor((micro_time - math.floor(micro_time))*62)
  return Utils.encodeNum(full_time) .. Utils.encodeNum(micro_time)
end

return Utils