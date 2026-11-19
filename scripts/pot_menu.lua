local mp = require "mp"
local opt = require "mp.options"

local o = { font = "", scale = 1.0, accent = "3E9BD8", bar_alpha = "E8", hide_delay = 2500, playlist_width = 360,
    osub_api_key = "", osub_user = "", osub_pass = "", osub_lang = "eng", auto_load_folder = "yes" }
opt.read_options(o, "pot")

local FONT = o.font
if FONT == "" then
    local pf = mp.get_property("platform") or "linux"
    if pf == "win" then FONT = "Segoe UI"
    elseif pf == "darwin" then FONT = "Helvetica Neue"
    else FONT = "Roboto" end
end

local C = {
    bg = "232323", border = "4A4A4A", text = "E8E8E8", dim = "9A9A9A",
    accent = o.accent, hover = "3E9BD8", sep = "3A3A3A", shadow = "000000",
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
local function linep(x1, y1, x2, y2, t)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return "" end
    local nx, ny = -dy / len * t / 2, dx / len * t / 2
    return poly(x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny)
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
local function check(x, y, s, hex)
    return shape(poly(x + s * .1, y + s * .52, x + s * .26, y + s * .36, x + s * .38, y + s * .5,
        x + s * .66, y + s * .16, x + s * .8, y + s * .3, x + s * .38, y + s * .74), hex)
end
local function chev(x, y, s, hex)
    return shape(linep(x + s * .25, y + s * .2, x + s * .62, y + s * .5, s * .09) ..
        " " .. linep(x + s * .62, y + s * .5, x + s * .25, y + s * .8, s * .09), hex)
end

local M = { open = false, pages = {}, w = 1280, h = 720, s = 1, ml = 0, mt = 0,
    hover_idx = nil, sub_key = nil, sub_timer = nil }

local overlay = mp.create_osd_overlay("ass-events")
overlay.z = 1100
local shown = false
local pending = false
local last_data, last_w, last_h

local function geom()
    local d = mp.get_property_native("osd-dimensions") or {}
    local W, H = d.w or 1280, d.h or 720
    local ml, mr, mt, mb = d.ml or 0, d.mr or 0, d.mt or 0, d.mb or 0
    local aw, ah = W - ml - mr, H - mt - mb
    if aw < 120 or ah < 90 then aw, ah = 1280, 720 end
    M.w, M.h, M.ml, M.mt = aw, ah, ml, mt
    M.s = clamp(o.scale, 0.7, 3.0)
end

local function mouse()
    local p = mp.get_property_native("mouse-pos")
    if not p or not p.x then return nil end
    return p.x - M.ml, p.y - M.mt
end

local function build_page(items)
    local s = M.s
    local itemh = N(26 * s)
    local seph = N(7 * s)
    local maxw = 0
    for _, it in ipairs(items) do
        if not it.sep then
            local w = tw(it.label or "", 13 * s) + N(46 * s)
            if it.accel then w = w + tw(it.accel, 11 * s) + N(20 * s) end
            if it.submenu then w = w + N(16 * s) end
            if w > maxw then maxw = w end
        end
    end
    local w = clamp(maxw, N(200 * s), N(470 * s))
    local lines = {}
    local y = N(5 * s)
    for _, it in ipairs(items) do
        local h = it.sep and seph or itemh
        lines[#lines + 1] = { item = it, y = y, h = h }
        y = y + h
    end
    local page = { items = items, lines = lines, w = w, h = y + N(5 * s), itemh = itemh,
        seph = seph, offset = 0, sel = 1, drawn = {} }
    for i, l in ipairs(page.lines) do
        if not l.item.sep then page.sel = i; break end
    end
    return page
end

local function vis_h()
    return M.h - N(12 * M.s)
end

local function layout_page(page, anchor_y)
    local s = M.s
    local avail = vis_h() - N(10 * s)
    page.drawn = {}
    local y = 0
    local used = 0
    for i = page.offset + 1, #page.lines do
        local l = page.lines[i]
        if used + l.h > avail then break end
        page.drawn[#page.drawn + 1] = { line = l, y = y, h = l.h, idx = i }
        used = used + l.h
        y = y + l.h
    end
    page.vis = used + N(10 * s)
end

local function place(page, px, py)
    local s = M.s
    page.x = clamp(px, N(4 * s), math.max(N(4 * s), M.w - page.w - N(4 * s)))
    page.y = clamp(py, N(4 * s), math.max(N(4 * s), M.h - page.vis - N(4 * s)))
end

local render

local function schedule()
    if pending then return end
    pending = true
    mp.add_timeout(0.03, function() pending = false; render() end)
end

local function close()
    if not M.open then return end
    last_data = nil
    M.open = false
    M.pages = {}
    M.hover_idx = nil
    M.sub_key = nil
    if M.sub_timer then M.sub_timer:stop(); M.sub_timer = nil end
    if shown then overlay:remove(); shown = false end
    for _, k in ipairs({ "ESC", "UP", "DOWN", "LEFT", "RIGHT", "ENTER", "KP_ENTER",
        "MBTN_LEFT", "MBTN_LEFT_DBL", "MBTN_RIGHT", "MBTN_MID", "WHEEL_UP", "WHEEL_DOWN" }) do
        mp.remove_key_binding("pot-menu-" .. k)
    end
    mp.commandv("script-message-to", "pot_ui", "pot-unlock")
end

local function first_selectable(page, from, dir)
    local i = from
    while i >= 1 and i <= #page.lines do
        if not page.lines[i].item.sep and not page.lines[i].item.disabled then return i end
        i = i + dir
    end
    return from
end

local function ensure_visible(page)
    layout_page(page)
    local first, last = nil, nil
    for _, d in ipairs(page.drawn) do first = first or d.idx; last = d.idx end
    if not first then return end
    if page.sel < first then
        page.offset = page.sel - 1
    elseif page.sel > last then
        local off = math.max(0, page.sel - 1)
        while off >= 0 do
            page.offset = off
            layout_page(page)
            local l2 = nil
            for _, d in ipairs(page.drawn) do l2 = d.idx end
            if page.sel <= (l2 or 0) then break end
            off = off - 1
        end
    end
    layout_page(page)
end

local function open_sub(page, idx)
    local line = page.lines[idx]
    if not line or not line.item.submenu then return end
    local items = line.item.submenu()
    if not items or #items == 0 then return end
    local child = build_page(items)
    layout_page(child)
    local s = M.s
    local px = page.x + page.w - N(4 * s)
    if px + child.w > M.w - N(4 * s) then px = page.x - child.w + N(4 * s) end
    local py = page.y + N(5 * s) + (line.y or 0) - N(6 * s)
    place(child, px, py)
    local base = 0
    for i = 1, #M.pages do if M.pages[i] == page then base = i end end
    while #M.pages > base do table.remove(M.pages) end
    M.pages[#M.pages + 1] = child
    M.hover_idx = nil
    M.sub_key = nil
    render()
end

local function activate(page, idx)
    local it = page.lines[idx] and page.lines[idx].item
    if not it or it.sep or it.disabled then return end
    if it.submenu then open_sub(page, idx); return end
    if it.action then
        close()
        local ok, err = pcall(it.action)
        if not ok then mp.msg.error("menu action failed: " .. tostring(err)) end
    end
end

local function move_sel(dir)
    local page = M.pages[#M.pages]
    if not page then return end
    local i = page.sel
    for _ = 1, #page.lines do
        i = i + dir
        if i < 1 or i > #page.lines then return end
        if not page.lines[i].item.sep and not page.lines[i].item.disabled then
            page.sel = i
            ensure_visible(page)
            render()
            return
        end
    end
end

local function update_hover()
    local mx, my = mouse()
    if not mx then return nil end
    M.hover_idx = nil
    for i = #M.pages, 1, -1 do
        local p = M.pages[i]
        if mx >= p.x and mx <= p.x + p.w and my >= p.y and my <= p.y + p.vis then
            if i < #M.pages then
                while #M.pages > i do table.remove(M.pages) end
            end
            local top = p.y + N(5 * M.s)
            for _, d in ipairs(p.drawn) do
                if my >= top + d.y and my < top + d.y + d.h then
                    p.sel = d.idx
                    M.hover_idx = d.idx
                    M.hover_page = p
                    return d, p, i
                end
            end
            M.hover_page = p
            return nil, p, i
        end
    end
    M.hover_page = nil
    return nil
end

local function maybe_submenu()
    update_hover()
    local top = M.pages[#M.pages]
    if not top then return end
    local line = top.lines[top.sel]
    if not line or not line.item.submenu then return end
    if #M.pages > 1 then return end
    local key = tostring(top.sel)
    if M.sub_key == key then return end
    M.sub_key = key
    if M.sub_timer then M.sub_timer:stop() end
    M.sub_timer = mp.add_timeout(0.18, function()
        M.sub_timer = nil
        if not M.open then return end
        if M.hover_idx == tonumber(key) then open_sub(top, tonumber(key)) end
    end)
end

local function open(items, px, py)
    geom()
    M.open = true
    M.pages = {}
    M.hover_idx = nil
    M.sub_key = nil
    if M.sub_timer then M.sub_timer:stop(); M.sub_timer = nil end
    local page = build_page(items)
    layout_page(page)
    place(page, px, py)
    M.pages[1] = page
    mp.commandv("script-message-to", "pot_ui", "pot-lock")
    for _, k in ipairs({ "ESC", "UP", "DOWN", "LEFT", "RIGHT", "ENTER", "KP_ENTER",
        "MBTN_LEFT", "MBTN_LEFT_DBL", "MBTN_RIGHT", "MBTN_MID", "WHEEL_UP", "WHEEL_DOWN" }) do
        mp.add_forced_key_binding(k, "pot-menu-" .. k, function()
            if k == "ESC" then close()
            elseif k == "UP" then move_sel(-1)
            elseif k == "DOWN" then move_sel(1)
            elseif k == "LEFT" then
                if #M.pages > 1 then table.remove(M.pages); render()
                else close() end
            elseif k == "RIGHT" then
                local p = M.pages[#M.pages]
                if p then open_sub(p, p.sel) end
            elseif k == "ENTER" or k == "KP_ENTER" then
                local p = M.pages[#M.pages]
                if p then activate(p, p.sel) end
            elseif k == "MBTN_LEFT" or k == "MBTN_LEFT_DBL" then
                local d, p, pi = update_hover()
                if not p then close(); return end
                if pi < #M.pages then table.remove(M.pages); render(); return end
                if d then activate(p, d.idx) end
            elseif k == "MBTN_RIGHT" or k == "MBTN_MID" then
                close()
            elseif k == "WHEEL_UP" or k == "WHEEL_DOWN" then
                local d, p = update_hover()
                if p then
                    local avail = vis_h() - N(10 * M.s)
                    if p.h > avail then
                        p.offset = clamp(p.offset + (k == "WHEEL_UP" and -1 or 1), 0, math.max(0, #p.lines - 1))
                        layout_page(p)
                        render()
                    end
                end
            end
        end)
    end
    render()
end

render = function()
    if not M.open then return end
    geom()
    if not M.pages[1] then return end
    for _, p in ipairs(M.pages) do layout_page(p) end
    local a = {}
    local function add(x) if x and x ~= "" then a[#a + 1] = x end end
    local function ev(txt) add(txt) end

    for i, p in ipairs(M.pages) do
        local s = M.s
        add(shape(rectp(p.x + N(4 * s), p.y + N(4 * s), p.w, p.vis), C.shadow, "88"))
        add(shape(rectp(p.x, p.y, p.w, p.vis), C.bg, "F6"))
        add(shape(rectp(p.x, p.y, p.w, N(1 * s)), C.border, "D0"))
        add(shape(rectp(p.x, p.y + p.vis - N(1 * s), p.w, N(1 * s)), C.border, "D0"))
        local top = p.y + N(5 * s)
        for _, d in ipairs(p.drawn) do
            local it = d.line.item
            local y = top + d.y
            if it.sep then
                add(shape(rectp(p.x + N(10 * s), y + math.floor(d.h / 2), p.w - N(20 * s), math.max(1, N(1 * s))), C.sep, "C0"))
            else
                local hov = (i == #M.pages) and (d.idx == p.sel)
                if hov then
                    add(shape(rectp(p.x, y, p.w, d.h), C.hover, "E6"))
                end
                local hc = hov and "FFFFFF" or C.text
                if it.disabled then hc = C.dim end
                local tx = p.x + N(16 * s)
                if it.checked then
                    add(check(p.x + N(6 * s), y + N(d.h / 2) - N(7 * s), N(14 * s), hov and "FFFFFF" or C.accent))
                    tx = p.x + N(28 * s)
                end
                add(text(tx, y + N(d.h / 2), 4, esc(it.label), N(13 * s), hc))
                local rx = p.x + p.w - N(12 * s)
                if it.submenu then
                    add(chev(p.x + p.w - N(18 * s), y + N(d.h / 2) - N(7 * s), N(12 * s), hov and "FFFFFF" or C.dim))
                    rx = p.x + p.w - N(26 * s)
                end
                if it.accel then
                    add(text(rx, y + N(d.h / 2), 6, esc(it.accel), N(10 * s),
                        hov and "DDE8F0" or C.dim))
                end
            end
        end
        if #p.lines > #p.drawn and p.h > vis_h() then
            local th = p.vis - N(10 * s)
            local sh = math.max(N(18 * s), N(th * #p.drawn / #p.lines))
            local maxoff = math.max(1, #p.lines - #p.drawn)
            local sy = p.y + N(5 * s) + N((th - sh) * (p.offset / maxoff))
            add(shape(rectp(p.x + p.w - N(4 * s), p.y + N(5 * s), N(2 * s), th), C.sep, "80"))
            add(shape(rectp(p.x + p.w - N(4 * s), sy, N(2 * s), sh), C.accent, "C0"))
        end
    end
    local data = table.concat(a, "\n")
    if data ~= last_data or M.w ~= last_w or M.h ~= last_h or not shown then
        overlay.data = data
        overlay.res_x = M.w
        overlay.res_y = M.h
        overlay:update()
        shown = true
        last_data, last_w, last_h = data, M.w, M.h
    end
end

-- dialogs
local function pcall_show(msg) mp.commandv("show-text", msg, "4000") end

local function subprocess_capture(args)
    local r = mp.command_native({ name = "subprocess", args = args, capture_stdout = true,
        capture_stderr = false, playback_only = false })
    if r and r.status == 0 and r.stdout and r.stdout ~= "" then return r.stdout end
    return nil
end

local function dialog_files(multi)
    local pf = mp.get_property("platform")
    if pf == "win" then
        local ps = [[Add-Type -AssemblyName System.Windows.Forms;$d=New-Object System.Windows.Forms.OpenFileDialog;$d.Multiselect=$true;if($d.ShowDialog() -eq 'OK'){$d.FileNames -join "`n"}]]
        if not multi then
            ps = [[Add-Type -AssemblyName System.Windows.Forms;$d=New-Object System.Windows.Forms.OpenFileDialog;if($d.ShowDialog() -eq 'OK'){$d.FileName}]]
        end
        return subprocess_capture({ "powershell", "-NoProfile", "-STA", "-Command", ps })
    elseif pf == "darwin" then
        return subprocess_capture({ "osascript", "-e",
            'set f to choose file with multiple selections allowed\nset out to ""\nrepeat with x in f\nset out to out & POSIX path of x & linefeed\nend repeat\nreturn out' })
    else
        local out = subprocess_capture({ "zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Open media" })
        if out then return out end
        if multi then
            return subprocess_capture({ "kdialog", "--multiple", "--getopenfilename", "." })
        end
        return subprocess_capture({ "kdialog", "--getopenfilename", "." })
    end
end

local function dialog_dir()
    local pf = mp.get_property("platform")
    if pf == "win" then
        return subprocess_capture({ "powershell", "-NoProfile", "-STA", "-Command",
            [[Add-Type -AssemblyName System.Windows.Forms;$d=New-Object System.Windows.Forms.FolderBrowserDialog;if($d.ShowDialog() -eq 'OK'){$d.SelectedPath}]] })
    elseif pf == "darwin" then
        return subprocess_capture({ "osascript", "-e", 'POSIX path of (choose folder)' })
    else
        local out = subprocess_capture({ "zenity", "--file-selection", "--directory", "--title=Open folder" })
        if out then return out end
        return subprocess_capture({ "kdialog", "--getexistingdirectory", "." })
    end
end

local function dialog_url()
    local pf = mp.get_property("platform")
    if pf == "win" then
        return subprocess_capture({ "powershell", "-NoProfile", "-STA", "-Command",
            [[Add-Type -AssemblyName Microsoft.VisualBasic;[Microsoft.VisualBasic.Interaction]::InputBox('URL','Open URL','https://')]] })
    elseif pf == "darwin" then
        return subprocess_capture({ "osascript", "-e",
            'text returned of (display dialog "Open URL" default answer "https://" buttons {"OK"} default button 1)' })
    else
        local out = subprocess_capture({ "zenity", "--entry", "--title=Open URL", "--text=URL:" })
        if out then return out end
        return subprocess_capture({ "kdialog", "--inputbox", "Open URL", "https://" })
    end
end


local function dialog_save(defname)
    local pf = mp.get_property("platform")
    if pf == "win" then
        return subprocess_capture({ "powershell", "-NoProfile", "-STA", "-Command",
            'Add-Type -AssemblyName System.Windows.Forms;$d=New-Object System.Windows.Forms.SaveFileDialog;$d.Filter="M3U|*.m3u|All|*.*";$d.FileName="' .. (defname or "playlist.m3u") .. '";if($d.ShowDialog() -eq "OK"){$d.FileName}' })
    elseif pf == "darwin" then
        return subprocess_capture({ "osascript", "-e",
            'POSIX path of (choose file name with prompt "Save playlist" default name "' .. (defname or "playlist.m3u") .. '")' })
    else
        local out = subprocess_capture({ "zenity", "--file-selection", "--save", "--confirm-overwrite",
            "--title=Save playlist", "--filename=" .. (defname or "playlist.m3u") })
        if out then return out end
        return subprocess_capture({ "kdialog", "--getsavefilename", defname or "playlist.m3u", "*.m3u" })
    end
end

local function save_playlist()
    local list = mp.get_property_native("playlist") or {}
    if #list == 0 then pcall_show("Playlist is empty"); return end
    local title = mp.get_property("media-title") or "playlist"
    title = title:gsub("[\\/:*?\"<>|]", "_")
    local out = dialog_save(title .. ".m3u")
    if not out or out == "" then return end
    out = out:gsub("[\r\n]+$", "")
    local f = io.open(out, "w")
    if not f then pcall_show("Cannot write " .. out); return end
    f:write("#EXTM3U\n")
    for _, e in ipairs(list) do
        if e.filename and e.filename ~= "" then f:write(e.filename, "\n") end
    end
    f:close()
    pcall_show("Playlist saved")
end

local function add_media(paths, mode)
    if not paths then return end
    local first = true
    for line in paths:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local how = mode or "append-play"
            if first and (mode == nil or mode == "replace") then how = "replace" end
            mp.commandv("loadfile", line, how)
            first = false
        end
    end
    if first then pcall_show("Nothing selected") end
end

local function open_file(mode)
    if mode == "folder" then
        add_media(dialog_dir(), "replace")
    elseif mode == "add-folder" then
        add_media(dialog_dir(), "append-play")
    elseif mode == "url" then
        add_media(dialog_url(), "replace")
    elseif mode == "add" then
        add_media(dialog_files(true), "append-play")
    else
        add_media(dialog_files(false), "replace")
    end
end

local function prop(n) return mp.get_property_number(n) end
local function propn(n) return mp.get_property_native(n) end

local function set_num(p, v, fmt)
    mp.commandv("set", p, fmt and string.format(fmt, v) or tostring(v))
end

local function toggle(p, on, off)
    local cur = propn(p)
    mp.commandv("set", p, cur and (off or "no") or (on or "yes"))
end

local function speeds_menu()
    local items = {}
    for _, v in ipairs({ 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 4.0 }) do
        local sp = prop("speed") or 1
        items[#items + 1] = {
            label = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "") .. "x",
            checked = math.abs(sp - v) < 0.01,
            action = function() set_num("speed", v, "%.2f") end,
        }
        if math.abs(v - 1.0) < 0.001 then
            items[#items + 1] = { label = "Reset to normal", accel = "BS", action = function() set_num("speed", 1, "%.2f") end }
            items[#items + 1] = { sep = true }
        end
    end
    return items
end

local function aspect_menu()
    local cur = mp.get_property("video-aspect-override") or "no"
    local items = {}
    for _, v in ipairs({ "no", "16:9", "4:3", "1.85:1", "2.35:1", "2.39:1", "1.33:1", "5:4", "1:1" }) do
        items[#items + 1] = {
            label = v == "no" and "Default (as coded)" or v,
            checked = cur == v,
            action = function() mp.commandv("set", "video-aspect-override", v) end,
        }
    end
    return items
end

local function hwdec_menu()
    local cur = mp.get_property("hwdec") or "no"
    local items = {}
    for _, v in ipairs({ "no", "auto-safe", "auto", "auto-copy" }) do
        items[#items + 1] = {
            label = ({ ["no"] = "Disabled (software)", ["auto-safe"] = "Auto (safe)",
                ["auto"] = "Auto", ["auto-copy"] = "Auto (copy-back)" })[v],
            checked = cur == v,
            action = function()
                mp.commandv("set", "hwdec", v)
                pcall_show("Hardware decoding: " .. v .. " (applies to next file)")
            end,
        }
    end
    return items
end

local function track_menu(kind)
    local items = {}
    local tracks = propn("track-list") or {}
    local cur = prop(kind == "audio" and "aid" or "sid")
    if not cur or cur == 0 then cur = -1 end
    for _, t in ipairs(tracks) do
        if t.type == kind then
            local name = t.title and t.title ~= "" and t.title or t.lang or "Track"
            local codec = t.codec and (" (" .. t.codec .. ")") or ""
            items[#items + 1] = {
                label = t.id .. ": " .. name .. codec,
                checked = (t.id == cur),
                action = function()
                    mp.commandv("set", kind == "audio" and "aid" or "sid", tostring(t.id))
                end,
            }
        end
    end
    items[#items + 1] = { sep = true }
    items[#items + 1] = {
        label = "Disable", checked = (cur == -1 or cur == nil),
        action = function() mp.commandv("set", kind == "audio" and "aid" or "sid", "no") end,
    }
    items[#items + 1] = {
        label = kind == "audio" and "Load external audio..." or "Load subtitle...",
        action = function()
            local out = dialog_files(false)
            if out then
                out = out:gsub("[\r\n]+$", "")
                if kind == "audio" then mp.commandv("audio-add", out, "select")
                else mp.commandv("sub-add", out, "select") end
            end
        end,
    }
    return items
end

local function playlist_menu()
    return {
        { label = "Add file...", action = function() open_file("add") end },
        { label = "Add folder...", action = function() open_file("add-folder") end },
        { sep = true },
        { label = "Previous", accel = "PgUp", action = function() mp.commandv("playlist-prev") end },
        { label = "Next", accel = "PgDn", action = function() mp.commandv("playlist-next") end },
        { label = "Shuffle", action = function() mp.commandv("playlist-shuffle") end },
        { label = "Remove current", action = function()
            local i = mp.get_property_number("playlist-pos")
            if i then mp.commandv("playlist-remove", tostring(i)) end
        end },
        { label = "Clear playlist", action = function() mp.commandv("playlist-clear") end },
        { sep = true },
        { label = "Auto-load folder", checked = o.auto_load_folder == "yes", action = function()
            o.auto_load_folder = (o.auto_load_folder == "yes") and "no" or "yes"
            mp.commandv("script-message-to", "pot_ui", "pot-setopt", "auto_load_folder", o.auto_load_folder)
            pcall_show("Auto-load folder: " .. (o.auto_load_folder == "yes" and "on" or "off"))
        end },
        { label = "Save playlist...", action = save_playlist },
        { label = "Show playlist", accel = "F6", checked = playlist_open(),
          action = function() mp.commandv("script-message-to", "pot_ui", "pot-toggle-playlist") end },
    }
end

function playlist_open()
    local ok, v = pcall(mp.get_property_native, "user-data/pot-playlist")
    if ok then return v == true end
    return false
end

local function video_menu()
    return {
        { label = "Hardware decoding", submenu = hwdec_menu },
        { label = "Deinterlace", checked = (mp.get_property("deinterlace") or "no") ~= "no",
          action = function() mp.commandv("cycle", "deinterlace") end },
        { label = "Aspect ratio", submenu = aspect_menu },
        { label = "Rotate 90 degrees", accel = "", action = function() mp.commandv("cycle-values", "video-rotate", "0", "90", "180", "270") end },
        { label = "Zoom in", accel = "", action = function() mp.commandv("add", "video-zoom", "0.1") end },
        { label = "Zoom out", accel = "", action = function() mp.commandv("add", "video-zoom", "-0.1") end },
        { label = "Reset zoom", action = function() mp.commandv("set", "video-zoom", "0") end },
        { sep = true },
        { label = "Take screenshot", accel = "S", action = function() mp.commandv("screenshot") end },
        { label = "Fullscreen", accel = "F", checked = propn("fullscreen"),
          action = function() mp.commandv("cycle", "fullscreen") end },
        { label = "Always on top", accel = "T", checked = propn("ontop"),
          action = function() mp.commandv("cycle", "ontop") end },
    }
end

local function audio_menu()
    local items = {
        { label = "Audio track", submenu = function() return track_menu("audio") end },
        { label = "Mute", accel = "M", checked = propn("mute"),
          action = function() mp.commandv("cycle", "mute") end },
        { label = "Volume up", action = function() mp.commandv("add", "volume", "5") end },
        { label = "Volume down", action = function() mp.commandv("add", "volume", "-5") end },
        { sep = true },
        { label = "Audio delay +0.1s", action = function() mp.commandv("add", "audio-delay", "0.1") end },
        { label = "Audio delay -0.1s", action = function() mp.commandv("add", "audio-delay", "-0.1") end },
        { label = "Reset audio delay", action = function() mp.commandv("set", "audio-delay", "0") end },
    }
    return items
end

local function subtitle_menu()
    local items = {
        { label = "Find subtitles online...", action = function()
            local mx, my = mouse()
            find_subtitles_online(mx, my)
        end },
        { label = "Subtitle track", submenu = function() return track_menu("subtitle") end },
        { label = "Show subtitles", accel = "V", checked = propn("sub-visibility") ~= false,
          action = function() mp.commandv("cycle", "sub-visibility") end },
        { label = "Load subtitle...", action = function()
            local out = dialog_files(false)
            if out then mp.commandv("sub-add", out:gsub("[\r\n]+$", ""), "select") end
        end },
        { sep = true },
        { label = "Delay +0.1s", action = function() mp.commandv("add", "sub-delay", "0.1") end },
        { label = "Delay -0.1s", action = function() mp.commandv("add", "sub-delay", "-0.1") end },
        { label = "Reset delay", action = function() mp.commandv("set", "sub-delay", "0") end },
        { sep = true },
        { label = "Bigger text", action = function() mp.commandv("add", "sub-font-size", "2") end },
        { label = "Smaller text", action = function() mp.commandv("add", "sub-font-size", "-2") end },
        { label = "Raise subtitles", action = function() mp.commandv("add", "sub-pos", "5") end },
        { label = "Lower subtitles", action = function() mp.commandv("add", "sub-pos", "-5") end },
        { sep = true },
        { label = "Advanced", submenu = function()
            local out = {}
            local cur = mp.get_property("sub-ass-override") or "scale"
            for _, v in ipairs({ "no", "yes", "scale", "force" }) do
                out[#out + 1] = {
                    label = ({ no = "Keep ASS styles", yes = "Override with styles",
                        scale = "Scale styles", force = "Force style" })[v],
                    checked = cur == v,
                    action = function() mp.commandv("set", "sub-ass-override", v) end,
                }
            end
            return out
        end },
    }
    return items
end

local function playback_menu()
    return {
        { label = "A-B loop", accel = "L", action = function() mp.commandv("ab-loop") end },
        { label = "Jump +10s", accel = "Right", action = function() mp.commandv("seek", "10") end },
        { label = "Jump -10s", accel = "Left", action = function() mp.commandv("seek", "-10") end },
        { label = "Next frame", action = function() mp.commandv("frame-step") end },
        { label = "Previous chapter", action = function() mp.commandv("chapter", "-1") end },
        { label = "Next chapter", action = function() mp.commandv("chapter", "1") end },
        { label = "Cycle pan/scan", action = function() mp.commandv("cycle-values", "video-pan-x", "0", "0.1", "-0.1") end },
        { sep = true },
        { label = "Shuffle playlist", action = function() mp.commandv("playlist-shuffle") end },
        { label = "Loop playlist", checked = (mp.get_property("loop-playlist") or "no") ~= "no",
          action = function() mp.commandv("cycle", "loop-playlist") end },
        { sep = true },
    }
end

local function playback_menu_base()
    return {
        { label = (propn("pause") and "Play" or "Pause"), accel = "Space",
          action = function() mp.commandv("cycle", "pause") end },
        { label = "Stop", action = function() mp.commandv("stop") end },
        { label = "Speed", submenu = speeds_menu },
        { label = "Repeat current file", checked = mp.get_property("loop-file") == "inf",
          action = function() mp.commandv("cycle-values", "loop-file", "no", "inf") end },
        { label = "Repeat playlist", checked = mp.get_property("loop-playlist") == "inf",
          action = function() mp.commandv("cycle-values", "loop-playlist", "no", "inf") end },
        { sep = true },
        { label = "Set A-B start", action = function()
            mp.commandv("set", "ab-loop-a", tostring(mp.get_property_number("time-pos") or 0))
            pcall_show("A-B start set")
        end },
        { label = "Set A-B end", action = function()
            mp.commandv("set", "ab-loop-b", tostring(mp.get_property_number("time-pos") or 0))
            pcall_show("A-B end set")
        end },
        { label = "Clear A-B loop", action = function()
            mp.commandv("set", "ab-loop-a", "no"); mp.commandv("set", "ab-loop-b", "no")
        end },
        { sep = true },
        { label = "Previous file", accel = "PgUp", action = function() mp.commandv("playlist-prev") end },
        { label = "Next file", accel = "PgDn", action = function() mp.commandv("playlist-next") end },
    }
end


-- ---------- online subtitles (OpenSubtitles API v1) ----------
local function urlenc(q)
    return (q:gsub("([^%w%-%._~ ])", function(c) return string.format("%%%02X", c:byte()) end):gsub(" ", "+"))
end

local function osub_http(method, url, headers, body)
    local args = { "curl", "-s", "--max-time", "20", "-X", method }
    for _, h in ipairs(headers or {}) do args[#args + 1] = "-H"; args[#args + 1] = h end
    if body then args[#args + 1] = "-d"; args[#args + 1] = body end
    args[#args + 1] = url
    local r = mp.command_native({ name = "subprocess", args = args,
        capture_stdout = true, capture_stderr = true, playback_only = false })
    if r and r.status == 0 then return r.stdout or "" end
    return nil
end

local function osub_token()
    local key = o.osub_api_key ~= "" and o.osub_api_key or os.getenv("OPENSUBTITLES_API_KEY") or ""
    if key == "" then return nil, "Set osub_api_key in script-opts/pot.conf" end
    local body = mp.utils.format_json({ username = o.osub_user or "", password = o.osub_pass or "", api_key = key })
    local out = osub_http("POST", "https://api.opensubtitles.com/api/v1/login",
        { "Content-Type: application/json", "Api-Key: " .. key }, body)
    if not out then return nil, "OpenSubtitles request failed" end
    local j = mp.utils.parse_json(out)
    if not j or not j.token then return nil, "OpenSubtitles login failed" end
    return j.token, nil
end

local function osub_search(q)
    local tok, err = osub_token()
    if not tok then pcall_show(err or ""); return {} end
    local url = "https://api.opensubtitles.com/api/v1/subtitles?query=" .. urlenc(q)
        .. "&languages=" .. (o.osub_lang ~= "" and o.osub_lang or "eng")
        .. "&subtitle_format=srt&per_number_limit=12"
    local out = osub_http("GET", url, { "Api-Key: " .. (o.osub_api_key ~= "" and o.osub_api_key or os.getenv("OPENSUBTITLES_API_KEY") or ""),
        "Authorization: Bearer " .. tok })
    if not out then pcall_show("Search failed"); return {} end
    local j = mp.utils.parse_json(out)
    local res = {}
    if j and j.data then
        for _, d in ipairs(j.data) do
            local a = d.attributes or {}
            res[#res + 1] = {
                id = d.id,
                name = a.feature_details_movie_name or a.feature_details_tv_series_name or q,
                rel = a.release or "",
                lang = a.language or "",
                dl = a.download_count or 0,
            }
        end
    end
    return res
end

local function osub_download(r, tok)
    local out = osub_http("POST", "https://api.opensubtitles.com/api/v1/download",
        { "Content-Type: application/json", "Api-Key: " .. (o.osub_api_key ~= "" and o.osub_api_key or os.getenv("OPENSUBTITLES_API_KEY") or ""),
          "Authorization: Bearer " .. tok }, mp.utils.format_json({ file_id = r.id }))
    if not out then pcall_show("Download request failed"); return end
    local j = mp.utils.parse_json(out)
    local link = j and j.link
    if not link then pcall_show("No download link"); return end
    local path = os.tmpname() .. ".srt"
    local r2 = mp.command_native({ name = "subprocess", args = { "curl", "-sL", "--max-time", "30", "-o", path, link },
        capture_stdout = true, capture_stderr = true, playback_only = false })
    if not r2 or r2.status ~= 0 then pcall_show("Download failed"); return end
    local f = io.open(path, "rb")
    if not f then pcall_show("Download failed"); return end
    local head = f:read(2) or ""
    f:close()
    if head == "\031\139" then
        os.rename(path, path .. ".gz")
        os.execute('gunzip -f "' .. path .. '.gz" >/dev/null 2>&1')
    end
    mp.commandv("sub-add", path, "select")
    pcall_show("Subtitle added: " .. r.name)
end

local function dialog_entry(title, def)
    local pf = mp.get_property("platform")
    if pf == "win" then
        return subprocess_capture({ "powershell", "-NoProfile", "-STA", "-Command",
            'Add-Type -AssemblyName Microsoft.VisualBasic;[Microsoft.VisualBasic.Interaction]::InputBox("' .. title .. '","' .. title .. '","' .. (def or "") .. '")' })
    elseif pf == "darwin" then
        return subprocess_capture({ "osascript", "-e",
            'text returned of (display dialog "' .. title .. '" default answer "' .. (def or "") .. '" buttons {"OK"} default button 1)' })
    else
        return subprocess_capture({ "zenity", "--entry", "--title=" .. title, "--text=" .. title, "--entry-text=" .. (def or "") })
    end
end

local function find_subtitles_online(mx, my)
    local title = mp.get_property("media-title") or ""
    local q = dialog_entry("Search subtitles", title)
    if not q or q == "" then return end
    local res = osub_search(q)
    if #res == 0 then pcall_show("No subtitles found"); return end
    local tok = osub_token()
    local items = {}
    for _, r in ipairs(res) do
        items[#items + 1] = {
            label = string.format("%s (%s) - %s dl:%d", r.name, r.lang, r.rel, r.dl),
            action = function() if tok then osub_download(r, tok) end end,
        }
    end
    open(items, mx or M.w / 2, my or M.h / 2)
end

-- ---------- edit controls / config ----------
local function edit_config_file(name)
    local path = mp.find_config_file(name)
    if not path then pcall_show(name .. " not found"); return end
    local ed = os.getenv("EDITOR")
    local pf = mp.get_property("platform")
    local args
    if ed then args = { ed, path }
    elseif pf == "win" then args = { "cmd", "/c", "start", "", path }
    else args = { "xdg-open", path } end
    mp.command_native({ name = "subprocess", args = args, playback_only = false })
end

local function controls_menu()
    return {
        { label = "Key bindings (input.conf)", action = function() edit_config_file("input.conf") end },
        { label = "Player options (mpv.conf)", action = function() edit_config_file("mpv.conf") end },
        { label = "Skin options (pot.conf)", action = function() edit_config_file("script-opts/pot.conf") end },
        { label = "Open config folder", action = function()
            local dir = mp.find_config_file("input.conf") or ""
            dir = dir:gsub("[^/]+$", "")
            if dir ~= "" then mp.command_native({ name = "subprocess", args = { "xdg-open", dir }, playback_only = false }) end
        end },
    }
end

local function root_menu()
    return {
        { label = "Open file...", accel = "Ctrl+O", action = function() open_file() end },
        { label = "Open folder...", action = function() open_file("folder") end },
        { label = "Open URL...", accel = "Ctrl+U", action = function() open_file("url") end },
        { sep = true },
        { label = "Playlist", submenu = playlist_menu },
        { label = "Playback", submenu = playback_menu },
        { label = "Aspect ratio", submenu = aspect_menu },
        { label = "Video", submenu = video_menu },
        { label = "Audio", submenu = audio_menu },
        { label = "Subtitles", submenu = subtitle_menu },
        { sep = true },
        { label = "Controls", submenu = controls_menu },
        { label = "Preferences...", accel = "F5", action = function()
            mp.commandv("script-message-to", "pot_prefs", "open")
        end },
        { label = "About PotMPV", action = function()
            pcall_show("PotMPV 1.1.1  |  " .. tostring(mp.get_property("mpv-version")))
        end },
        { sep = true },
        { label = "Exit", accel = "Ctrl+Q", action = function() mp.commandv("quit") end },
    }
end

local submenus = {
    speed = speeds_menu,
    video = video_menu,
    audio = audio_menu,
    subtitles = subtitle_menu,
    playback = playback_menu,
    playlist = playlist_menu,
    ["playlist-menu"] = playlist_menu,
    tracks_audio = function() return track_menu("audio") end,
    tracks_sub = function() return track_menu("subtitle") end,
    aspect = aspect_menu,
    hwdec = hwdec_menu,
}

local function open_at_mouse()
    if M.open then close(); return end
    geom()
    local mx, my = mouse()
    if not mx then mx, my = M.w / 2, M.h / 2 end
    open(root_menu(), mx, my)
end

mp.register_script_message("menu", open_at_mouse)
mp.register_script_message("open-file", function(mode) open_file(mode) end)
mp.register_script_message("open-sub", function(name, x, y)
    if M.open then close() end
    geom()
    local items = submenus[name]
    if type(items) == "function" then items = items() end
    if not items then return end
    local page = build_page(items)
    layout_page(page)
    local px = tonumber(x) or M.w / 2
    local py = tonumber(y) or M.h / 2
    if px == 0 and py == 0 then px, py = M.w / 2, M.h / 2 end
    open(items, px, py)
end)

local function on_mouse(_, p)
    if not M.open or not p or not p.x then return end
    schedule()
end
mp.observe_property("mouse-pos", "native", on_mouse)


mp.add_periodic_timer(0.05, function()
    if M.open then
        update_hover()
        maybe_submenu()
        render()
    end
end)
