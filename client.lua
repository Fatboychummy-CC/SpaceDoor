--[[
  Expects the door peripherals to be on the right.
  Expects system network on the left.

  MIT License

  Copyright (c) 2020 Fatboychummy-CC

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

]]
assert(peripheral.getType("right") == "modem", "Need modem on right side.")
assert(not peripheral.call("right", "isWireless"), "Modem right needs to be a wired modem.")
assert(peripheral.getType("left") == "modem", "Need modem on left side.")
assert(not peripheral.call("left", "isWireless"), "Modem left needs to be a wired modem.")
-- [[ Modules ]] --
local expect = require("cc.expect").expect
os.loadAPI("bigfont")

-- [[ Semi-Globals ]] --
local function GetPeripherals(sType)
  expect(1, sType, "string")

  local t = {n = 0}

  for _, sName in ipairs(peripheral.call("right", "getNamesRemote")) do
    if peripheral.getType(sName) == sType then
      t.n = t.n + 1
      t[t.n] = sName
    end
  end
  table.sort(t)
  local t2 = {n = t.n}
  for i = 1, t.n do
    t2[i] = peripheral.wrap(t[i])
  end

  return t2, t
end
local tIntegrators = GetPeripherals("redstone_integrator")
local tMonitors, tMonNames = GetPeripherals("monitor")
local Manip = peripheral.find("manipulator") -- only one is needed.
local nLockdownChannel = 350
local bLockDown = false
local nLockMin = 0

-- [[ Functions ]] --
local function DefineSettings()
  local function DefineDefault(sSetting, val)
    settings.define(sSetting, {type = type(val), default = val})
  end
  DefineDefault("door.id1",           "M1")
  DefineDefault("door.id2",           "M2")
  DefineDefault("door.name1",         "Monitor 1")
  DefineDefault("door.name2",         "Monitor 2")
  DefineDefault("door.level1",        1)
  DefineDefault("door.level2",        1)
  DefineDefault("door.playerlocked",  false)
  DefineDefault("door.sensorOffset",  {0, 0, 1.5})
  DefineDefault("door.serverChannel", 458)
end

local function Palette(monitor)
  expect(1, monitor, "table")
  local function f(x, y)
    monitor.setPaletteColor(x, y)
  end

  f(colors.orange, 0xffa500)
  f(colors.yellow, 0xffff00)
  f(colors.red,    0xff0000)
  f(colors.green,  0x00ff00)
  f(colors.gray,   0x666666)
  f(colors.white,  0xffffff)
  f(colors.black,  0x000000)
end

local function ForEach(t, f)
  expect(1, t, "table")
  expect(2, f, "function")
  expect(1000, t.n, "number")

  for i = 1, t.n do
    f(t[i], i)
  end
end

local tSides = {"north", "east", "south", "west", n = 4}
local function Integrators(b)
  expect(1, b, "boolean")

  ForEach(tIntegrators, function(Integrator)
    ForEach(tSides, function(side)
      Integrator.setOutput(side, b)
    end)
  end)
end

local function Box(termObj, x, y, w, h, bg)
  expect(1, termObj, "table")
  expect(2, x,       "number")
  expect(3, y,       "number")
  expect(4, w,       "number")
  expect(5, h,       "number")
  expect(6, bg,      "number")

  local rep = string.rep(' ', w)

  termObj.setBackgroundColor(bg)
  for _y = y, y + h do
    termObj.setCursorPos(x, _y)
    termObj.write(rep)
  end
end

local function Monitors(sState, bUpdateStateOnly, ei)
  expect(1, sState, "string")
  expect(2, bUpdateStateOnly, "boolean", "nil")
  expect(3, ei, "number", "nil")

  if not bUpdateStateOnly then
    local sId1, sId2, sName1, sName2 =
      settings.get("door.id1"),
      settings.get("door.id2"),
      settings.get("door.name1"),
      settings.get("door.name2")

    ForEach(tMonitors, function(monitor, i)
      Palette(monitor)
      local sId, sName
      monitor.setBackgroundColor(colors.blue)
      monitor.setTextColor(colors.white)
      monitor.setTextScale(0.5)
      monitor.clear()

      if sState == "Errored" then
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.red)
        monitor.clear()
        sId = tostring(ei)
        sName = "System Error"
      elseif sState == "Lockdown" or bLockDown then
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.red)
        monitor.clear()
        sId = "X"
        sName = "LOCKDOWN"
      else
        if i == 1 then
          sId   = sId1
          sName = sName1
        else
          sId   = sId2
          sName = sName2
        end
      end

      monitor.setCursorPos(2, 2)
      bigfont.writeOn(monitor, 2, sId, 2, 2)
      bigfont.writeOn(monitor, 1, sName, 3 + sId:len() * 9, 5)
    end)
  end

  local StateWidth = 7
  local tLevels = {settings.get("door.level1"), settings.get("door.level2")}
  local function StateFunc(color)
    return function(monitor, i)
      local mx, my = monitor.getSize()
      Box(monitor, mx - StateWidth + 1, 1, StateWidth, my, color)
      if tLevels[i] > 1 then
        bigfont.writeOn(monitor, 1, "L" .. tostring(tLevels[i]), mx - StateWidth / 2 - ("L" .. tostring(tLevels[i])):len() / 2, my / 2)
      end
    end
  end

  if sState == "Closed" then
    ForEach(tMonitors, StateFunc(colors.orange))
  elseif sState == "Unlocking1" then
    ForEach(tMonitors, StateFunc(colors.yellow))
  elseif sState == "Unlocking2" then
    ForEach(tMonitors, StateFunc(colors.red))
  elseif sState == "Opened" then
    ForEach(tMonitors, StateFunc(colors.green))
  elseif sState == "Errored" or sState == "Lockdown" then
    ForEach(tMonitors, StateFunc(colors.gray))
  end
