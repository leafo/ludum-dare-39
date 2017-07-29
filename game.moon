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

{:cos, :sin, :floor, :atan2, pi: PI} = math

PAL_GRAD = {
  "210D14"
  "2D1C20"
  "382C2C"
  "443B38"
  "504B44"
  "5B5A50"
  "676A5C"
  "737968"
  "7E8974"
  "8A9880"
  "96A88C"
  "A1B798"
  "ADC7A4"
  "B9D6B0"
  "C4E6BC"
  "D0F5C8"
}

PAL_REG = {
  -- "0d080d"
  -- "4f2b24"
  -- "825b31"
  -- "c59154"
  -- "f0bd77"
  -- "fbdf9b"
  -- "fff9e4"
  -- "bebbb2"
  -- "7bb24e"
  -- "74adbb"
  -- "4180a0"
  -- "32535f"
  -- "2a2349"
  -- "7d3840"
  -- "c16c5b"
  -- "e89973"

  "140C1C"
  "442434"
  "30346D"
  "4E4A4F"
  "854C30"
  "346524"
  "D04648"
  "757161"
  "597DCE"
  "D27D2C"
  "8595A1"
  "6DAA2C"
  "D2AA99"
  "6DC2CA"
  "DAD45E"
}

SCREEN_W = 240
SCREEN_H = 136
VIEW_H = SCREEN_H - 15

class Vector
  x: 0
  y: 0

  @from_radians: (rads) =>
    Vector cos(rads), sin(rads)

  @from_input: =>
    y = if btn 0 then -1
    elseif btn 1 then 1
    else 0

    x = if btn 2 then -1
    elseif btn 3 then 1
    else 0

    @(x, y)\normalized!

  new: (@x, @y) =>

  radians: =>
    atan2 @y, @x

  rotate: (rads) =>
    c, s = cos(rads), sin(rads)
    Vector @x*c - @y*s, @y*c + @x*s

  -- returns new vector with average angle betwen the two
  -- returns unit vector
  merge_angle: (other, p=0.5) =>
    a = @radians!
    b = other\radians!

    if b - a > PI
      a += 2 * PI

    if b - a < -PI
      a -= 2 * PI

    rad = a + (b - a) * p
    @@from_radians rad

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

  draw: (color=6) =>
    x,y,w,h = @unpack!
    rectb x,y,w,h, 15
    p = math.max 0, math.min 1, @p
    fill = floor p * (w - 4)
    rect x + 2, y + 2, fill, h - 4, color

class Bullet extends Rect
  w: 5
  h: 5

  new: (pos, @dir) =>
    @pos = pos - Vector @w / 2, @h / 2

  update: (world) =>
    @pos += @dir
    unless world\contains @
      world\remove @

  draw_light: (lb) =>
    lb\rect @unpack!

  draw: (color=15) =>
    x, y = @center!\unpack!
    r = floor @w/2
    circ x, y, r + 1, 3
    circ x, y, r, color

  __tostring: =>
    "Bullet(#{@pos}, #{@w}, #{@h})"

