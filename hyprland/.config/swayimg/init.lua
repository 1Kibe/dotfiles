-- swayimg: default image viewer of the Hyprland session (install.sh:
-- set_default_apps). Colors from the shell (quickshell/theme/Theme.qml),
-- as ARGB: bgHard 1d2021, bg 282828, bg1 3c3836, bg2 504945, fg ebdbb2,
-- accentLight bfb8a3, yellow fabd2f.
-- Every key is set here: the built-in ones are reset first.

local font = "Agave Nerd Font Propo"

swayimg.decoration = false     -- Hyprland draws no title bars
swayimg.exif_orientation = true

-- Opening one file also lists the other images of its folder
swayimg.imagelist.order = "numeric"
swayimg.imagelist.adjacent = true
swayimg.imagelist.fsmon = true

-- ── Info panel (key i) ──
swayimg.text.visible = false
swayimg.text.timeout = 0       -- stays until i is pressed again
swayimg.text.status_timeout = 3
swayimg.text.font = font
swayimg.text.size = 18
swayimg.text.padding = 14
swayimg.text.color = 0xffebdbb2
swayimg.text.background = 0xd9282828
swayimg.text.shadow = 0x00000000

swayimg.format_conf = {
  ttf = { color = 0xffebdbb2, background = 0x00000000 },
}

-- ── Trash with confirmation ──
-- The first Delete only asks; a second Delete on the same image within 3 s
-- sends it to the trash (gio trash, it can be restored). Nothing is deleted
-- for good.
local pending, pending_at = nil, 0

local function quote(path)
  return "'" .. path:gsub("'", "'\\''") .. "'"
end

local function trash(image)
  if not image or not image.path then
    return
  end
  if pending ~= image.path or os.time() - pending_at > 3 then
    pending, pending_at = image.path, os.time()
    swayimg.text.status = "Delete de novo para mandar à lixeira"
    return
  end
  pending = nil
  local result = os.execute("gio trash -- " .. quote(image.path))
  if result == 0 or result == true then
    swayimg.imagelist.remove(image.path)
    swayimg.text.status = "Na lixeira"
  else
    swayimg.text.status = "Não deu para mandar à lixeira"
  end
end

local function forget_pending()
  pending = nil
end

-- ── Keys shared by the viewer and the gallery ──
local function common_keys(mode)
  mode.on_key("Escape", function() swayimg.exit() end)
  mode.on_key("q", function() swayimg.exit() end)
  mode.on_key("i", function() swayimg.text.visible = not swayimg.text.visible end)
  mode.on_key("f", function() swayimg.fullscreen = not swayimg.fullscreen end)
  mode.on_key("F11", function() swayimg.fullscreen = not swayimg.fullscreen end)
  mode.on_key("Delete", function() trash(mode.get_image()) end)
  mode.on_image_change(forget_pending)
end

-- ── Viewer ──
local viewer = swayimg.viewer
viewer.bind_reset()
viewer.default_scale = "optimal"
viewer.default_position = "center"
viewer.loop = true
viewer.preload = 1
viewer.history = 1
viewer.mark_color = 0xfffabd2f
viewer.text = {
  topleft = {
    "Arquivo:\t{name}",
    "Formato:\t{format}",
    "Tamanho:\t{frame.width}×{frame.height}",
    "Peso:\t{sizehr}",
    "Data:\t{time}",
    "Foto:\t{meta.Exif.Photo.DateTimeOriginal}",
    "Câmera:\t{meta.Exif.Image.Model}",
  },
  topright = { "{list.index} de {list.total}" },
  bottomleft = { "Zoom:\t{scale}" },
}
viewer.set_window_background(0xff1d2021)
viewer.set_image_chessboard(16, 0xff3c3836, 0xff504945)

