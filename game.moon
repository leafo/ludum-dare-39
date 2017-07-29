-- title: shoot game
-- author: leafo
-- desc: running out of power
-- script: moon
-- input: gamepad
-- safeid: leafo-ld39

PAL = 0x3fc0
set_palette = (colors) ->
  n = (v, ...) ->
    return unless v
    tonumber(v, 16), n ...

  for k, col in ipairs colors
    i = k - 1
    r,g,b = n col\match "^(..)(..)(..)$"
    poke PAL + i * 3, r
    poke PAL + i * 3 + 1, g
    poke PAL + i * 3 + 2, b

set_palette {
  "0d080d"
  "4f2b24"
  "825b31"
  "c59154"
  "f0bd77"
  "fbdf9b"
  "fff9e4"
  "bebbb2"
  "7bb24e"
  "74adbb"
  "4180a0"
  "32535f"
  "2a2349"
  "7d3840"
  "c16c5b"
  "e89973"
}

SCREEN_W = 240
SCREEN_H = 136

class Vector
  x: 0
  y: 0

  @from_input: =>
    y = if btn 0 then -1
    elseif btn 1 then 1
    else 0

    x = if btn 2 then -1
    elseif btn 3 then 1
    else 0

    @(x, y)\normalized!

  new: (@x, @y) =>

  unpack: =>
    @x, @y

  nonzero: =>
    @x != 0 or @y != 0

  len: =>
    return math.abs(@x) if @y == 0
    return math.abs(@y) if @x == 0
    math.sqrt @x*@x + @y*@y

  normalized: =>
    len = @len!
    if len == 0
      return Vector!

    Vector @x / len, @y / len

  __add: (other) =>
    Vector @x + other.x, @y + other.y

  __sub: (other) =>
    Vector @x - other.x, @y - other.y

  __mul: (a,b) ->
    if type(a) == "number"
      return Vector b.x * a, b.y * a

    if type(b) == "number"
      return Vector a.x * b, a.y * b

    -- dot product
    a.x * b.x + a.y * b.y

  __tostring: (other) =>
    "Vec(#{@x}, #{@y})"


class Rect
  w: 0
  h: 0

  new: (x,y,@w,@h)=>
    @pos = Vector x,y

  unpack: =>
    @pos.x, @pos.y, @w, @h

  draw: (color=5) =>
    rect @pos.x, @pos.y, @w, @h, color

  -- is touching another box
  touches: (other) =>
    {x: ox, y: oy} = other.pos

    return false if ox > @pos.x + @w
    return false if oy > @pos.y + @h

    return false if ox + other.w < @pos.x
    return false if oy + other.h < @pos.y

    true

  -- other is inside the rect
  contains: (other) =>
    {x: ox, y: oy} = other.pos

    return false if ox < @pos.x
    return false if oy < @pos.y

    return false if ox + other.w > @pos.x + @w
    return false if oy + other.h > @pos.y + @h

    true

  center: =>
    @pos + Vector @w/2, @h/2

class UIBar extends Rect
  p: 0

  new: (@p, ...) =>
    super ...

  draw: =>
    x,y,w,h = @unpack!
    rectb x,y,w,h, 15
    p = math.max 0, math.min 1, @p
    fill = math.floor p * (w - 4)
    rect x + 2, y + 2, fill, h - 4, 6

class Bullet extends Rect
  w: 5
  h: 5

  new: (pos, @dir) =>
    @pos = pos - Vector @w / 2, @h / 2

  update: (world) =>
    @pos += @dir
    unless world\contains @
      world\remove @

  draw: (color=15) =>
    x, y = @center!\unpack!
    circ x, y, @w/2, color

  __tostring: =>
    "Bullet(#{@pos}, #{@w}, #{@h})"

class Player extends Rect
  w: 10
  h: 10

  draw: =>
    super 8

    center = @center!
    if @dir
      pointing = center + @dir * 10
      line center.x, center.y, pointing.x, pointing.y, 11

  shoot: (world) =>
    return unless @last_dir
    world\add Bullet @center!, @last_dir * 5

  update: (world) =>
    @dir = Vector\from_input!

    if @dir\nonzero!
      @last_dir = @dir

    @pos += @dir * 2

    if btnp 4
      @shoot world


class World extends Rect
  w: SCREEN_W
  h: SCREEN_H

  new: =>
    super!

    @player = Player 10, 10

    @entities = {
      @player
    }

  draw: =>
    for entity in *@entities
      entity\draw!

  remove: (to_remove) =>
    @entities = [e for e in *@entities when e != to_remove]

  add: (e) =>
    table.insert @entities, e

  update: =>
    for entity in *@entities
      entity\update @

-- bar = UIBar 0.5, 5, 5, 40, 8

world = World!



class LightBuffer
  unpack_pixels = (byte) ->
    byte & 0xf, (byte & 0xf0) >> 4

  res: 20 -- number of vertical lines

  new: =>
    @w = @res
    @h = math.floor (SCREEN_H / SCREEN_W * @res) + 1

  size: =>
    "#{@w} #{@h}: #{@w * @h}"

  read: =>
    SCREEN = 0

    -- read all the colors into an array
    @buffer = {}

    line_width = SCREEN_W /2

    for y=1,@h
      for x=1,@w,2
        addr = (x - 1) / 2 + (y - 1) * line_width
        byte = peek SCREEN + addr
        a, b = unpack_pixels byte

        table.insert @buffer, a
        -- don't take color ourside buffer
        unless x == @w
          table.insert @buffer, b

  blur: =>

  write: =>

  -- draw the buffer over the whole screen
  draw: =>
    assert @buffer, "no buffer has been read"

    cell_w = SCREEN_W / @res
    cell_h = SCREEN_W / @res

    k = 0
    for y=1,@h
      for x=1,@w

        rect(
          (x - 1) * cell_w
          (y - 1) * cell_h
          cell_w
          cell_h
          k % 16
        )

        k += 1


-- export scanline = ->
--   trace "hi"

lightbuffer = LightBuffer!

last_time = 0

export TIC = ->
  start = time!
  cls 0

  -- write some stuff into the buffer
  for i=0,25
    pix i, 0, 11

  line 0, 0, lightbuffer.w - 1, lightbuffer.h - 1, 10
  line lightbuffer.w - 1, 0, 0, lightbuffer.h - 1, 10

  pix 0, 0, 6
  pix lightbuffer.w - 1, 0, 6
  pix 0, lightbuffer.h - 1, 6
  pix lightbuffer.w - 1, lightbuffer.h - 1, 6

  -- not in buffer
  pix SCREEN_W - 1, 0, 15

  --lightbuffer\draw!
  -- world\update!
  -- world\draw!

  if btnp 5
    lightbuffer\read!

  if lightbuffer.buffer
    lightbuffer\draw!

  util = (time! - start) / 16
  UIBar(util, 2, 100, SCREEN_W - 4, 5)\draw!
  print "Entities: #{#world.entities}", SCREEN_W - 80, 10