class Player extends Rect
  w: 10
  h: 10

  draw_light: (lb) =>
    lb\rect @unpack!

  draw: =>
    center = @center!
    x, y = center\unpack!
    r = floor @w/2
    circ x, y, r+1, 3
    circ x, y, r, 15

    -- draw gun
    if d = @aim_dir
      -- d = Vector\from_radians time! / 1000

      pos = center
      for i=1,4
        circ pos.x, pos.y, 3, 2
        pos += d * 2

      pos = center
      for i=1,4
        circ pos.x, pos.y, 2, 15
        pos += d * 2

      -- pointing = center + d * 50
      -- line center.x, center.y, pointing.x, pointing.y, 11

  shoot: (world) =>
    return unless @last_dir
    origin = @center! + @last_dir * 8
    world\add Bullet origin, @last_dir * 5

  update: (world) =>
    @dir = Vector\from_input!

    if @dir\nonzero!
      @last_dir = @dir
      @aim_dir or= @last_dir

    if @aim_dir and @last_dir
      @aim_dir = @aim_dir\merge_angle @last_dir, 0.2

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

  pack_pixels = (a,b) ->
    assert type(a) == "number", "missing a for pack"
    assert type(b) == "number", "missing b for pack"
    a + (b << 4)

  SCREEN = 0
  LINE_WIDTH = SCREEN_W /2

  res: 20 -- number of vertical lines

  new: =>
    @w = @res
    @h = floor (SCREEN_H / SCREEN_W * @res) + 1

  rect: (x, y, w, h, b=8) =>
    return nil unless @buffer
    scalex = @w / SCREEN_W
    scaley = @h / SCREEN_H

    lx = x*scalex
    ly = y*scaley
    lw = w*scalex
    lh = h*scaley

    -- make it cover whole pixels
    area = lw * ly

    lw = floor(lx + lw + 0.5)
    lh = floor(ly + lh + 0.5)

    lx = floor lx
    ly = floor ly

    lw -= lx
    lh -= ly

    ratio = math.max 0.2, math.min 1, area / (lw * lh)
    rect lx, ly, lw, lh, floor ratio * b + 0.5

  read: =>
    -- read all the colors into an array
    @buffer = {}

    for y=1,@h
      for x=1,@w,2
        addr = (x - 1) / 2 + (y - 1) * LINE_WIDTH
        byte = peek SCREEN + addr
        a, b = unpack_pixels byte

        table.insert @buffer, a
        -- don't take color outside buffer
        unless x == @w
          table.insert @buffer, b

  -- write the buffer back
  write: =>
    return nil unless @buffer

    k = 1
    for y=1,@h
      for x=1,@w,2
        addr = (x - 1) / 2 + (y - 1) * LINE_WIDTH

        if x == @w
          poke4 SCREEN + addr, floor(@buffer[k])
          k += 1
        else
          poke SCREEN + addr, pack_pixels floor(@buffer[k]), floor(@buffer[k + 1])
          k += 2

  blur: =>
    return nil unless @buffer
    radius = 1
    decay = 1

    new_buffer = {}
    size = #@buffer

    -- blur on y
    for idx=1,size
      hit = 0
      sum = 0

      for o=-radius,radius
        if val = @buffer[idx + o * @w]
          sum += val
          hit += 1


      new_buffer[idx] =  sum / hit

    -- blur on y axis
    for idx=1,size
      hit = 0
      sum = 0

      for o=-radius,radius
        x = (idx - 1) % @w + o
        continue if x < 0 or x >= @w
        hit += 1
        sum += new_buffer[idx + o]

      new_buffer[idx] = decay * sum / hit

    @buffer = new_buffer

  -- draw the buffer over the whole screen
  draw: =>
    return nil unless @buffer

    cell_w = SCREEN_W / @res
    cell_h = SCREEN_W / @res

    k = 1
    for y=1,@h
      for x=1,@w
        c = floor @buffer[k]
        tx, ty = (x - 1) * cell_w, (y - 1) * cell_h

        rect(
          tx, ty
          cell_w, cell_h
          c
        )

        k += 1

lightbuffer = LightBuffer!

-- call fn every ms
every = (ms, fn) ->
  local start
  ->
    unless start
      start = time!
      return

    while time! - start > ms
      start += ms
      fn!

f = every 100, ->
  lightbuffer\blur!

export scanline = (row) ->
  if row == 0
    set_palette PAL_GRAD

  if row == VIEW_H
    set_palette PAL_REG

export TIC = ->
  start = time!

  world\update!

  cls 0
  lightbuffer\write!

  for e in *world.entities
    if e.draw_light
      e\draw_light lightbuffer

  lightbuffer\read!
  f!

  cls 0
  clip 0, 0, SCREEN_W, VIEW_H
  lightbuffer\draw!

  world\draw!

  clip!
  util = (time! - start) / 16
  print "Energy: 0, Entities: #{#world.entities}", 0, SCREEN_H - 6
  UIBar(util, 0, SCREEN_H - 15, SCREEN_W, 5)\draw!

-- up = Vector 0, -1
-- down = Vector 0, 1
-- left = Vector -1, 0
-- right = Vector 1, 0
-- 
-- print "u", up, up\radians!
-- print "r", right, right\radians!
-- print "d", down, down\radians!
-- print "l", left, left\radians!
-- 


