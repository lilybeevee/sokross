local Editor = {}

function Editor:enter()
  print("Sokoma editor")

  self.font = love.graphics.newFont(46)
end

function Editor:draw()
  love.graphics.setFont(self.font)
  local text = "What is Sokoma. Like what is that"
  love.graphics.print(text, love.graphics.getWidth()/2 - self.font:getWidth(text)/2, love.graphics.getHeight()/2 - self.font:getHeight()/2)
end

return Editor