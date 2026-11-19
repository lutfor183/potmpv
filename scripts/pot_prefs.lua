local mp = require "mp"
local utils = require "mp.utils"
local opt = require "mp.options"

local o = { font = "", scale = 1.0, accent = "3E9BD8", hide_delay = 2500, bar_alpha = "E8", playlist_width = 360 }
opt.read_options(o, "pot")

local FONT = o.font
if FONT == "" then
    local pf = mp.get_property("platform") or "linux"
    if pf == "win" then FONT = "Segoe UI"
    elseif pf == "darwin" then FONT = "Helvetica Neue"
    else FONT = "Roboto" end
end

local C = {
    panel = "1E1E1E", head = "252525", text = "E8E8E8", dim = "9A9A9A",
    accent = o.accent, hover = "2E2E2E", line = "3A3A3A", track = "3A3A3A",
    sel = "2A2A2A", white = "FFFFFF", shadow = "000000",
}

local function N(v) return math.floor(v + 0.5) end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function col(h) return "&H" .. h:sub(5, 6) .. h:sub(3, 4) .. h:sub(1, 2) .. "&" end
local function at(a)
    local v = tonumber(a or "FF", 16) or 255
    if v < 0 then v = 0 elseif v > 255 then v = 255 end
    return string.format("%02X", 255 - v)
end
local function shape(path, hex, a)
    if path == "" then return "" end
    return "{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\1c" .. col(hex) .. "\\1a&H" .. at(a) .. "&}" .. path
end
local function text(x, y, an, s, size, hex, a, bold)
    return string.format("{\\an%d\\pos(%d,%d)\\fn%s\\fs%d\\1c%s\\1a&H%s&%s\\bord0\\shad0}%s",
        an, N(x), N(y), FONT, N(size), col(hex), at(a), bold and "\\b1" or "\\b0", s)
end
local function tw(s, size) return #s * size * 0.56 end
local function esc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "/"):gsub("{", "("):gsub("}", ")")
    return (s:gsub("[\r\n]+", " "))
