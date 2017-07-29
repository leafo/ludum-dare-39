-- converts tiled json map to something we can embed into game
-- encodes into binary string

filename = ...
file = assert io.open filename, "r"
content = file\read "*a"

json = require("cjson")
object = json.decode content
layer = assert object.layers[1], "missing layer"

bits = for t in *layer.data
  if t > 0
    1
  else
    0

print "{ width: #{object.width}, #{table.concat(bits, ",")} }"


