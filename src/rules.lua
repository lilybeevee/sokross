local Rules = Class{}

function Rules:init(room)
  self.room = room
  self.inherited_rules = {}
  self:clear()
end

function Rules:clear()
  self.rules = {}
  self.raw_rules = {}
  self.not_rules = {}
  self.not_layers = 0
  self.new_active = {}
end

function Rules:addInherents()
  local function addRule(target, effect)
    table.insert(self.rules, {target = target, effect = effect})
  end

  --addRule("flof", "play")
  --addRule("wall", "stop")
  --addRule("box", "push")
  --addRule("ladder", "exit")
  --addRule("room", "push")
  --addRule("rule", "push")

  --addRule("rule", "word")
  --addRule("key", "push")
  --addRule("key", "open")
  --addRule("door", "stop")
  --addRule("door", "lock")
  --addRule("ring", "tele")
  --addRule("belt", "move")
end

function Rules:addInherited()
  if self.room:getParent() then
    self.inherited_rules = {}
    for _,raw in ipairs(self.room:getParent().rules.raw_rules) do
      table.insert(self.inherited_rules, raw)
      table.insert(self.raw_rules, raw)
    end
  else
    for _,raw in ipairs(self.inherited_rules) do
      table.insert(self.raw_rules, raw)
    end
  end
end

function Rules:get(target, effect)
  local result = {}
  for _,rule in ipairs(self.rules) do
    local target_match = not target or (target and target == rule.target)
    local effect_match = not effect or (effect and effect == rule.effect)
    if target_match and effect_match then
      table.insert(result, rule)
    end
  end
  return result
end

function Rules:parse()
  self:clear()
  self:addInherents()

  -- create raw rules from tiles
  self.raw_rules = self:buildRaw()

  -- copy raw rules from above layers
  self:addInherited()

  -- parse raw rules into the rules table
  for _,raw in ipairs(self.raw_rules) do
    self:parseRaw(Utils.copy(raw))
  end

  -- remove cancelled rules
  self:applyNot()
end

function Rules:parseRaw(raw)
  --print("Parsing raw: "..dump(raw))

  -- take the target and effect from the start and end of the raw rule respectively
  local target = table.remove(raw, 1)
  local effect = table.remove(raw, #raw)
  
  -- we're left with only the modifiers, so we can loop through them now
  local not_count = 0
  for _,mod in ipairs(raw) do
    if mod == "not" then
      not_count = not_count + 1
    elseif mod == "plus" then
      -- nothing! plus is pretty much already covered
    else
      error("Unrecognized rule modifier: "..mod)
    end
  end

  if not_count > 0 then
    -- if we have any NOTs in the rule, add them to the not_rules table instead, indexed by
    -- the amount of NOTs there are (we will loop through them from top to bottom later)
    self.not_layers = math.max(self.not_layers, not_count)
    self.not_rules[not_count] = self.not_rules[not_count] or {}
    self.not_rules[not_count][target..","..effect] = true
  else
    table.insert(self.rules, {target = target, effect = effect})
  end
end

function Rules:buildRaw()
  -- Creates a list of tables with all connection names in order, for example:
  --   {"flof", "play"}, {"wall", "not", "stop"}, {"box", "not", "not", "push"}
  
  -- Every raw rule will have the format {target, ...(modifiers), effect}

  local raw_rules = {}
  for _,tile in ipairs(self.room.tiles_by_name["rule"] or {}) do
    -- make all words inactive unless they've been processed
    if not self.new_active[tile] then
      tile.active = false
    end

    -- only parse from nouns because rules can only start from nouns
    if tile.word.type == "noun" then
      local function process(tile, current, processed)
        -- stop processing this branch if we've looped around to
        -- a word we already processed before in this branch
        if processed[tile] then
          return
        else
          processed[tile] = true
        end

        -- add the tile to the current branch
        table.insert(current, tile)

        -- add the current branch to the table and return if the current word is a property
        --   1. there is currently no support for anything connecting into properties
        --   2. all rules should end with a property
        if tile.word.type == "prop" then
          local names = {}
          for _,v in ipairs(current) do
            table.insert(names, v.word.name)
            v.active = true
            self.new_active[v] = true
          end
          table.insert(raw_rules, names)
          return
        end

        -- loop through all words properly connected to the current tile and
        -- recursively process them into a new branch (copied from the current)
        for _,other in ipairs(tile:getConnections("in")) do
          process(other[1], Utils.copy(current), Utils.copy(processed))
        end
      end
      process(tile, {}, {}, {})
    end
  end

  return raw_rules
end

function Rules:applyNot()
  local layer = self.not_layers
  while layer > 0 do
    local lower
    if layer == 1 then
      lower = self.rules
    else
      lower = self.not_rules[layer - 1]
    end

    if layer == 1 then
      local to_remove = {}
      for i,rule in ipairs(lower) do
        if self.not_rules[layer][rule.target..","..rule.effect] then
          table.insert(to_remove, i)
        end
      end
      for i,index in ipairs(to_remove) do
        table.remove(lower, index-i+1)
      end
    elseif self.not_rules[layer - 1] then
      for name,_ in pairs(self.not_rules[layer]) do
        self.not_rules[layer - 1][name] = nil
      end
    end

    layer = layer - 1
  end
end

return Rules