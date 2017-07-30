-- converts tiled json map to something we can embed into game
-- encodes into binary string

filename = ...
file = assert io.open filename, "r"
content = file\read "*a"

json = require("cjson")
map = json.decode content
-- layer = assert object.layers[1], "missing layer"

local tiles, objects
for layer in *map.layers
  switch layer.type
    when "tilelayer"
      tiles = layer
    when "objectgroup"
      objects = layer

bits = for t in *tiles.data
  if t > 0
    1
  else
    0

print "{ width: #{map.width}, #{table.concat(bits, ",")} }"


