os.loadAPI("json")

local url = "https://api.github.com/gists"
local args = {...}

if table.getn(args) ~= 1 then
  print("usage: "..shell.getRunningProgram().." file")
  return 0
end

if not fs.exists(args[1]) then
  print("file not found")
  return 0
end

local file = fs.open(args[1], "r")
local file_content = file.readAll()
file.close()
local content = {
  public=true,
  files={
    file={
      content=file_content
     }
    }
  }
content = json.json.encode(content)
local resp = http.post(url, content)
if resp == nil then
  print("what")
  return 0
end
resp = json.json.decode(resp.readAll())

print(resp["html_url"])