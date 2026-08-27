local override = os.getenv("HOME") .. "/.config/hypr/user_overrides.lua"
local file = io.open(override, "r")
if file then
  file:close()
  dofile(override)
end
