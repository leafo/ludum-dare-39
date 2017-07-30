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

-- call fn every ms
every = (ms, fn) ->
  local start
  (...) ->
    unless start
      start = time!
      return

    while time! - start > ms
      start += ms
      fn ...

random_normal = do
  r = math.random
  ->
    (r! + r! + r! + r! + r! + r! + r! + r! + r! + r! + r! + r!) / 12

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

  __unm: =>
    Vector -@x, -@y

  __add: (other) =>
    Vector @x + other.x, @y + other.y

  __sub: (other) =>
    Vector @x - other.x, @y - other.y

  __div: (num) =>
    Vector @x / num, @y / num

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

-- a square particle
class Particle extends Rect
  w: 2
  h: 2
  life: 500
  type: "rect"

  @emit_sparks: (world, origin, dir) =>
    for i=1,5
      -- shake it
      r = (math.random! + math.random!) / 2

      dir = dir\rotate (r - 0.5) * 2 * PI/3
      dir = dir * (random_normal!/2 + 1)

      accel = -dir / 40
      world\add @ origin, dir, accel

  @emit_explosion: (world, origin) =>
    for i=1,2
      big = i % 2 == 0

      radius = if big
        math.random 8,14
      else
        math.random 4,6

      o = origin + Vector(
        (random_normal! - 0.5) * 20
        (random_normal! - 0.5) * 20
      )

      world\add with @ o
        .radius = radius
        .type = "circle"

  draw_light: (lb, viewport) =>
    light = math.floor (1 - @p!) * 5
    p = viewport\apply @pos
    lb\rect p.x, p.y, @w, @h, light

  new: (@pos, @vel=Vector!, @accel=Vector!) =>

  update: (world) =>
    @vel += @accel
    @pos += @vel

    @spawn or= time!

    -- unless world\touches @
    --   world\remove @

    if time! - @spawn > @life
      world\remove @

  -- percentage of life lived
  p: =>
    return 0 unless @spawn
    math.max 0, math.min 1, (time! - @spawn) / @life

  draw: (viewport) =>
    color = math.floor (1 - @p!) * 12

    switch @type
      when "rect"
        pos = viewport\apply @pos
        rect pos.x, pos.y, @w, @h, color
      when "circle"
        center = viewport\apply @center!
        r = (@radius or 5) * (1 - @p!)
        circ center.x, center.y, r, color

class Bullet extends Rect
  w: 5
  h: 5

  new: (pos, @dir) =>
    @pos = pos - Vector @w / 2, @h / 2

  update: (world) =>
    @pos += @dir
    unless world\contains @
      world\remove @
      Particle\emit_sparks world, @pos, @dir\normalized!\rotate(PI)
      Particle\emit_explosion world, @pos

  draw_light: (lb, viewport) =>
    p = viewport\apply @pos
    lb\rect p.x, p.y, @w, @h

  draw: (viewport) =>
    color = 15
    x, y = viewport\apply(@center!)\unpack!
    r = floor @w/2
    circ x, y, r + 1, 3
    circ x, y, r, color

  __tostring: =>
    "Bullet(#{@pos}, #{@w}, #{@h})"

class Player extends Rect
  w: 10
  h: 10

  new: (...) =>
    super ...
    @aim_dir = Vector 1, 0

  draw_light: (lb, viewport) =>
    p = viewport\apply @pos
    lb\rect p.x, p.y, @w, @h

  draw: (viewport) =>
    center = viewport\apply @center!

    x, y = center\unpack!
    r = floor @w/2
    circ x, y, r+1, 3
    circ x, y, r, 15

    -- draw gun
    if d = @aim_dir
      pos = center
      for i=1,4
        circ pos.x, pos.y, 3, 2
        pos += d * 2

      pos = center
      for i=1,4
        circ pos.x, pos.y, 2, 15
        pos += d * 2

      dist = 15

      -- draw reticle
      ab = center + d\rotate(PI/4) * dist
      ab2 = center + d\rotate(-PI/4) * dist
      ab3 = center + d\rotate(PI/4 + PI) * dist
      ab4 = center + d\rotate(-PI/4 + PI) * dist

      line ab.x, ab.y, ab2.x, ab2.y, 11
      line ab2.x, ab2.y, ab3.x, ab3.y, 11
      line ab3.x, ab3.y, ab4.x, ab4.y, 11
      line ab4.x, ab4.y, ab.x, ab.y, 11


  shoot: (world) =>
    return unless @aim_dir
    origin = @center! + @aim_dir * 8
    world\add Bullet origin, @aim_dir * 5

  update: (world) =>
    @dir = Vector\from_input!

    if @dir\nonzero!
      @last_dir = @dir
      @aim_dir or= @last_dir

    if @aim_dir and @last_dir
      @aim_dir = @aim_dir\merge_angle @last_dir, 0.2

    @pos += @dir * 2

    -- @shoot_lock or= every 100, (world) -> @shoot world
    -- @.shoot_lock world

    if btnp 4
      @shoot world