end

local function GetDistanceToEntity(entity)
  return (
    vector.new(table.unpack(settings.get("door.sensorOffset"), 1, 3))
    + vector.new(entity.x, entity.y, entity.z)
  ):length()
end

local function GetEntitiesInRangeOfDoor()
  if Manip then
    if Manip.sense then
      local tEntities = Manip.sense()
      local tInRange = {}

      for i = 1, #tEntities do
        if GetDistanceToEntity(tEntities[i]) <= 4 then
          tInRange[#tInRange + 1] = tEntities[i]
        end
      end

      return tInRange
    else
      error("Manipulator needs entity sensor!")
    end
  else
    error("Cannot have clearance level > 1 without manipulator and entity sensor!")
  end
end

local function RetrieveUUIDClearance(_uuid)
  local Channel = settings.get("door.serverChannel")
  local modem = peripheral.wrap("left")

  modem.open(Channel)
  modem.transmit(Channel, Channel, {type = "Get-Clearance", uuid = _uuid, id = os.getComputerID()})

  local EndTimer = os.startTimer(0.25)
  local Level = 1

  while true do
    local tEvent = table.pack(os.pullEvent())
    if tEvent[1] == "timer" and tEvent[2] == EndTimer then
      break
    elseif tEvent[1] == "modem_message" then
      local side, fRec, _, message = table.unpack(tEvent, 2, tEvent.n)
      if side == "left" and fRec == Channel and type(message) == "table" then
        if message.type == "Clearance" and message.id == os.getComputerID() then
          Level = message.level
          break
        end
      end
    end
  end

  modem.close(Channel)
  return Level
end

local function CheckEntities(Level)
  local tEntities = GetEntitiesInRangeOfDoor()

  print("Entry check:")
  for i = 1, #tEntities do
    print(" ", tEntities[i].id, "?")
    local DetectedLevel = RetrieveUUIDClearance(tEntities[i].id)
    if (bLockDown and DetectedLevel >= nLockMin) or (not bLockDown and DetectedLevel >= Level) then
      print("    Allowed.")
      return true
    end
    print("    Not high enough clearance.")
  end
  return false
end

local function Open()
  Monitors("Opened", true)
  Integrators(true)
  sleep(3)
  Monitors("Closed", true)
  Integrators(false)
end

local function Unlocking(Level)
  local bUnlocked = false
  parallel.waitForAny(
    function() -- check entities thread
      while true do
        if CheckEntities(Level) then
          bUnlocked = true
          break
        end
        sleep(0.5)
      end
    end,
    function() -- monitor drawing thread
      for i = 1, 3 do
        Monitors("Unlocking1", true)
        sleep(0.5)
        Monitors("Unlocking2", true)
        sleep(0.5)
      end
    end
  )

  if bUnlocked then
    Open()
  else
    Monitors("Closed", true)
  end
end

-- [[ Main Program ]] --
local function Main()
  DefineSettings()
  Monitors("Closed")
  Integrators(false)
  peripheral.call("left", "open", nLockdownChannel)
  local tLevels = {settings.get("door.level1"), settings.get("door.level2")}
  while true do
    local tEvent = table.pack(os.pullEvent())
    if tEvent[1] == "monitor_touch" then
      for i = 1, tMonNames.n do
        local name = tMonNames[i]
        if name == tEvent[2] then
          Unlocking(tLevels[i])
        end
      end
    elseif tEvent[1] == "modem_message" and tEvent[2] == "left" then
      local fRec, _, message = table.unpack(tEvent, 3, tEvent.n)
      if fRec == nLockdownChannel and type(message) == "table" then
        if message.type == "LOCKDOWN" then
          if message.status then
            -- lockdown
            bLockDown = true
            nLockMin = type(message.bypass) == "number" and message.bypass or 999
            Monitors("Lockdown")
            print("LOCKDOWN LOCKDOWN")
            print("  MINIMUM CLEARANCE:", nLockMin)
          else
            -- no lockdown
            if bLockDown then
              print("Lockdown ended.")
            end
            bLockDown = false
            nLockMin = 0
            Monitors("Closed")
          end
        end
      end
    end
  end
end

-- [[ Error Handling ]] --
local ok, err = pcall(Main)
if not ok then
  printError(err)
  pcall(Monitors, "Errored", nil, 10)
  for i = 9, 0, -1 do
    sleep(1)
    pcall(Monitors, "Errored", nil, i)
  end
  os.reboot()
end
