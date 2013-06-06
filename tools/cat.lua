local arg = {...}
if table.getn(arg) ~= 1 then
  print("usage: "..shell.getRunningProgram().." file")
  return 0
end
if fs.exists(arg[1]) then
  local h = fs.open(arg[1], "r")
  print(h.readAll())
  h.close()
end