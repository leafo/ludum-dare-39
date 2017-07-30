
DEBUG = false -- hides light map and shows all tiles

instance_of = do
  subclass = (child, parent) ->
    return false unless parent and child
    return true if child == parent
    if p = child.__parent
      subclass p, parent
    else
      false

  (obj, cls) ->
    subclass obj.__class, cls

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

{:cos, :sin, :floor, :ceil, :atan2, pi: PI} = math

sounds = {
  explode: -> sfx 0, "C-4", 16, 3
  low_explode: -> sfx 0, "C-3", 13, 3
  shoot: -> sfx 1, "C-4", 16, 3
  game_start: -> sfx 5, "C-5", 32, 3
  game_over: -> sfx 6, "C-5", 32, 3
}

local Vector, Enemy, GameOver, Game, Title

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

round = (v) -> floor v + 0.5

random_normal = do
  r = math.random
  ->
    (r! + r! + r! + r! + r! + r! + r! + r! + r! + r! + r! + r!) / 12

smoothstep = (a, b, t) ->
  t = t*t*t*(t*(t*6 - 15) + 10)
  a + (b - a)*t

-- moves object right up until edge of collision
fit_move = (obj, move, world) ->
  if world\collides obj
    trace "object(#{obj}) is stuck"
    return

  start = obj.pos
  obj.pos += move

  -- was able to move
  return unless world\collides obj

  -- reset, move piecewise
  obj.pos = start

  hit_x, hit_y = false, false

  if move.x != 0
    obj.pos += Vector move.x, 0
    if world\collides obj
      hit_x = true
      nudge_x = if move.x > 0 then -1 else 1
      obj.pos.x = round obj.pos.x
      while world\collides obj
        obj.pos.x += nudge_x

  if move.y != 0
    obj.pos += Vector 0, move.y
    if world\collides obj
      hit_y = true
      nudge_y = if move.y > 0 then -1 else 1
      obj.pos.y = round obj.pos.y
      while world\collides obj
        obj.pos.y += nudge_y

  hit_x, hit_y


-- gets the buckets that this rect hits in the grid
-- implemented as stateless iterator
grid_hash_iter = do
  hash_pt = (x,y) -> "#{x}.#{y}"
  grid_hashes = (rect, k=0, grid_size=40) ->
    x, y, w, h = rect\unpack!

    x2 = x + w
    y2 = y + h

    x = floor x / grid_size
    y = floor y / grid_size

    steps_x = floor(x2 / grid_size) - x + 1
    steps_y = floor(y2 / grid_size) - y + 1
    total_steps = steps_x * steps_y

    return nil, "out of range: #{k}" if k >= total_steps

    hx = x + (k % steps_x)
    hy = y + floor(k / steps_x)
    has_more = k + 1 < total_steps

    k + 1, hash_pt(hx, hy)

  (rect) -> grid_hashes, rect, nil

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

  flip_x: => @@ -@x, @y
  flip_y: => @@ @x, -@y

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
    "Vec(#{"%.3f"\format @x}, #{"%.3f"\format @y})"