class Map extends Rect
  wall_sprites: {1,2,3,4}
  rotations: {
    top: 2
    bottom: 0
    left: 1
    right: 3
  }

  @load_for_tiles: (tiles) =>
    assert tiles.width, "missing width for tileset"

    is_solid = (i) -> i != 0
    is_floor = (i) -> not is_solid i

    -- top left at 0, 0
    get_tile = (x, y) -> tiles[x + y * tiles.width + 1]

    -- each tile gets a rotation configuration based on the surrounding
    -- geometry
    arranged = for tile in ipairs tiles
      x = (tile - 1) % tiles.width
      y = math.floor (tile - 1) / tiles.width
      current = get_tile x, y

      if is_solid current
        -- get the direction the wall faces
        if is_floor get_tile x, y + 1
          "bottom"
        elseif is_floor get_tile x, y - 1
          "top"
        elseif is_floor get_tile x - 1, y
          "left"
        elseif is_floor get_tile x + 1, y
          "right"
        else
          "solid"
      else
        false -- no tile here

    @ arranged, tiles

  new: (@walls, opts) =>
    @pos = Vector!
    @tiles_width = opts.width
    @tiles_height = #@walls / opts.width

    @w = @tiles_width * 8
    @h = @tiles_width * 8

  -- draw the entire map
  draw: (viewport, ox=0, oy=0, light_buffer) =>
    {x: vx, y: vy} = viewport.pos

    for idx, wall in ipairs @walls
      continue unless wall
      -- continue if wall == "solid"

      x = (idx - 1) % @tiles_width
      y = math.floor (idx - 1) / @tiles_width

      tx, ty = ox + x * 8, oy + y * 8
      tx -= vx
      ty -= vy

      if wall == "solid"
        spr 0, tx, ty
        continue

      rot = @rotations[wall]
      continue unless rot

      spr(
        1
        tx, ty
        -1, 1, 0
        rot
      )

class Viewport extends Rect
  w: SCREEN_W
  h: VIEW_H

  new: =>
    @pos = Vector!

  center_on: (pos) =>
    @pos = pos - Vector @w/2, @h/2

  -- move the point into viewport space
  apply: (pos) =>
    pos - @pos

  draw: =>
    p = @apply @pos
    rectb p.x, p.y, @w, @h, 15

class World extends Rect
  new: =>
    super!

    @player = Player 10, 10
    @viewport = Viewport!

    @entities = {
      @player
    }

    @map = Map\load_for_tiles {
      width: 100, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0,0,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    }

    @w = @map.w
    @h = @map.h

  draw: =>
    @viewport\center_on @player.pos

    @map\draw @viewport
    for entity in *@entities
      entity\draw @viewport

    @viewport\draw!

  remove: (to_remove) =>
    @entities = [e for e in *@entities when e != to_remove]

  add: (e) =>
    table.insert @entities, e

  update: =>
    for entity in *@entities
      entity\update @

  __tostring: =>
    "World()"

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

f = every 100, ->
  lightbuffer\blur!

export scanline = (row) ->
  if row == 0
    set_palette PAL_GRAD

  if row == VIEW_H
    set_palette PAL_REG

local world
export TIC = ->
  world or= World!

  start = time!

  world\update!

  cls 0
  lightbuffer\write!

  for e in *world.entities
    if e.draw_light
      e\draw_light lightbuffer, world.viewport

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

