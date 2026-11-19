local mp = require "mp"
local opt = require "mp.options"
local utils = require "mp.utils"

local o = {
    font = "",
    scale = 1.0,
    accent = "3E9BD8",
    bar_alpha = "E8",
    hide_delay = 2500,
    playlist_width = 360,
    auto_load_folder = "yes",
}
opt.read_options(o, "pot")

local FONT = o.font
if FONT == "" then
    local pf = mp.get_property("platform") or "linux"
    if pf == "win" then FONT = "Segoe UI"
    elseif pf == "darwin" then FONT = "Helvetica Neue"
    else FONT = "Roboto" end
end

local C = {
    bg = "1B1B1B", panel = "141414", text = "E8E8E8", dim = "9C9C9C",
    accent = o.accent, hover = "2E2E2E", line = "000000",
    track = "3A3A3A", buf = "1F5C82", sel = "232323", white = "FFFFFF",
}

local function N(v) return math.floor(v + 0.5) end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function click_feedback(was_paused)
    mp.commandv("show-text", was_paused and "Play" or "Pause", 600)
end
local function now() return mp.get_time() end
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
    s = s:gsub("[\r\n]+", " ")
    return s
end
local function fmt_time(t)
    if not t or t < 0 then return "--:--" end
    t = math.floor(t)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end
local function fmt_speed(v)
    if not v then return "1x" end
    local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
    local t = string.format("%.2f", s):gsub("0$", "")
    return t .. "x"
end
local function basename(p)
    if not p then return "" end
    return (p:gsub("\\", "/"):match("([^/]+)$")) or p
end
local function ellipsize(s, size, maxw)
    if tw(s, size) <= maxw then return s end
    local n = math.floor(maxw / (size * 0.56)) - 1
    if n < 1 then return "" end
    return s:sub(1, n) .. "\226\128\166"
end