class Rect
  w: 0
  h: 0
  collision_type: "box"

  new: (x,y,@w,@h)=>
    @pos = Vector x,y

  unpack: =>
    @pos.x, @pos.y, @w, @h

  draw: (viewport, color=5) =>
    p = viewport\apply @pos
    rect p.x, p.y, @w, @h, color

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

  center_on: (pos) =>
    @pos = pos - Vector @w/2, @h/2

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
  collision_type: "center"
  light_radius: 0

  @emit_sparks: (world, origin, dir) =>
    for i=1,5
      -- shake it
      r = (math.random! + math.random!) / 2

      dir = dir\rotate (r - 0.5) * 2 * PI/3
      dir = dir * (random_normal!/2 + 1)

      accel = -dir / 40
      world\add @ origin, dir, accel

  @emit_cross_explosion: (world, origin) =>
    sounds.explode!

    --- shoot circles out in all dirs
    for rad=0,PI*2-1,PI/2
      dir = Vector\from_radians rad

      world\add with @ origin
        .light_radius = 10
        .radius = 10
        .type = "circle"
        .life = 500 * random_normal!
        .vel = dir * 5
        .friction = 1.1

  @emit_explosion: (world, origin) =>
    sounds.explode!

    for i=1,2
      big = i % 2 == 1

      radius = if big
        math.random 8,14
      else
        math.random 6,10

      o = origin + Vector(
        (random_normal! - 0.5) * 20
        (random_normal! - 0.5) * 20
      )

      world\add with @ o
        .light_radius = 10
        .radius = radius
        .type = "circle"
        .life = 500 * random_normal!

  new: (@pos, @vel=Vector!, @accel=Vector!) =>

  update: (world) =>
    @vel += @accel
    if @friction
      @vel = @vel / @friction

    @pos += @vel

    @spawn or= time!

    if time! - @spawn > @life
      world\remove @

  -- percentage of life lived
  p: =>
    return 0 unless @spawn
    p = math.max 0, math.min 1, (time! - @spawn) / @life
    if @inverse
      1 - p
    else
      p

  draw_light: (lb, viewport) =>
    light = floor (1 - @p!) * 5
    p = viewport\apply @pos
    lb\rect(
      p.x - @light_radius
      p.y - @light_radius
      @w + @light_radius * 2
      @h + @light_radius * 2
      light
    )

  draw: (viewport) =>
    color = floor math.pow(1 - @p!, 0.8) * 12
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
  collision_type: "center"

  new: (pos, @dir) =>
    @pos = pos - Vector @w / 2, @h / 2

  update: (world) =>
    @pos += @dir

    is_hit = world\collides @
    if enemy = not is_hit and world\touching_entity @, Enemy
      enemy\on_hit world, @
      is_hit = true

    if is_hit
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


class Base extends Rect
  w: 48
  h: 48

  new: (x, y) =>
    @center_on Vector x,y

  draw: (viewport) =>
    return unless @active

    p = viewport\apply @center!
    r = @w/2 * ((@active_frame / 4) % 10) / 10
    rectb p.x - r, p.y - r, r*2, r*2, 14

  draw_light: (lb, viewport) =>
    return unless @active
    p = viewport\apply @pos
    lb\rect p.x-1, p.y-1, @w+2, @h+2

  update: (world) =>
    if @active_frame
      @active_frame += 1

    active = world\touching_entity @, Player

    if not @active and active
      @active_frame = 0

    @active = active

class Player extends Rect
  health: 2
  w: 10
  h: 10
  collidable: true
  stun_frames: 0

  new: (...) =>
    super ...
    @aim_dir = Vector 1, 0

  draw_light: (lb, viewport) =>
    p = viewport\apply @pos
    radius = 3
    lb\rect(
      p.x - radius
      p.y - radius
      @w + radius * 2
      @h + radius * 2
    )

  draw: (viewport) =>
    center = viewport\apply @center!

    x, y = center\unpack!
    r = floor @w/2
    circ x, y, r+1, 3
    circ x, y, r, 15

    -- draw gun
    if d = @aim_dir
      gun_root = center
      if @recoil_frames
        gun_root -= @aim_dir * @recoil_frames

      pos = gun_root
      for i=1,4
        circ pos.x, pos.y, 3, 2
        pos += d * 2

      pos = gun_root
      for i=1,4
        circ pos.x, pos.y, 2, 15
        pos += d * 2

      dist = 15

      -- -- draw reticle
      -- ab = center + d\rotate(PI/4) * dist
      -- ab2 = center + d\rotate(-PI/4) * dist
      -- ab3 = center + d\rotate(PI/4 + PI) * dist
      -- ab4 = center + d\rotate(-PI/4 + PI) * dist

      -- line ab.x, ab.y, ab2.x, ab2.y, 11
      -- line ab2.x, ab2.y, ab3.x, ab3.y, 11
      -- line ab3.x, ab3.y, ab4.x, ab4.y, 11
      -- line ab4.x, ab4.y, ab.x, ab.y, 11

  is_dead: =>
    @health <= 0

  shoot: (world) =>
    return if @is_dead!

    sounds.shoot!
    @recoil_frames = 4
    return unless @aim_dir
    origin = @center! + @aim_dir * 8
    world\add Bullet origin, @aim_dir * 5

  stun: (world) =>
    return if @stun_frames > 0
    @stun_frames = 15
    sounds.low_explode!
    world\shake!

  on_die: (world) =>
    Particle\emit_cross_explosion world, @center!
    world\set_timeout 1.5, ->
      sounds.game_over!
      export TIC = GameOver\tic

  -- hit by bullet or enemy
  on_hit: (world, e) =>
    return if @is_dead!

    @stun_dir = (@center! - e\center!)\normalized! * 10
    e\shake world
    @stun world
    @health -= 1

    if @health <= 0
      @on_die world

  update: (world) =>
    if @is_dead!
      world\remove @
      return

    input = Vector\from_input!

    @vel = if @stun_frames == 0
      input * 2
    else
      @stun_frames -= 1
      with (@stun_dir or Vector!) + input
        @stun_dir = @stun_dir * 0.85

    if @recoil_frames
      @recoil_frames -= 1
      @recoil_frames = nil if @recoil_frames == 0

    if input\nonzero!
      @last_dir = input
      @aim_dir or= @last_dir

    if @aim_dir and @last_dir
      @aim_dir = @aim_dir\merge_angle @last_dir, 0.2

    hit_x, hit_y = fit_move @, @vel, world

    -- bounce off walls if we are stunned
    if @stun_frames > 0
      if hit_x
        if @vel\len! > 4
          world\shake!
          sounds.explode!
        @stun_dir = @stun_dir\flip_x!

      if hit_y
        if @vel\len! > 4
          world\shake!
          sounds.explode!
        @stun_dir = @stun_dir\flip_y!

    -- @shoot_lock or= every 100, (world) -> @shoot world
    -- @.shoot_lock world

    if btnp 4
      @shoot world

    if e = world\touching_entity @, Enemy
      @on_hit world, e

