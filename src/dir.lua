local Dir = {}

function Dir.toPos(dir)
  if dir == 1 then return  1,  0 end
  if dir == 2 then return  0,  1 end
  if dir == 3 then return -1,  0 end
  if dir == 4 then return  0, -1 end
end

function Dir.fromPos(x,y)
  if Vector.eq(x,y,  1,  0) then return 1 end
  if Vector.eq(x,y,  0,  1) then return 2 end
  if Vector.eq(x,y, -1,  0) then return 3 end
  if Vector.eq(x,y,  0, -1) then return 4 end
end

function Dir.reverse(dir)
  if dir == 1 then return 3 end
  if dir == 2 then return 4 end
  if dir == 3 then return 1 end
  if dir == 4 then return 2 end
end

return Dir