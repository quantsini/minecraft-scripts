local arg = {...}
if table.getn(arg) == 0 or table.getn(arg) > 2 then
   print("usage: "..shell.getRunningProgram().." url <output>")
   return 0
end

local data = http.get(arg[1]).readAll()

if table.getn(arg) == 1 then
  print(data)
else
  if fs.exists(arg[2]) then
    fs.remove(arg[2])
  end
  
  local h = fs.open(arg[2], "w")
  h.write(data)
  h.close()
end