class Enemy extends Rect
  w: 15
  h: 15
  health: 5
  light_radius: 15
  collidable: true
  shake_frames: 0
  flash_frames: 0

  draw_light: (lb, viewport) =>
    lr = @light_radius
    -- remove light
    p = viewport\apply @pos
    lb\rect(
      p.x - lr
      p.y - lr
      @w + lr * 2
      @h + lr * 2
      0
    )

  draw: (viewport) =>
    pos = viewport\apply @pos
    shake_offset = if @shake_frames > 0
      Vector math.random(-4, 4), math.random(-4, 4)

    pos += shake_offset if shake_offset

    rect pos.x, pos.y, @w, @h, 0

    if @flash_frames > 0
      r = @flash_frames
      c = viewport\apply @center!
      c += shake_offset if shake_offset

      rectb c.x - r, c.y - r, r*2, r*2, 15
      @flash_frames -= 1

  shake: =>
    @shake_frames = 10
    @flash_frames = ceil 4 + @w / 2

  on_die: (world) =>
    world.map\flash!
    Particle\emit_cross_explosion world, @center!

  on_hit: (world, bullet) =>
    @shake!
    @health -= 1

  update: (world) =>
    if @shake_frames > 0
      @shake_frames -= 1

    if @health <= 0
      @on_die world
      world\remove @

-- bug will move around and charge
class Bug extends Enemy
  update: (world, lb) =>

  draw_light: false

  draw: (viewport) =>
    Rect.draw @, viewport, 10

class ShootBug extends Enemy
  new: (...) =>
    super

  update: (world) =>


class SprayBug extends Enemy
  new: (...) =>
    super

  update: (world) =>