end
local function poly(...)
    local t = { ... }
    local out = {}
    for i = 1, #t, 2 do
        out[#out + 1] = string.format("%s %d %d", i == 1 and "m" or "l", N(t[i]), N(t[i + 1]))
    end
    return table.concat(out, " ")
end
local function rectp(x, y, w, h) return poly(x, y, x + w, y, x + w, y + h, x, y + h) end
local function checkout(x, y, s, hex, a)
    return shape(poly(x + s * .1, y + s * .52, x + s * .26, y + s * .36, x + s * .38, y + s * .5,
        x + s * .66, y + s * .16, x + s * .8, y + s * .3, x + s * .38, y + s * .74), hex, a)
end
local function trip(x, y, s, hex, dir)
    if dir < 0 then return shape(poly(x + s * .7, y + s * .15, x + s * .7, y + s * .85, x + s * .25, y + s * .5), hex) end
    return shape(poly(x + s * .3, y + s * .15, x + s * .3, y + s * .85, x + s * .75, y + s * .5), hex)
end
local function ellipsize(s, size, maxw)
    if tw(s, size) <= maxw then return s end
    local n = math.floor(maxw / (size * 0.56)) - 1
    if n < 1 then return "" end
    return s:sub(1, n) .. "\226\128\166"
end

local function pct(v) return tostring(N(v)) .. "%" end
local function ms(v) return tostring(N(v)) .. " ms" end
local function num(v, dec) return string.format("%." .. (dec or 0) .. "f", v) end
local function yesno(v) return v and "On" or "Off" end

local function cat_playback()
    return {
        { label = "Remember playback position", kind = "bool", prop = "save-position-on-quit" },
        { label = "Keep player open after playback", kind = "bool", prop = "keep-open" },
        { label = "Repeat current file", kind = "choice", prop = "loop-file", values = { "no", "inf" }, names = { "Off", "On" } },
        { label = "Repeat playlist", kind = "choice", prop = "loop-playlist", values = { "no", "inf" }, names = { "Off", "On" } },
        { label = "Default volume", kind = "slider", prop = "volume", min = 0, max = 130, step = 5, fmt = pct },
        { label = "Maximum volume", kind = "slider", prop = "volume-max", min = 100, max = 200, step = 10, fmt = pct },
    }
end

local function cat_video()
    return {
        { label = "Hardware decoding", kind = "choice", prop = "hwdec",
          values = { "no", "auto-safe", "auto", "auto-copy" },
          names = { "Off", "Auto (safe)", "Auto", "Auto (copy)" } },
        { label = "Deinterlace", kind = "choice", prop = "deinterlace", values = { "no", "yes" }, names = { "Off", "On" } },
        { label = "Video sync", kind = "choice", prop = "video-sync",
          values = { "audio", "display-resample" }, names = { "Audio", "Display resample" } },
        { label = "Motion interpolation", kind = "bool", prop = "interpolation" },
        { label = "Deband", kind = "bool", prop = "deband" },
        { label = "Scaling filter", kind = "choice", prop = "scale",
          values = { "bilinear", "lanczos", "ewa_lanczossharp" },
          names = { "Bilinear (fast)", "Lanczos", "EWA Lanczos Sharp" } },
    }
end

local function cat_audio()
    return {
        { label = "Normalize downmix", kind = "bool", prop = "audio-normalize-downmix" },
        { label = "Gapless audio", kind = "choice", prop = "gapless-audio",
          values = { "no", "weak", "yes" }, names = { "Off", "Weak", "On" } },
        { label = "Auto-load audio files", kind = "choice", prop = "audio-file-auto",
          values = { "no", "exact", "fuzzy" }, names = { "Off", "Exact", "Fuzzy" } },
        { label = "Pitch correction", kind = "bool", prop = "audio-pitch-correction" },
    }
end

local function cat_sub()
    return {
        { label = "Auto-load subtitles", kind = "choice", prop = "sub-auto",
          values = { "no", "exact", "fuzzy" }, names = { "Off", "Exact", "Fuzzy" } },
        { label = "Font size", kind = "slider", prop = "sub-font-size", min = 20, max = 100, step = 2 },
        { label = "Bold", kind = "bool", prop = "sub-bold" },
        { label = "Border size", kind = "slider", prop = "sub-border-size", min = 0, max = 6, step = 0.2, dec = 1 },
        { label = "Vertical position", kind = "slider", prop = "sub-pos", min = 50, max = 150, step = 5 },
        { label = "Text color", kind = "choice", prop = "sub-color",
          values = { "#FFFFFFFF", "#FFFFFF00", "#FF00FFFF", "#FF00FF00" },
          names = { "White", "Yellow", "Cyan", "Green" } },
        { label = "ASS styles", kind = "choice", prop = "sub-ass-override",
          values = { "no", "yes", "scale", "force" },
          names = { "Keep original", "Override", "Scale", "Force" } },
    }
end

local function cat_shots()
    return {
        { label = "Format", kind = "choice", prop = "screenshot-format", values = { "png", "jpg", "webp" } },
        { label = "Include subtitles", kind = "bool", prop = "screenshot-subs" },
        { label = "Save location", kind = "choice", prop = "screenshot-directory",
          values = { "~~/screenshots", "" }, names = { "Config folder", "Current folder" } },
    }
end

local function cat_ui()
    return {
        { label = "UI scale", kind = "slider", custom = "ui.scale", min = 0.6, max = 1.8, step = 0.05, dec = 2, fmt = function(v) return num(v, 2) .. "x" end },
        { label = "Hide controls after", kind = "slider", custom = "ui.hide", min = 500, max = 8000, step = 250, fmt = ms },
        { label = "Mouse cursor autohide", kind = "slider", prop = "cursor-autohide", min = 0, max = 5000, step = 250, fmt = ms },
        { label = "Window border", kind = "bool", prop = "border" },
        { label = "Always on top", kind = "bool", prop = "ontop" },
    }
end

local cats = {
    { name = "Playback", rows = cat_playback },
    { name = "Video", rows = cat_video },
    { name = "Audio", rows = cat_audio },
    { name = "Subtitles", rows = cat_sub },
    { name = "Screenshots", rows = cat_shots },
    { name = "Interface", rows = cat_ui },
}

local P = {
    open = false, cat = 1, sel = 1, offset = 0, saved = {}, baseline = {},
    w = 800, h = 560, s = 1, ml = 0, mt = 0, hit = {},
}

local overlay = mp.create_osd_overlay("ass-events")
overlay.z = 1200
local shown = false

local function conf_path()
    local dir = mp.get_property("config-dir") or "."
    return utils.join_path(dir, "potmpv-prefs.conf")
end

local function apply_value(key, val)
    if key == "ui.scale" then
        mp.commandv("script-message-to", "pot_ui", "pot-setopt", "scale", val)
    elseif key == "ui.hide" then
        mp.commandv("script-message-to", "pot_ui", "pot-setopt", "hide_delay", val)
    else
        mp.commandv("set", key, val)
    end
end

local function current_value(row)
    if row.custom then
        if row.custom == "ui.scale" then return o.scale end
        if row.custom == "ui.hide" then return o.hide_delay end
        return 0
    end
    return mp.get_property_native(row.prop)
end

local function value_string(row)
    if row.kind == "bool" then return yesno(current_value(row)) end
    if row.kind == "choice" then
        local cur = mp.get_property(row.prop)
        for i, v in ipairs(row.values) do
            if v == cur then return row.names and row.names[i] or v end
        end
        return tostring(cur)
    end
    local v = current_value(row)
    if type(v) ~= "number" then return tostring(v) end
    if row.fmt then return row.fmt(v) end
    return num(v, row.dec)
end

local function save()
    local lines = {}
    for k, v in pairs(P.saved) do lines[#lines + 1] = k .. "=" .. tostring(v) end
    table.sort(lines)
    local f = io.open(conf_path(), "w")
    if f then f:write(table.concat(lines, "\n") .. "\n") f:close() end
end

local function set_row(row, dir)
    if row.kind == "bool" then
        local cur = not not current_value(row)
        local nv = not cur
        mp.commandv("set", row.prop, nv and "yes" or "no")
        P.saved[row.prop] = nv and "yes" or "no"
    elseif row.kind == "choice" then
        local cur = mp.get_property(row.prop)
        local idx = 1
        for i, v in ipairs(row.values) do if v == cur then idx = i end end
        if dir ~= 0 then idx = ((idx - 1 + (dir > 0 and 1 or #row.values - 1)) % #row.values) + 1 end
        mp.commandv("set", row.prop, row.values[idx])
        P.saved[row.prop] = row.values[idx]
    elseif row.kind == "slider" then
        local v = tonumber(current_value(row)) or row.min
        if dir ~= 0 then
            v = clamp(v + (dir > 0 and row.step or -row.step), row.min, row.max)
            v = row.step >= 1 and N(v) or math.floor(v * 100 + 0.5) / 100
        end
        local sv = num(v, row.dec)
        if row.custom then
            apply_value(row.custom, sv)
            P.saved[row.custom] = sv
        else
            mp.commandv("set", row.prop, sv)
            P.saved[row.prop] = sv
        end
    end
    save()
end

local function slider_set(row, frac)
    local v = row.min + (row.max - row.min) * clamp(frac, 0, 1)
    if row.step >= 1 then v = N(v / row.step) * row.step end
    v = clamp(v, row.min, row.max)
    local sv = num(v, row.dec)
    if row.custom then
        apply_value(row.custom, sv)
        P.saved[row.custom] = sv
    else
        mp.commandv("set", row.prop, sv)
        P.saved[row.prop] = sv
    end
    save()
end

local function rows()
    local f = cats[P.cat] and cats[P.cat].rows
    return f and f() or {}
end

local function geom()
    local d = mp.get_property_native("osd-dimensions") or {}
    local W, H = d.w or 1280, d.h or 720
    local ml, mr, mt, mb = d.ml or 0, d.mr or 0, d.mt or 0, d.mb or 0
    local aw, ah = W - ml - mr, H - mt - mb
    if aw < 120 or ah < 90 then aw, ah = 1280, 720 end
    P.ml, P.mt = ml, mt
    P.aw, P.ah = aw, ah
    P.s = clamp(o.scale, 0.7, 3.0)
    P.w = math.min(N(780 * P.s), aw - N(24 * P.s))
    P.h = math.min(N(560 * P.s), ah - N(24 * P.s))
    P.x = N((aw - P.w) / 2)
    P.y = N((ah - P.h) / 2)
end

local function layout()
    geom()
    local s = P.s
    P.navW = N(168 * s)
    P.headH = N(42 * s)
    P.footH = N(44 * s)
    P.rowH = N(32 * s)
    P.rowsY = P.y + P.headH + N(10 * s)
    P.contentX = P.x + P.navW + N(16 * s)
    P.contentW = P.w - P.navW - N(32 * s)
    P.maxrows = math.max(1, math.floor((P.h - P.headH - P.footH - N(16 * s)) / P.rowH))
    local n = #rows()
    P.offset = clamp(P.offset, 0, math.max(0, n - P.maxrows))
    P.sel = clamp(P.sel, 1, math.max(1, n))
end

local render

local function schedule()
    if P.pending then return end
    P.pending = true
    mp.add_timeout(0.03, function() P.pending = false; render() end)
end

local function close()
    if not P.open then return end
    P.open = false
    if shown then overlay:remove(); shown = false end
    for _, k in ipairs({ "ESC", "UP", "DOWN", "LEFT", "RIGHT", "ENTER", "KP_ENTER", "TAB",
        "MBTN_LEFT", "MBTN_LEFT_DBL", "MBTN_RIGHT", "WHEEL_UP", "WHEEL_DOWN" }) do
        mp.remove_key_binding("pot-prefs-" .. k)
    end
    mp.commandv("script-message-to", "pot_ui", "pot-unlock")
end

local function mouse()
    local p = mp.get_property_native("mouse-pos")
    if not p or not p.x then return nil end
    return p.x - P.ml, p.y - P.mt
end

local function row_at(mx, my)
    local list = rows()
    for i = 1, math.min(#list, P.maxrows) do
        local idx = P.offset + i
        local y = P.rowsY + (i - 1) * P.rowH
        if my >= y and my < y + P.rowH then
            return idx, list[idx], y
        end
    end
end

local function click()
    local mx, my = mouse()
    if not mx then return end
    -- close button
    if mx >= P.x + P.w - N(38 * P.s) and mx <= P.x + P.w - N(8 * P.s)
        and my >= P.y + N(7 * P.s) and my <= P.y + N(37 * P.s) then
        close(); return
    end
    -- nav
    local navY = P.y + P.headH + N(10 * P.s)
    local navH = N(34 * P.s)
    for i = 1, #cats do
        local y = navY + (i - 1) * navH
        if mx >= P.x + N(8 * P.s) and mx <= P.x + P.navW - N(6 * P.s) and my >= y and my < y + navH then
            P.cat = i; P.sel = 1; P.offset = 0; schedule(); return
        end
    end
    -- footer buttons
    local by = P.y + P.h - P.footH + N(6 * P.s)
    local bw, bh = N(90 * P.s), N(28 * P.s)
    local closeX = P.x + P.w - bw - N(14 * P.s)
    local resetX = closeX - bw - N(8 * P.s)
    if my >= by and my <= by + bh then
        if mx >= closeX and mx <= closeX + bw then close(); return end
        if mx >= resetX and mx <= resetX + bw then
            for k, v in pairs(P.baseline) do apply_value(k, v) end
            P.saved = {}
            save()
            schedule()
            mp.commandv("show-text", "Settings reset to defaults", "2500")
            return
        end
    end
    if mx < P.contentX - N(8 * P.s) then return end
    local idx, row, y = row_at(mx, my)
    if not row then return end
    P.sel = idx
    if row.kind == "bool" then
        set_row(row, 0)
    elseif row.kind == "choice" then
        set_row(row, 1)
    elseif row.kind == "slider" then
        local cw = N(150 * P.s)
        local cx = P.x + P.w - N(24 * P.s) - cw
        if mx >= cx - N(30 * P.s) then
            slider_set(row, (mx - cx) / cw)
        else
            set_row(row, 1)
        end
    end
    schedule()
end

render = function()
    if not P.open then return end
    layout()
    local s = P.s
    local a = {}
    local function add(x) if x and x ~= "" then a[#a + 1] = x end end
    local function ev(txt) add(txt) end

    add(shape(rectp(0, 0, P.aw, P.ah), "000000", "80"))
    add(shape(rectp(P.x + N(5 * s), P.y + N(5 * s), P.w, P.h), C.shadow, "90"))
    add(shape(rectp(P.x, P.y, P.w, P.h), C.panel, "FA"))
    add(shape(rectp(P.x, P.y, P.w, N(1 * s)), C.line, "D0"))
    add(shape(rectp(P.x, P.y + P.h - N(1 * s), P.w, N(1 * s)), C.line, "D0"))
    add(shape(rectp(P.x, P.y, P.w, P.headH), C.head, "FF"))
    add(text(P.x + N(16 * s), P.y + N(P.headH / 2), 4, "Preferences", N(14 * s), C.text, nil, true))
    local cx, cy = P.x + P.w - N(22 * s), P.y + N(P.headH / 2)
    add(text(cx, cy, 5, "\195\151", N(17 * s), C.dim))

    -- nav
    local navY = P.y + P.headH + N(10 * s)
    local navH = N(34 * s)
    for i, c in ipairs(cats) do
        local y = navY + (i - 1) * navH
        if i == P.cat then
            add(shape(rectp(P.x + N(6 * s), y, P.navW - N(12 * s), navH), C.sel, "FF"))
            add(shape(rectp(P.x + N(6 * s), y, N(3 * s), navH), C.accent))
        end
        add(text(P.x + N(18 * s), y + N(navH / 2), 4, c.name, N(12 * s), i == P.cat and C.text or C.dim))
    end
    add(shape(rectp(P.x + P.navW, P.y + P.headH + N(6 * s), N(1 * s), P.h - P.headH - P.footH - N(4 * s)), C.line, "90"))

    -- rows
    local list = rows()
    local mx, my = mouse()
    local hoverRow = nil
    if mx then local ri = row_at(mx, my); hoverRow = ri end
    for i = 1, math.min(#list, P.maxrows) do
        local idx = P.offset + i
        local row = list[idx]
        if row then
            local y = P.rowsY + (i - 1) * P.rowH
            local hov = (idx == P.sel)
            if hov then
                add(shape(rectp(P.contentX - N(6 * s), y + N(1 * s), P.contentW + N(6 * s), P.rowH - N(2 * s)), C.sel, "C0"))
            end
            local labelW = P.contentW * 0.55
            add(text(P.contentX, y + N(P.rowH / 2), 4, esc(ellipsize(row.label, N(12 * s), labelW)), N(12 * s), C.text))
            local rightX = P.x + P.w - N(24 * s)
            if row.kind == "bool" then
                local bx, by = rightX - N(18 * s), y + N(P.rowH / 2) - N(9 * s)
                add(shape(rectp(bx, by, N(18 * s), N(18 * s)), hov and C.accent or C.track, "FF"))
                if current_value(row) then
                    add(checkout(bx, by, N(18 * s), C.white))
                end
            elseif row.kind == "choice" then
                local vs = value_string(row)
                add(text(rightX - N(4 * s), y + N(P.rowH / 2), 6, esc(vs), N(12 * s), hov and C.accent or C.dim))
                add(trip(rightX - N(24 * s) - tw(vs, N(12 * s)) - N(6 * s), y + N(P.rowH / 2) - N(5 * s), N(10 * s), C.dim, -1))
                add(trip(rightX + N(2 * s), y + N(P.rowH / 2) - N(5 * s), N(10 * s), C.dim, 1))
            elseif row.kind == "slider" then
                local v = tonumber(current_value(row)) or row.min
                local vs = value_string(row)
                local cw = N(150 * s)
                local cx0 = rightX - cw
                local frac = clamp((v - row.min) / (row.max - row.min), 0, 1)
                add(shape(rectp(cx0, y + N(P.rowH / 2) - N(2 * s), cw, N(4 * s)), C.track, "C0"))
                add(shape(rectp(cx0, y + N(P.rowH / 2) - N(2 * s), N(cw * frac), N(4 * s)), C.accent))
                add(shape(poly(cx0 + cw * frac, y + N(P.rowH / 2) - N(6 * s),
                    cx0 + cw * frac - N(5 * s), y + N(P.rowH / 2),
                    cx0 + cw * frac, y + N(P.rowH / 2) + N(6 * s),
                    cx0 + cw * frac + N(5 * s), y + N(P.rowH / 2)), C.white))
                add(text(cx0 - N(14 * s), y + N(P.rowH / 2), 6, esc(vs), N(11 * s), hov and C.accent or C.dim))
            end
        end
    end

    if #list > P.maxrows then
        local th = P.maxrows * P.rowH
        local sh = math.max(N(20 * s), N(th * P.maxrows / #list))
        local sy = P.rowsY + N((th - sh) * (P.offset / math.max(1, #list - P.maxrows)))
        add(shape(rectp(P.x + P.w - N(5 * s), P.rowsY, N(2 * s), th), C.track, "80"))
        add(shape(rectp(P.x + P.w - N(5 * s), sy, N(2 * s), sh), C.accent, "C0"))
    end

    -- footer
    add(shape(rectp(P.x, P.y + P.h - P.footH, P.w, P.footH), C.head, "FF"))
    add(text(P.x + N(16 * s), P.y + P.h - N(P.footH / 2), 4,
        "Up/Down select  \194\183  Left/Right change  \194\183  Esc close", N(10 * s), C.dim))
    local by = P.y + P.h - P.footH + N(6 * s)
    local bw, bh = N(90 * s), N(28 * s)
    local closeX = P.x + P.w - bw - N(14 * s)
    local resetX = closeX - bw - N(8 * s)
    add(shape(rectp(closeX, by, bw, bh), C.accent, "FF"))
    add(text(closeX + bw / 2, by + bh / 2, 5, "Close", N(11 * s), C.white))
    add(shape(rectp(resetX, by, bw, bh), C.sel, "FF"))
    add(text(resetX + bw / 2, by + bh / 2, 5, "Reset", N(11 * s), C.text))

    overlay.data = table.concat(a, "\n")
    overlay.res_x = P.aw
    overlay.res_y = P.ah
    overlay:update()
    shown = true
end

local function open_prefs()
    if P.open then close(); return end
    P.open = true
    P.hit = {}
    layout()
    mp.commandv("script-message-to", "pot_ui", "pot-lock")
    for _, k in ipairs({ "ESC", "UP", "DOWN", "LEFT", "RIGHT", "ENTER", "KP_ENTER", "TAB",
        "MBTN_LEFT", "MBTN_LEFT_DBL", "MBTN_RIGHT", "WHEEL_UP", "WHEEL_DOWN" }) do
        mp.add_forced_key_binding(k, "pot-prefs-" .. k, function()
            if k == "ESC" then close()
            elseif k == "UP" then
                P.sel = clamp(P.sel - 1, 1, #rows())
                if P.sel < P.offset + 1 then P.offset = P.sel - 1 end
                schedule()
            elseif k == "DOWN" then
                local n = #rows()
                P.sel = clamp(P.sel + 1, 1, n)
                if P.sel > P.offset + P.maxrows then P.offset = P.sel - P.maxrows end
                schedule()
            elseif k == "TAB" then
                P.cat = (P.cat % #cats) + 1; P.sel = 1; P.offset = 0; schedule()
            elseif k == "LEFT" then set_row(rows()[P.sel] or {}, -1); schedule()
            elseif k == "RIGHT" then set_row(rows()[P.sel] or {}, 1); schedule()
            elseif k == "ENTER" or k == "KP_ENTER" then
                local row = rows()[P.sel]
                if row then set_row(row, 0); schedule() end
            elseif k == "MBTN_LEFT" or k == "MBTN_LEFT_DBL" then click()
            elseif k == "MBTN_RIGHT" then close()
            elseif k == "WHEEL_UP" or k == "WHEEL_DOWN" then
                P.offset = clamp(P.offset + (k == "WHEEL_UP" and -1 or 1), 0,
                    math.max(0, #rows() - P.maxrows))
                schedule()
            end
        end)
    end
    render()
end

mp.register_script_message("open", open_prefs)
mp.register_script_message("close", close)

-- baseline + persist
local function capture_baseline()
    for _, c in ipairs(cats) do
        for _, row in ipairs(c.rows()) do
            if row.prop then
                P.baseline[row.prop] = mp.get_property(row.prop) or ""
            elseif row.custom then
                if row.custom == "ui.scale" then P.baseline[row.custom] = num(o.scale, 2)
                elseif row.custom == "ui.hide" then P.baseline[row.custom] = tostring(N(o.hide_delay)) end
            end
        end
    end
end

capture_baseline()

mp.add_timeout(0.8, function()
    local f = io.open(conf_path(), "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^([^=]+)=(.*)$")
        if k and v and v ~= "" then
            apply_value(k, v)
            P.saved[k] = v
            if k == "ui.scale" then o.scale = tonumber(v) or o.scale end
            if k == "ui.hide" then o.hide_delay = tonumber(v) or o.hide_delay end
        end
    end
    f:close()
end)

mp.add_periodic_timer(0.4, function()
    if P.open then schedule() end
end)
