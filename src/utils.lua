local Utils = {}

function dump(o)
  if type(o) == 'table' then
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
  elseif type(o) == 'string' then
    return '"' .. o .. '"'
  else
    return tostring(o)
  end
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

return Utils