class Map extends Rect
  wall_sprites: {5,4,3,2,1}
  corner_sprites: { 21, 20, 19, 18, 17 }
  base_sprites: {35, 34, 33}
  base_corner_sprites: {51, 50, 49}

  global_brightness: 0

  rotations: {
    b: 0
    l: 1
    t: 2
    r: 3

    bl: 0
    tl: 1
    tr: 2
    br: 3
  }

  @load_for_tiles: (tiles) =>
    assert tiles.width, "missing width for tileset"

    is_solid = (i) -> i == 1 or not i
    is_base = (i) -> i == 2
    is_floor = (i) -> i == 0

    -- top left at 0, 0
    get_tile = (x, y) -> tiles[x + y * tiles.width + 1]

    -- each tile gets a rotation configuration based on the surrounding
    -- geometry
    arranged = for tile in ipairs tiles
      x = (tile - 1) % tiles.width
      y = floor (tile - 1) / tiles.width
      current = get_tile x, y

      dir = if is_solid(current) or is_base(current)
        open_below = is_floor get_tile x, y + 1
        open_above = is_floor get_tile x, y - 1
        open_left = is_floor get_tile x - 1, y
        open_right = is_floor get_tile x + 1, y

        -- get the direction the wall faces
        if open_below
          if open_left
            "bl"
          elseif open_right
            "br"
          else
            "b"
        elseif open_above
          if open_left
            "tl"
          elseif open_right
            "tr"
          else
            "t"
        elseif open_left
          "l"
        elseif open_right
          "r"

      if is_solid current
        dir or "solid"
      elseif is_base(current) and dir
        "_#{dir}"
      else
        false -- no tile here

    @ arranged, tiles

  new: (@walls, opts) =>
    @pos = Vector!
    @tiles_width = opts.width
    @tiles_height = #@walls / opts.width

    @w = @tiles_width * TILE_W
    @h = @tiles_width * TILE_H

    @objects = opts.objects or {}

  collides: (rect) =>
    switch rect.collision_type
      when "box"
        @collides_box  rect
      when "center"
        @collides_pt rect\center!\unpack!
      else
        error "unknown collision type"

  collides_box: (rect) =>
    {:x, :y} = rect.pos
    steps_x = ceil rect.w / TILE_W
    steps_y = ceil rect.h / TILE_H

    for oy=1,steps_y
      x = rect.pos.x

      for ox=1,steps_x
        return true if @collides_pt x,y
        x += TILE_W
      y += TILE_H

    false


  -- checks if pt is touching solid tile
  collides_pt: (x, y) =>
    x = floor x / TILE_W
    y = floor y / TILE_H

    -- outside map
    if x >= @tiles_width or x < 0 or y >= @tiles_height or y < 0
      true

    tile = @walls[x + y * @tiles_width + 1]
    if tile
      tile\sub(1,1) != "_"
    else
      false

  flash: (amount=1.0) =>
    @global_brightness = amount

  update: =>
    if @global_brightness > 0
      @global_brightness -= 0.03
      @global_brightness = 0 if @global_brightness < 0

  -- draw the entire map
  draw: (viewport, lb, world) =>
    {x: vx, y: vy} = viewport.pos

    -- for all tiles that fit into the screen
    vp_tiles_x = floor(viewport.w / TILE_H) + 1
    vp_tiles_y = floor(viewport.h / TILE_W) + 1
    vp_tiles = vp_tiles_x * vp_tiles_y

    origin_x = vx % TILE_W
    origin_y = vy % TILE_H

    -- how far are we offset in map
    mox = floor vx / TILE_W
    moy = floor vy / TILE_H

    for idx=0,vp_tiles-1
      -- x,y is tile coordinate in screen space
      x = idx % vp_tiles_x
      y = floor idx / vp_tiles_x

      tx = x*TILE_W - origin_x
      ty = y*TILE_H - origin_y

      x += mox
      y += moy

      -- out of bounds
      wall = if x >= @tiles_width or x < 0 or y >= @tiles_height or y < 0
        "solid"
      else
        @walls[x + y * @tiles_width + 1]

      continue unless wall

      -- to debug map:
      -- rect tx, ty, TILE_W, TILE_H, (idx % 2) + 10
      -- do continue

      if wall == "solid"
        spr 0, tx, ty
        continue

      is_base = wall\sub(1,1) == "_"
      wall = if is_base
        wall\sub 2,-1

      rot = @rotations[wall]
      continue unless rot

      b = lb\light_for_pos Vector tx + TILE_W / 2, ty + TILE_H / 2
      b += smoothstep 0, 1, @global_brightness
      b = math.max 0, math.min 1, b

      if DEBUG
        b = 1 -- view all tiles

      if b == 0
        spr 0, tx, ty
        continue

      b = math.pow b, 0.4

      sprites = if is_base
        #wall == 2 and @base_corner_sprites or @base_sprites
      else
        #wall == 2 and @corner_sprites or @wall_sprites

      levels = #sprites
      sprite_idx = math.min levels, floor(b * levels) + 1

      spr(
        sprites[sprite_idx]
        tx, ty
        -1, 1, 0
        rot
      )

