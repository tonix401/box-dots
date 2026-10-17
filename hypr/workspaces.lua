-----------------------------
---- LINKED WORKSPACES ----
-----------------------------

-- Switching workspace switches every monitor at once, so the screens act as one desktop while
-- windows still tile per screen. Each monitor has its own workspaces by slot: slot 0 (the laptop
-- panel, or the only screen) has 1-9, slot 1 has 11-19, slot 2 21-29, so "workspace n" is
-- slot * 10 + n on each monitor. However a workspace gets focused (keys, the bar, the overview, an
-- app asking for attention), the workspace.active handler below shows the same n on the others.
-- quickshell/modules/Workspaces.qml reads the slot back from each monitor's active workspace.

linked = {
  slots = {}, -- monitor name -> slot; kept for the session, so a screen plugged back in gets its old one
}

local busy = false -- while show() switches monitors itself, so its own focus changes don't sync again

local function slot_of(id) return (id - 1) // 10 end
function linked.n(id) return (id - 1) % 10 + 1 end

local function internal(m) return m.name:find("^eDP") ~= nil end

-- Monitors that show something of their own, laptop panel first, then by connector name.
local function monitors()
  local ms = {}
  for _, m in ipairs(hl.get_monitors()) do
    if not m.is_mirror then table.insert(ms, m) end
  end
  table.sort(ms, function(a, b)
    if internal(a) ~= internal(b) then return internal(a) end
    return a.name < b.name
  end)
  return ms
end

-- Gives every monitor a slot of its own: the one it had, else the one its workspace is in, else
-- the lowest free. Then moves workspaces numbered for another slot over to their monitor's numbers,
-- keeping n (hyprland.lua starts a second screen on 2, which becomes 12; after unplugging a screen,
-- its 11-19 land on the panel and become 1-9 where those are free). Renumbering keeps the windows
-- and what each screen shows.
function linked.assign()
  local taken, slots = {}, {}
  for _, m in ipairs(monitors()) do
    local s = linked.slots[m.name]
    if s == nil or taken[s] then
      local ws = m.active_workspace
      s = ws and ws.id > 0 and slot_of(ws.id) or 0
      while taken[s] do s = s + 1 end
    end
    taken[s] = true
    slots[m.name] = s
    linked.slots[m.name] = s
  end
  for _, w in ipairs(hl.get_workspaces()) do
    local s = w.id > 0 and w.monitor and slots[w.monitor.name]
    if s and slot_of(w.id) ~= s then
      local id = s * 10 + linked.n(w.id)
      if not hl.get_workspace(id) then
        hl.dispatch(hl.dsp.workspace.change_id({ workspace = w.id, id = id }))
      end
    end
  end
end

-- Workspace n on the focused monitor.
function linked.here(n)
  local m = hl.get_active_monitor()
  if m and linked.slots[m.name] == nil then linked.assign() end
  return (m and linked.slots[m.name] or 0) * 10 + n
end

-- Shows workspace n on every monitor. Focusing a monitor moves the cursor to it, so the focused
-- monitor gets the focus back last and the cursor goes back where it was.
function linked.show(n)
  local active = hl.get_active_monitor()
  if not active then return end
  local cursor = hl.get_cursor_pos()
  local moved = false
  busy = true
  for _, m in ipairs(monitors()) do
    local s = linked.slots[m.name]
    if s and m.name ~= active.name and not (m.active_workspace and m.active_workspace.id == s * 10 + n) then
      hl.dispatch(hl.dsp.focus({ monitor = m.name }))
      hl.dispatch(hl.dsp.focus({ workspace = s * 10 + n }))
      moved = true
    end
  end
  if moved then
    hl.dispatch(hl.dsp.focus({ monitor = active.name }))
    if cursor then hl.dispatch(hl.dsp.cursor.move({ x = cursor.x, y = cursor.y })) end
  end
  busy = false
end

-- One step left or right, within 1-9.
function linked.step(delta)
  local ws = hl.get_active_workspace()
  local n = ws and ws.id > 0 and linked.n(ws.id) or 1
  hl.dispatch(hl.dsp.focus({ workspace = linked.here(math.max(1, math.min(9, n + delta))) }))
end

hl.on("workspace.active", function(w)
  if busy or not w or w.id < 1 or not w.monitor then return end
  local s = linked.slots[w.monitor.name]
  if s == nil then
    linked.assign()
    s = linked.slots[w.monitor.name]
  end
  -- a workspace left over from an unplugged screen: show it here alone
  if s ~= slot_of(w.id) then return end
  linked.show(linked.n(w.id))
end)

-- A screen that just came (or went) gets its slot and then the workspace the others show. The
-- delay lets Hyprland give a new screen its first workspace before it's renumbered.
local function rearrange()
  hl.timer(function()
    linked.assign()
    local ws = hl.get_active_workspace()
    if ws and ws.id > 0 then linked.show(linked.n(ws.id)) end
  end, { timeout = 300, type = "oneshot" })
end
hl.on("monitor.added", rearrange)
hl.on("monitor.removed", rearrange)

linked.assign()
