local home = os.getenv("HOME")

if home then
  local generated = home .. "/.config/hypr/generated-theme.lua"
  local handle = io.open(generated, "r")
  if handle then
    handle:close()
    local ok, error = pcall(dofile, generated)
    if not ok then
      print("Infinity theme load failed: " .. tostring(error))
    end
  end
end