-- drawing helpers
local function poly(...)
    local t = { ... }
    local out = {}
    for i = 1, #t, 2 do
        out[#out + 1] = string.format("%s %d %d", i == 1 and "m" or "l", N(t[i]), N(t[i + 1]))
    end
    return table.concat(out, " ")
end
local function rectp(x, y, w, h) return poly(x, y, x + w, y, x + w, y + h, x, y + h) end
local function chreamp(x, y, w, h, r)
    r = math.min(r, math.min(w, h) / 2)
    return poly(x + r, y, x + w - r, y, x + w, y + r, x + w, y + h - r,
        x + w - r, y + h, x + r, y + h, x, y + h - r, x, y + r)
end
local function circp(cx, cy, r, n)
    n = n or 14
    local t = {}
    for i = 0, n do
        local a = i / n * math.pi * 2
        t[#t + 1] = string.format("%s %d %d", i == 0 and "m" or "l",
            N(cx + math.cos(a) * r), N(cy + math.sin(a) * r))
    end
    return table.concat(t, " ")
end
local function linep(x1, y1, x2, y2, t)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return "" end
    local nx, ny = -dy / len * t / 2, dx / len * t / 2
    return poly(x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny)
end
local function arcline(cx, cy, r, a0, a1, seg, t)
    local p = {}
    local prev
    for i = 0, seg do
        local a = math.rad(a0 + (a1 - a0) * i / seg)
        local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        if prev then p[#p + 1] = linep(prev[1], prev[2], x, y, t) end
        prev = { x, y }
    end
    return table.concat(p, " ")
end

local I = {}
local function ico_play(x, y, s, h, a)
    return shape(poly(x + s * .26, y + s * .12, x + s * .26, y + s * .88, x + s * .86, y + s * .5), h, a)
end
local function ico_pause(x, y, s, h, a)
    return shape(chreamp(x + s * .24, y + s * .14, s * .17, s * .72, s * .03) .. " " ..
        chreamp(x + s * .59, y + s * .14, s * .17, s * .72, s * .03), h, a)
end
local function ico_prev(x, y, s, h, a)
    return shape(poly(x + s * .78, y + s * .14, x + s * .78, y + s * .86, x + s * .26, y + s * .5) .. " " ..
        rectp(x + s * .14, y + s * .14, s * .08, s * .72), h, a)
end
local function ico_next(x, y, s, h, a)
    return shape(poly(x + s * .22, y + s * .14, x + s * .22, y + s * .86, x + s * .74, y + s * .5) .. " " ..
        rectp(x + s * .78, y + s * .14, s * .08, s * .72), h, a)
end
local function ico_stop(x, y, s, h, a)
    return shape(rectp(x + s * .24, y + s * .24, s * .52, s * .52), h, a)
end
local function ico_open(x, y, s, h, a)
    return shape(poly(x + s * .1, y + s * .3, x + s * .1, y + s * .78, x + s * .9, y + s * .78,
        x + s * .9, y + s * .36, x + s * .48, y + s * .36, x + s * .4, y + s * .25,
        x + s * .1, y + s * .25), h, a)
end
local function ico_vol(x, y, s, h, a, muted)
    local p = poly(x + s * .1, y + s * .38, x + s * .3, y + s * .38, x + s * .46, y + s * .2,
        x + s * .46, y + s * .8, x + s * .3, y + s * .62, x + s * .1, y + s * .62)
    if muted then
        p = p .. " " .. linep(x + s * .58, y + s * .38, x + s * .84, y + s * .62, s * .07)
            .. " " .. linep(x + s * .84, y + s * .38, x + s * .58, y + s * .62, s * .07)
    else
        p = p .. " " .. arcline(x + s * .48, y + s * .5, s * .16, -50, 50, 6, s * .07)
            .. " " .. arcline(x + s * .48, y + s * .5, s * .3, -50, 50, 8, s * .07)
    end
    return shape(p, h, a)
end
local function ico_sub(x, y, s, h, a)
    local x0, y0, w, hh, t = x + s * .08, y + s * .24, s * .84, s * .52, s * .07
    return shape(
        linep(x0 + t, y0, x0 + w - t, y0, t) .. " " ..
        linep(x0 + w, y0 + t, x0 + w, y0 + hh - t, t) .. " " ..
        linep(x0 + w - t, y0 + hh, x0 + t, y0 + hh, t) .. " " ..
        linep(x0, y0 + hh - t, x0, y0 + t, t) .. " " ..
        linep(x0 + s * .17, y0 + hh * .38, x0 + w - s * .17, y0 + hh * .38, t * .8) .. " " ..
        linep(x0 + s * .17, y0 + hh * .66, x0 + w - s * .32, y0 + hh * .66, t * .8), h, a)
end
local function ico_aud(x, y, s, h, a)
    return shape(circp(x + s * .3, y + s * .72, s * .13, 10) .. " " ..
        rectp(x + s * .39, y + s * .2, s * .07, s * .52) .. " " ..
        poly(x + s * .46, y + s * .2, x + s * .72, y + s * .3, x + s * .72, y + s * .42,
            x + s * .46, y + s * .33), h, a)
end
local function ico_list(x, y, s, h, a)
    local p = ""
    for i = 0, 2 do
        local yy = y + s * (.25 + i * .25)
        p = p .. " " .. rectp(x + s * .26, yy, s * .58 * (i == 2 and .7 or 1), s * .08)
        p = p .. " " .. rectp(x + s * .1, yy, s * .08, s * .08)
    end
    return shape(p, h, a)
end
local function ico_prefs(x, y, s, h, a)
    local p = ""
    local knobs = { .3, .65, .45 }
    for i = 0, 2 do
        local yy = y + s * (.24 + i * .26)
        p = p .. " " .. rectp(x + s * .1, yy, s * .8, s * .06)
        p = p .. " " .. circp(x + s * (.1 + .8 * knobs[i + 1]), yy + s * .03, s * .1, 10)
    end
    return shape(p, h, a)
end
local function ico_fs(x, y, s, h, a)
    local t = s * .07
    local e, i = s * .06, s * .26
    local p = linep(x + e, y + e + i, x + e, y + e, t) .. " " .. linep(x + e, y + e, x + e + i, y + e, t)
    p = p .. " " .. linep(x + s - e - i, y + e, x + s - e, y + e, t) .. " " .. linep(x + s - e, y + e, x + s - e, y + e + i, t)
    p = p .. " " .. linep(x + e, y + s - e - i, x + e, y + s - e, t) .. " " .. linep(x + e, y + s - e, x + e + i, y + s - e, t)
    p = p .. " " .. linep(x + s - e - i, y + s - e, x + s - e, y + s - e, t) .. " " .. linep(x + s - e, y + s - e, x + s - e, y + s - e - i, t)
    return shape(p, h, a)
end
local function ico_close(x, y, s, h, a)
    return shape(linep(x + s * .22, y + s * .22, x + s * .78, y + s * .78, s * .08) ..
        " " .. linep(x + s * .78, y + s * .22, x + s * .22, y + s * .78, s * .08), h, a)
end

local S = {
    visible = false, playlist = false, locked = false, hover = nil,
    pl_off = 0, pl_index = -1, last_move = 0, last_click = nil, g = nil, L = nil,
}

local overlay = mp.create_osd_overlay("ass-events")
overlay.z = 1000
local shown = false
local dirty = true
local pending = false
local last_data, last_w, last_h

local function release()
    if shown then overlay:remove(); shown = false end
    last_data = nil
end

local function geom()
    local d = mp.get_property_native("osd-dimensions") or {}
    local W, H = d.w or 1280, d.h or 720
    local ml, mr, mt, mb = d.ml or 0, d.mr or 0, d.mt or 0, d.mb or 0
    local aw, ah = W - ml - mr, H - mt - mb
    if aw < 120 or ah < 90 then aw, ah = 1280, 720 end
    local s = clamp(o.scale, 0.7, 3.0)
    return { w = aw, h = ah, ml = ml, mt = mt, s = s }
end

local function build_layout(g)
    local s, w, h = g.s, g.w, g.h
    local barH = N(46 * s)
    local barTop = h - barH
    local pad = N(8 * s)
    local btnW = N(32 * s)
    local btnH = N(barH - 12 * s)
    local btnS = N(21 * s)
    local rowY = barTop + N(barH * 0.5) + N(2 * s)
    local L = { barTop = barTop, barH = barH, rowY = rowY, buttons = {}, s = s }
    local bx = pad
    for _, id in ipairs({ "prev", "play", "next", "stop", "open" }) do
        L.buttons[#L.buttons + 1] = { id = id, x = bx, w = btnW, h = btnH, s = btnS }
        bx = bx + btnW
    end
    L.timeX = bx + N(6 * s)
    L.seek = { x = 0, y = barTop + N(1 * s), w = w, h = math.max(2, N(3 * s)), hit = N(9 * s) }
    local rx = w - pad
    local function rbtn(id, wd)
        rx = rx - wd
        L.buttons[#L.buttons + 1] = { id = id, x = rx, w = wd, h = btnH, s = btnS }
    end
    rbtn("fs", btnW); rbtn("prefs", btnW); rbtn("playlist", btnW)
    rbtn("speed", N(46 * s)); rbtn("sub", btnW); rbtn("aud", btnW)
    if w > 700 * s then
        local vw = N(72 * s)
        rx = rx - N(10 * s) - vw
        L.vol = { x = rx, y = rowY - math.max(1, N(2 * s)), w = vw, h = math.max(2, N(4 * s)) }
        rx = rx - N(2 * s) - btnW
        L.buttons[#L.buttons + 1] = { id = "vol", x = rx, w = btnW, h = btnH, s = btnS }
    end
    if S.playlist then
        local pw = N(math.min(o.playlist_width * s, w * 0.6))
        local head = N(40 * s)
        local rowH = N(30 * s)
        local px = w - pw
        local ph = barTop
        local rows = math.max(1, math.floor((ph - head - N(8 * s)) / rowH))
        L.pl = {
            x = px, y = 0, w = pw, h = ph, head = head, rowH = rowH, rows = rows,
            rowsY = head, close = { x = px + pw - N(34 * s), y = N(6 * s), w = N(28 * s), h = N(28 * s) },
        }
    end
    return L
end

local function hover_layout(L, s)
    local hov = nil
    if not S.mx then return nil end
    local mx, my = S.mx, S.my
    if L.pl then
        local pl = L.pl
        if mx >= pl.x and my <= pl.h then
            if mx >= pl.close.x and mx <= pl.close.x + pl.close.w and my >= pl.close.y and my <= pl.close.y + pl.close.h then
                return "pl-close"
            end
            if my >= pl.rowsY then
                local idx = S.pl_off + math.floor((my - pl.rowsY) / pl.rowH) + 1
                local list = mp.get_property_native("playlist") or {}
                if idx >= 1 and idx <= #list then return "pl-item:" .. idx end
            end
            return "pl"
        end
    end
    for _, b in ipairs(L.buttons) do
        if mx >= b.x and mx <= b.x + b.w and my >= L.rowY - b.h / 2 and my <= L.rowY + b.h / 2 then
            return b.id
        end
    end
    if my >= L.seek.y - L.seek.hit and my <= L.seek.y + L.seek.hit + N(2 * s) then return "seek" end
    if L.vol and mx >= L.vol.x - N(4 * s) and mx <= L.vol.x + L.vol.w + N(4 * s)
        and math.abs(my - L.rowY) <= N(12 * s) then return "volslider" end
    return hov
end

local function sync_state()
    pcall(mp.set_property_native, "user-data/pot-playlist", S.playlist)
end

local render

local function schedule()
    if pending then return end
    pending = true
    mp.add_timeout(0.03, function() pending = false; render() end)
end

local function toggle_playlist()
    S.playlist = not S.playlist
    sync_state()
    dirty = true
    schedule()
end

local function open_sub(sub, x, y)
    mp.commandv("script-message-to", "pot_menu", "open-sub", sub, tostring(N(x)), tostring(N(y)))
end

local function do_button(id, b)
    if id == "prev" then mp.commandv("playlist-prev")
    elseif id == "next" then mp.commandv("playlist-next")
    elseif id == "play" then mp.commandv("cycle", "pause")
    elseif id == "stop" then mp.commandv("stop")
    elseif id == "open" then mp.commandv("script-message-to", "pot_menu", "open-file")
    elseif id == "fs" then mp.commandv("cycle", "fullscreen")
    elseif id == "prefs" then mp.commandv("script-message-to", "pot_prefs", "open")
    elseif id == "playlist" then toggle_playlist()
    elseif id == "vol" then mp.commandv("cycle", "mute")
    elseif id == "speed" then open_sub("speed", b and b.x or S.mx, (S.L.barTop or 0) - 10)
    elseif id == "sub" then open_sub("subtitles", b and b.x or S.mx, (S.L.barTop or 0) - 10)
    elseif id == "aud" then open_sub("audio", b and b.x or S.mx, (S.L.barTop or 0) - 10)
    end
end

local function click()
    if S.locked then return end
    local g = geom(); S.g = g
    local p = mp.get_property_native("mouse-pos")
    if p then S.mx, S.my = p.x - g.ml, p.y - g.mt end
    S.last_move = now()
    S.visible = true
    local L = S.L or build_layout(g)
    local s = g.s
    if not S.mx then
        local prev = mp.get_property_native("pause")
        mp.commandv("cycle", "pause")
        click_feedback(prev)
        return
    end
    local mx, my = S.mx, S.my
    if L.pl and S.playlist and mx >= L.pl.x and my <= L.pl.h then
        local pl = L.pl
        if mx >= pl.close.x and mx <= pl.close.x + pl.close.w and my >= pl.close.y and my <= pl.close.y + pl.close.h then
            S.playlist = false; sync_state(); dirty = true; return
        end
        if my >= pl.rowsY then
            local idx = S.pl_off + math.floor((my - pl.rowsY) / pl.rowH) + 1
            local list = mp.get_property_native("playlist") or {}
            if idx >= 1 and idx <= #list then
                mp.commandv("playlist-play-index", tostring(idx - 1))
            end
        end
        return
    end
    if my < L.barTop - N(2 * s) then
        local prev = mp.get_property_native("pause")
        mp.commandv("cycle", "pause")
        S.last_click = { t = now(), prev = prev }
        click_feedback(prev)
        return
    end
    if my <= L.seek.y + L.seek.hit then
        local dur = mp.get_property_number("duration")
        if dur and dur > 0 then
            mp.commandv("seek", string.format("%.3f", clamp(mx / L.seek.w, 0, 1) * dur), "absolute")
        end
        return
    end
    if L.vol and mx >= L.vol.x - N(2 * s) and mx <= L.vol.x + L.vol.w + N(2 * s)
        and math.abs(my - L.rowY) <= N(12 * s) then
        local vmax = mp.get_property_number("volume-max") or 130
        local frac = clamp((mx - L.vol.x) / L.vol.w, 0, 1)
        mp.set_property_number("volume", N(frac * vmax))
        return
    end
    for _, b in ipairs(L.buttons) do
        if mx >= b.x and mx <= b.x + b.w and my >= L.rowY - b.h / 2 and my <= L.rowY + b.h / 2 then
            do_button(b.id, b)
            return
        end
    end
    local prev = mp.get_property_native("pause")
    mp.commandv("cycle", "pause")
    S.last_click = { t = now(), prev = prev }
    click_feedback(prev)
end

local function dblclick()
    if S.locked then return end
    if S.last_click and now() - S.last_click.t < 0.45 then
        pcall(mp.set_property_native, "pause", S.last_click.prev)
        S.last_click = nil
    end
    mp.commandv("cycle", "fullscreen")
end

local function wheel(dir, mod)
    if S.locked then return end
    local g = geom(); S.g = g
    local p = mp.get_property_native("mouse-pos")
    if p then S.mx, S.my = p.x - g.ml, p.y - g.mt end
    local L = S.L
    if S.playlist and L and L.pl and S.mx and S.mx >= L.pl.x and S.my <= L.pl.h then
        local list = mp.get_property_native("playlist") or {}
        local maxoff = math.max(0, #list - L.pl.rows)
        S.pl_off = clamp(S.pl_off + (dir == "up" and -3 or 3), 0, maxoff)
        dirty = true
        return
    end
    if mod == "shift" then
        mp.commandv("seek", dir == "up" and "30" or "-30")
    elseif mod == "ctrl" then
        mp.commandv("add", "speed", dir == "up" and "0.1" or "-0.1")
    elseif L and S.my and S.my >= L.barTop - N(4 * g.s) then
        mp.commandv("seek", dir == "up" and "5" or "-5")
    else
        mp.commandv("add", "volume", dir == "up" and "2" or "-2")
    end
    S.last_move = now()
end

local function toggle_pause()
    mp.commandv("cycle", "pause")
end

render = function()
    local g = geom(); S.g = g
    local s, w, h = g.s, g.w, g.h
    if S.locked then release(); return end
    local L = build_layout(g)
    S.L = L
    local list = mp.get_property_native("playlist") or {}
    local pp = mp.get_property_number("playlist-pos") or -1
    if pp ~= S.pl_index then
        S.pl_index = pp
        if S.playlist then
            local maxoff = math.max(0, #list - L.pl.rows)
            S.pl_off = clamp(pp - math.floor(L.pl.rows / 2), 0, maxoff)
        end
    end
    if S.playlist then
        S.pl_off = clamp(S.pl_off, 0, math.max(0, #list - L.pl.rows))
    end
    S.hover = hover_layout(L, s)
    local show = S.visible or S.playlist
    if not show then release(); return end

    local a = {}
    local function add(x) if x and x ~= "" then a[#a + 1] = x end end
    local function ev(txt) add(txt) end

    -- playlist panel
    if L.pl then
        local pl = L.pl
        add(shape(rectp(pl.x, 0, pl.w, pl.h), C.panel, "F2"))
        add(shape(rectp(pl.x, 0, N(1 * s), pl.h), C.line, "70"))
        add(shape(rectp(pl.x, pl.head - N(1 * s), pl.w, N(1 * s)), C.accent, "80"))
        add(text(pl.x + N(14 * s), N(20 * s), 4, "Playlist (" .. #list .. ")", N(12 * s), C.text, nil, true))
        if S.hover == "pl-close" then
            add(shape(chreamp(pl.close.x, pl.close.y, pl.close.w, pl.close.h, N(4 * s)), C.hover, "C0"))
        end
        add(ico_close(pl.close.x + N(6 * s), pl.close.y + N(6 * s), N(16 * s), C.dim))
        local maxoff = math.max(0, #list - pl.rows)
        local first = S.pl_off + 1
        local last = math.min(#list, S.pl_off + pl.rows)
        for i = first, last do
            local e = list[i] or {}
            local y = pl.rowsY + (i - 1 - S.pl_off) * pl.rowH
            local cur = (i - 1 == pp)
            if S.hover == ("pl-item:" .. i) then
                add(shape(rectp(pl.x, y, pl.w, pl.rowH), C.hover, "90"))
            elseif cur then
                add(shape(rectp(pl.x, y, pl.w, pl.rowH), C.sel, "E0"))
            end
            if cur then add(shape(rectp(pl.x, y, N(3 * s), pl.rowH), C.accent)) end
            local title = e.title and e.title ~= "" and e.title or basename(e.filename)
            add(text(pl.x + N(12 * s), y + N(pl.rowH / 2), 4, tostring(i), N(10 * s), C.dim))
            local avail = pl.w - N(56 * s)
            add(text(pl.x + N(38 * s), y + N(pl.rowH / 2), 4, esc(ellipsize(title, N(12 * s), avail)), N(12 * s), cur and C.text or C.dim))
        end
        if maxoff > 0 then
            local tx = pl.x + pl.w - N(5 * s)
            local th = pl.h - pl.rowsY - N(8 * s)
            add(shape(rectp(tx, pl.rowsY, N(2 * s), th), C.track, "80"))
            local sh = math.max(N(18 * s), N(th * pl.rows / #list))
            local sy = pl.rowsY + N((th - sh) * (S.pl_off / maxoff))
            add(shape(rectp(tx, sy, N(2 * s), sh), C.accent, "C0"))
        end
    end

    -- bar
    add(shape(rectp(0, L.barTop, w, L.barH), C.bg, o.bar_alpha))
    add(shape(rectp(0, L.barTop, w, N(1 * s)), C.line, "90"))

    -- seek bar
    local dur = mp.get_property_number("duration") or 0
    local pos = mp.get_property_number("time-pos") or 0
    local frac = dur > 0 and clamp(pos / dur, 0, 1) or 0
    local sh = L.seek.h
    if S.hover == "seek" then sh = math.max(sh, N(5 * s)) end
    local sy = L.seek.y - (sh - L.seek.h) / 2
    add(shape(rectp(0, N(sy), w, N(sh)), C.track, "A0"))
    local ct = mp.get_property_number("demuxer-cache-time") or 0
    if ct > 0 and dur > 0 then
        add(shape(rectp(0, N(sy), N(w * clamp(ct / dur, 0, 1)), N(sh)), C.buf, "C0"))
    end
    local chapters = mp.get_property_native("chapter-list") or {}
    for _, ch in ipairs(chapters) do
        if dur > 0 and ch.time and ch.time > 0 then
            local cx = N(w * clamp(ch.time / dur, 0, 1))
            add(shape(rectp(cx, N(sy), math.max(1, N(1 * s)), N(sh)), C.white, "70"))
        end
    end
    add(shape(rectp(0, N(sy), N(w * frac), N(sh)), C.accent))
    if S.hover == "seek" and S.mx then
        add(shape(circp(S.mx, sy + sh / 2, math.max(3, N(5 * s)), 12), C.accent))
        local tpos = clamp(S.mx / w, 0, 1) * dur
        local lbl = fmt_time(tpos)
        for _, ch in ipairs(chapters) do
            if ch.time and tpos >= ch.time then
                lbl = lbl .. "  " .. esc(ch.title or "")
            end
        end
        local bw = tw(lbl, N(11 * s)) + N(16 * s)
        local bx = clamp(S.mx - bw / 2, N(4 * s), w - bw - N(4 * s))
        local by = L.barTop - N(28 * s)
        add(shape(chreamp(bx, by, bw, N(22 * s), N(4 * s)), "000000", "A0"))
        add(text(bx + bw / 2, by + N(11 * s), 5, lbl, N(11 * s), C.text))
    end

    -- time
    add(text(L.timeX, L.rowY, 4, fmt_time(pos), N(13 * s), C.text))
    add(text(L.timeX + tw(fmt_time(pos), N(13 * s)) + N(6 * s), L.rowY, 4,
        "/ " .. fmt_time(dur), N(12 * s), C.dim))

    -- buttons
    local paused = mp.get_property_native("pause")
    local eof = mp.get_property_native("eof-reached")
    for _, b in ipairs(L.buttons) do
        local hov = S.hover == b.id
        local ix = b.x + (b.w - b.s) / 2
        local iy = L.rowY - b.s / 2
        if hov then
            add(shape(chreamp(b.x, L.rowY - b.h / 2, b.w, b.h, N(4 * s)), C.hover, "D0"))
        end
        local hc = hov and C.white or C.text
        if b.id == "play" then
            add((paused or eof) and ico_play(ix, iy, b.s, hc) or ico_pause(ix, iy, b.s, hc))
        elseif b.id == "prev" then add(ico_prev(ix, iy, b.s, hc))
        elseif b.id == "next" then add(ico_next(ix, iy, b.s, hc))
        elseif b.id == "stop" then add(ico_stop(ix, iy, b.s, hc))
        elseif b.id == "open" then add(ico_open(ix, iy, b.s, hc))
        elseif b.id == "fs" then
            local fs = mp.get_property_native("fullscreen")
            add(ico_fs(ix, iy, b.s, fs and C.accent or hc))
        elseif b.id == "prefs" then add(ico_prefs(ix, iy, b.s, hc))
        elseif b.id == "playlist" then add(ico_list(ix, iy, b.s, S.playlist and C.accent or hc))
        elseif b.id == "sub" then
            local sid = mp.get_property_number("sid")
            add(ico_sub(ix, iy, b.s, sid and C.accent or (hov and C.white or C.dim)))
        elseif b.id == "aud" then
            local aid = mp.get_property_number("aid")
            add(ico_aud(ix, iy, b.s, aid and (hov and C.white or C.text) or C.dim))
        elseif b.id == "vol" then
            add(ico_vol(ix, iy, b.s, mp.get_property_native("mute") and C.accent or hc,
                mp.get_property_native("mute")))
        elseif b.id == "speed" then
            add(text(b.x + b.w / 2, L.rowY, 5, fmt_speed(mp.get_property_number("speed")),
                N(11 * s), hov and C.white or C.dim))
        end
    end

    if L.vol then
        local vmax = mp.get_property_number("volume-max") or 130
        local vol = mp.get_property_number("volume") or 0
        local vf = clamp(vol / vmax, 0, 1)
        add(shape(rectp(L.vol.x, L.vol.y, L.vol.w, L.vol.h), C.track, "A0"))
        add(shape(rectp(L.vol.x, L.vol.y, N(L.vol.w * vf), L.vol.h),
            mp.get_property_native("mute") and C.dim or C.accent))
        if S.hover == "volslider" then
            add(shape(circp(L.vol.x + L.vol.w * vf, L.vol.y + L.vol.h / 2, math.max(3, N(4 * s)), 12), C.white))
        end
    end

    local data = table.concat(a, "\n")
    if data ~= last_data or w ~= last_w or h ~= last_h or not shown then
        overlay.data = data
        overlay.res_x = w
        overlay.res_y = h
        overlay:update()
        shown = true
        last_data, last_w, last_h = data, w, h
    end
end

local function on_mouse(_, p)
    if not p or not p.x then return end
    local g = S.g or geom()
    S.g = g
    S.mx, S.my = p.x - g.ml, p.y - g.mt
    S.last_move = now()
    if not S.locked then
        S.visible = true
        dirty = true
        schedule()
    end
end

mp.observe_property("mouse-pos", "native", on_mouse)
for _, p in ipairs({
    "pause", "duration", "volume", "mute", "speed", "playlist", "playlist-pos",
    "media-title", "fullscreen", "chapter-list", "sub-visibility", "aid", "sid",
    "eof-reached", "video-rotate", "ontop",
}) do
    mp.observe_property(p, "native", function() dirty = true; if S.visible or S.playlist then schedule() end end)
end

mp.add_periodic_timer(0.2, function()
    if S.locked then return end
    local g = geom(); S.g = g
    local over = false
    if S.mx and S.L then
        local L = S.L
        if S.my >= L.barTop - N(8 * g.s) then over = true end
        if S.playlist and L.pl and S.mx >= L.pl.x then over = true end
    end
    local vis = (now() - S.last_move < o.hide_delay / 1000) or over or S.playlist
    if vis ~= S.visible then S.visible = vis; dirty = true end
    if vis and not mp.get_property_native("pause") then
        local t = mp.get_property_number("time-pos") or 0
        if math.floor(t) ~= math.floor(S.last_t or -1) then S.last_t = t; dirty = true end
    end
    if dirty then dirty = false; render() end
end)

local MEDIA_EXT = {
    mp4=true, mkv=true, avi=true, mov=true, webm=true, flv=true, wmv=true, m4v=true,
    mpg=true, mpeg=true, ts=true, m2ts=true, ogv=true, ogm=true, ["3gp"]=true, ["3g2"]=true,
    vob=true, divx=true, rmvb=true, asf=true, xvid=true, mts=true, f4v=true,
}

local last_auto_dir = nil

local function auto_load_folder(path)
    if o.auto_load_folder ~= "yes" then return end
    if not path or path == "" or path:match("^%a[%w+.-]*://") then return end
    local dir, base = path:match("^(.*)[/\\]([^/\\]+)$")
    if not dir then return end
    local list = mp.get_property_native("playlist") or {}
    if #list > 1 or dir == last_auto_dir then last_auto_dir = dir; return end
    local files = utils.readdir(dir, "files") or {}
    local names = {}
    for _, f in ipairs(files) do
        local ext = tostring(f):match("%.([%w]+)$")
        if ext and MEDIA_EXT[ext:lower()] then names[#names + 1] = f end
    end
    table.sort(names)
    local n = 0
    for _, f in ipairs(names) do
        if f ~= base and n < 300 then
            mp.commandv("loadfile", dir .. "/" .. f, "append")
            n = n + 1
        end
    end
    last_auto_dir = dir
    if n > 0 then
        dirty = true
        if S.visible then schedule() end
    end
end

mp.observe_property("path", "string", function(_, p) auto_load_folder(p) end)

mp.register_script_message("pot-click", click)
mp.register_script_message("pot-dblclick", dblclick)
mp.register_script_message("pot-mid", toggle_playlist)
mp.register_script_message("pot-wheel", wheel)
mp.register_script_message("pot-lock", function() S.locked = true; release() end)
mp.register_script_message("pot-unlock", function() S.locked = false; S.visible = false; S.last_move = 0 end)
mp.register_script_message("pot-toggle-playlist", toggle_playlist)
mp.register_script_message("pot-setopt", function(k, v)
    if k == "scale" then o.scale = tonumber(v) or o.scale
    elseif k == "hide_delay" then o.hide_delay = tonumber(v) or o.hide_delay
    elseif k == "auto_load_folder" then o.auto_load_folder = v end
    dirty = true
    schedule()
end)
mp.register_script_message("pot-open", function() mp.commandv("script-message-to", "pot_menu", "open-file") end)

mp.add_timeout(1, function() dirty = true; render() end)