class Viewport extends Rect
  w: SCREEN_W
  h: VIEW_H

  new: =>
    @pos = Vector!

  update: =>
    if @target_center
      mid_center = (@center! + @target_center) / 2
      @pos = mid_center - Vector @w/2, @h/2

  floating_center_on: (pos, max_len=20) =>
    center = @center!
    -- vector from center to pos
    dir = pos - center
    len = dir\len!

    return if len <= max_len

    delta =  dir\normalized! * max_len
    @center_on pos - delta

  -- move the point into viewport space
  apply: (pos) =>
    pos - @pos

  draw: =>
    p = @apply @pos
    rectb p.x, p.y, @w, @h, 15

class World extends Rect
  new: =>
    super!

    @player = Player 28, 28
    @viewport = Viewport!

    @timers = {}

    @entities = {
      @player
    }

    @map = Map\load_for_tiles MAP_1
    for object in *@map.objects
      {x, y} = object
      switch object.type
        when "enemy"
          @add Enemy x, y
        when "bug"
          @add Bug x, y
        when "player"
          @player.pos = Vector x, y
        when "base"
          assert not @base, "base already exists"
          @base = Base x,y
          @add @base

    @w = @map.w
    @h = @map.h
    -- music 0

  draw: (lb) =>
    @map\draw @viewport, lb, @

    for entity in *@entities
      entity\draw @viewport

    if @shake_frames
      if @shake_frames == 0
        poke 0x3FF9, 0
        poke 0x3FF9 + 1, 0
        @shake_frames = nil
      else
        poke 0x3FF9, math.random -@shake_intensity, @shake_intensity
        poke 0x3FF9 + 1, math.random -@shake_intensity, @shake_intensity
        @shake_frames -= 1

    -- @viewport\draw!

  build_collision_grid: =>
    @collision_grid = nil
    for e in *@entities
      continue unless e.collidable
      for _, bucket in grid_hash_iter e
        unless @collision_grid
          @collision_grid = {}

        t = @collision_grid[bucket]
        unless t
          t = {}
          @collision_grid[bucket] = t

        table.insert t, e

    @collision_grid

  touching_entity: (e, cls=nil) =>
    return unless @collision_grid

    for _, bucket in grid_hash_iter e
      cell = @collision_grid[bucket]
      continue unless cell
      for other_e in *cell
        continue if other_e == e
        if cls and not instance_of other_e, cls
          continue

        if e\touches other_e
          return other_e


  remove: (to_remove) =>
    unless @entities_to_remove
      @entities_to_remove = {}

    @entities_to_remove[to_remove] = true

  -- wait is in seconds
  set_timeout: (wait, callback) =>
    frames = wait * FPS
    table.insert @timers, {frames, callback}

  add: (e) =>
    table.insert @entities, e

  collides: (obj) =>
    @map\collides obj

  shake: =>
    @shake_intensity = 4
    @shake_frames = 10

  update: =>
    @viewport\floating_center_on @player.pos + @player.aim_dir * 10
    @viewport\update!
    @map\update!

    -- if btnp 6
    --   @shake!

    @build_collision_grid!
    for entity in *@entities
      entity\update @

    if @entities_to_remove
      @entities = [e for e in *@entities when not @entities_to_remove[e]]
      @entities_to_remove = nil

    @update_timers!

  update_timers: =>
    return unless @timers[1]

    clean_timers = false
    for timer in *@timers
      timer[1] -= 1
      if timer[1] <= 0
        clean_timers = true
        timer[2] @

    if clean_timers
      @timers = [t for t in *@timers when t[1] > 0]

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
  ox: 0
  oy: 0

  new: =>
    @w = @res
    @h = floor (SCREEN_H / SCREEN_W * @res) + 1

  light_for_pos: (pos) =>
    return unless @buffer

    cx, cy = pos\unpack!
    cx += @ox
    cy += @oy

    x = floor cx / SCREEN_W * @w + 0.5
    y = floor cy / SCREEN_H * @h + 0.5

    idx = x + y * @w
    b = @buffer[idx + 1] or 0
    floor(b + 0.5) / 15 --> move it in p space

  rect: (x, y, w, h, b=8) =>
    return nil unless @buffer
    scalex = @w / SCREEN_W
    scaley = @h / SCREEN_H

    x += @ox
    y += @oy

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
  write: (viewport) =>
    return nil unless @buffer

    cell_w = SCREEN_W / @w
    cell_h = SCREEN_H / @h

    -- get the hanging amount
    {x: vx, y: vy} = viewport.pos
    @ox = vx % cell_w
    @oy = vy % cell_h

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
  draw: (debug=false) =>
    return nil unless @buffer

    -- this is fractional
    cell_w = SCREEN_W / @w
    cell_h = SCREEN_H / @h
    origin_x = -@ox
    origin_y = -@oy

    if debug
      cell_w = 1
      cell_h = 1
      origin_x = 0
      origin_y = 0

    tx, ty = origin_x, origin_y
    for k=1,@w*@h
      c = floor @buffer[k]

      ftx = floor tx
      fty = floor ty

      -- fill the y gaps
      bottom = ty + cell_h
      bottom = floor bottom + 0.5
      real_h = bottom - fty

      -- fill the x gaps
      right = tx + cell_w
      right = floor right + 0.5
      real_w = right - ftx

      rect(
        ftx, fty
        real_w, real_h
        c
      )

      -- increment position
      if k % @w == 0
        tx = origin_x
        ty += cell_h
      else
        tx += cell_w

    if debug
      rectb 0, 0, @w, @h, 10