common_keys(viewer)
viewer.on_key("Return", function() swayimg.mode = "gallery" end)
viewer.on_key("g", function() swayimg.mode = "gallery" end)
viewer.on_key("Left", function() viewer.open("prev") end)
viewer.on_key("Right", function() viewer.open("next") end)
viewer.on_key("Prior", function() viewer.open("prev") end)
viewer.on_key("Next", function() viewer.open("next") end)
viewer.on_key("space", function() viewer.open("next") end)
viewer.on_key("Home", function() viewer.open("first") end)
viewer.on_key("End", function() viewer.open("last") end)
viewer.on_key({ "plus", "Shift-plus", "equal", "KP_Add" }, function()
  viewer.scale = viewer.scale * 1.1
end)
viewer.on_key({ "minus", "KP_Subtract" }, function()
  viewer.scale = viewer.scale / 1.1
end)
viewer.on_key("0", function() viewer.reset() end)
viewer.on_key("r", function() viewer.rotate(90) end)
viewer.on_key("Shift-r", function() viewer.rotate(270) end)
viewer.on_key("s", function() swayimg.mode = "slideshow" end)

-- Wheel: zoom at the mouse; Shift+wheel: previous/next image
viewer.on_scroll(function(kmods, horizontal, vertical)
  if not vertical or vertical == 0 then
    return
  end
  if kmods == "Shift" then
    viewer.open(vertical > 0 and "prev" or "next")
    return
  end
  local mouse = swayimg.get_mouse_pos()
  local scale = viewer.scale
  viewer.set_abs_scale(scale - scale * vertical / 10.0, mouse.x, mouse.y)
end)

-- ── Slide show (s), 5 s per image ──
local slideshow = swayimg.slideshow
slideshow.bind_reset()
slideshow.timeout = 5
slideshow.default_scale = "fit"
slideshow.text = { topleft = { "{name}" } }
slideshow.set_window_background(0xff1d2021)
slideshow.on_key("Escape", function() swayimg.mode = "viewer" end)
slideshow.on_key("s", function() swayimg.mode = "viewer" end)
slideshow.on_key("q", function() swayimg.exit() end)

-- ── Gallery (Enter or g), with thumbnails ──
local gallery = swayimg.gallery
gallery.bind_reset()
gallery.thumb_size = 180
gallery.aspect = "fill"
gallery.padding_size = 8
gallery.border_size = 3
gallery.border_color = 0xffbfb8a3
gallery.selected_scale = 1.08
gallery.selected_color = 0xff3c3836
gallery.unselected_color = 0xff282828
gallery.window_color = 0xff1d2021
gallery.mark_color = 0xfffabd2f
gallery.hover = true
gallery.pstore = true          -- thumbnails kept in ~/.cache, faster next time
gallery.text = {
  topleft = { "{name}" },
  topright = { "{list.index} de {list.total}" },
}

common_keys(gallery)
gallery.on_key("Return", function() swayimg.mode = "viewer" end)
gallery.on_key("g", function() swayimg.mode = "viewer" end)
gallery.on_key("Left", function() gallery.select("left") end)
gallery.on_key("Right", function() gallery.select("right") end)
gallery.on_key("Up", function() gallery.select("up") end)
gallery.on_key("Down", function() gallery.select("down") end)
gallery.on_key("Prior", function() gallery.select("pgup") end)
gallery.on_key("Next", function() gallery.select("pgdown") end)
gallery.on_key("Home", function() gallery.select("first") end)
gallery.on_key("End", function() gallery.select("last") end)
gallery.on_key({ "plus", "Shift-plus", "equal", "KP_Add" }, function()
  gallery.thumb_size = gallery.thumb_size + 20
end)
gallery.on_key({ "minus", "KP_Subtract" }, function()
  gallery.thumb_size = math.max(gallery.thumb_size - 20, 80)
end)

-- Wheel: next row; Ctrl+wheel: thumbnail size
gallery.on_scroll(function(kmods, horizontal, vertical)
  if not vertical or vertical == 0 then
    return
  end
  if kmods == "Ctrl" then
    gallery.thumb_size = math.max(gallery.thumb_size + math.floor(-vertical * 10), 80)
    return
  end
  gallery.select(vertical > 0 and "up" or "down")
end)

-- A click opens the thumbnail under the mouse (hover selects it)
gallery.on_mouse("MouseLeft", function() swayimg.mode = "viewer" end)
