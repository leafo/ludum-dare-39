-- converts tiled json map to something we can embed into game
-- encodes into binary string

filename, var_name = ...

var_name or= "MAP_1"

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


tile_ids = for t in *tiles.data
  if t > 0
    t - 1
  else
    0

map_objects = {}

if objects
  for object in *objects.objects
    table.insert map_objects,
      "{ type: '#{object.type}', #{math.floor object.x}, #{math.floor object.y}}"

print "#{var_name} = { width: #{map.width}, objects: {#{table.concat map_objects, ", "}}, #{table.concat(tile_ids, ",")} }\n"