class Screen
  loaded: false

  on_load: =>
    set_palette PAL_REG
    export scanline = (row) ->

  tic: =>
    unless @loaded
      @on_load!
      @loaded = true

    @update()

class GameOver extends Screen
  on_load: =>
    @frame = 0

  update: =>
    cls 0
    print "You have died, sorry!", 10, 10
    print "Please try again!", 10, 20

    @frame += 1
    if @frame > 40
      if btnp 4
        export TIC = Title!\tic


class Title extends Screen
  on_load: =>
    super!
    @frame = 0

  -- create vector field
  draw_grid: =>
    size = 20
    width = floor(SCREEN_W / size) + 1
    height = floor(SCREEN_H / size) + 1

    x, y = 0, 0
    t = time! / 200
    vectors = [Vector(x * size + 4 * math.sin(t* 1.1 + 2 + y), y * size + 4 * math.cos(t * 0.9 + 4 + x)) for x=0,width-1 for y=0,width-1]
    for v in *vectors
      circ v.x, v.y, 2, 2

  update: =>
    @frame += 1

    if @frame > 40
      if btnp 4
        sounds.game_start!
        export TIC = Game!\tic

    cls 0

    @draw_grid!

    print "X-Moon 2: Dark Moon", 16, 9, 15, false, 2
    print "A game of tactical espionage action", 22, 24, 7

    if math.floor(@frame / 30) % 2 == 0
      print "Press button 1 to begin", 49, 115

    spr 128, 83, 36, 7, 1, 0, 0, 8, 8

class Game extends Screen
  loaded: false

  on_load: =>
    @world = World!

    @lightbuffer = LightBuffer!
    @blur_lightbuffer = every 100, -> @lightbuffer\blur!

    export scanline = (row) ->
      if row == 0
        set_palette PAL_GRAD

      if row == VIEW_H
        set_palette PAL_REG

  update: =>
    {:lightbuffer, :blur_lightbuffer, :world} = @

    start = time!
    world\update!

    cls 0
    lightbuffer\write world.viewport

    for e in *world.entities
      if e.draw_light
        e\draw_light lightbuffer, world.viewport

    lightbuffer\read!
    blur_lightbuffer!

    cls 0
    clip 0, 0, SCREEN_W, VIEW_H

    unless DEBUG
      lightbuffer\draw!

    world\draw lightbuffer

    clip!
    util = (time! - start) / (1 / FPS * 1000)
    print table.concat({
      "Entities: #{#world.entities}"
      "HP: #{world.player.health}"
      tostring world.player.pos
    }, ", "), 0, SCREEN_H - 6
    UIBar(util, 0, SCREEN_H - 15, SCREEN_W, 5)\draw!

export TIC = Game!\tic
-- export TIC = Title!\tic

