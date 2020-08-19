--[[
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
--[[ Modules ]] --
local expect = require("cc.expect").expect

-- [[ Semi-Globals ]] --
local tClearances = {}
local sSaveFile = ".records"
local mx, my = term.getSize()
local bLockDown = false
local nLockdownChannel = 350
local minLockdownLevel = 999
local printWindow   = window.create(term.current(), 1, 2, mx, my - 8)
local commandWindow = window.create(term.current(), 1, my - 6, mx, 1)
local resultWindow  = window.create(term.current(), 1, my - 4, mx, 3)
local userWindow    = window.create(term.current(), 1, my, mx, 1)

local function Line(window, length, color)
  window.setBackgroundColor(color)
  window.write(string.rep(' ', length))
end

local function redrawScreen()
  term.setBackgroundColor(colors.gray)
  term.clear()
  term.setCursorPos(2, 1)
  term.write("Log Output")
  printWindow.setBackgroundColor(colors.black)
  printWindow.redraw()
  term.setCursorPos(1, my - 7)
  Line(term, mx, colors.gray)
  term.setCursorPos(2, my - 7)
  term.write("Last Command")
  commandWindow.setBackgroundColor(colors.black)
  commandWindow.redraw()
  term.setCursorPos(2, my - 5)
  term.write("Last Command Results")
  userWindow.setBackgroundColor(colors.black)
  userWindow.redraw()
  term.setCursorPos(2, my - 1)
  term.write("User Input")
  resultWindow.setBackgroundColor(colors.black)
  resultWindow.redraw()
  term.setBackgroundColor(colors.black)
end

local oprint = print
local function print(...)
  local lx, ly = term.getCursorPos()
  local old = term.redirect(printWindow)
  printWindow.setBackgroundColor(colors.black)
  oprint(...)

  term.redirect(old)
  redrawScreen()
  term.setCursorPos(lx, ly)
end
term.setBackgroundColor(colors.gray)
term.clear()
printWindow.setBackgroundColor(colors.black)
printWindow.clear()
commandWindow.setBackgroundColor(colors.black)
commandWindow.clear()
userWindow.setBackgroundColor(colors.black)
userWindow.clear()
resultWindow.setBackgroundColor(colors.black)
resultWindow.clear()

-- [[ Functions ]] --


local function CommandResult(sCommand, tResult)
  expect(1, sCommand, "string")
  expect(2, tResult, "table")

  commandWindow.clear()
  commandWindow.setCursorPos(1, 1)
  commandWindow.write(sCommand)

  resultWindow.clear()
  resultWindow.setCursorPos(1, 1)
  resultWindow.write(string.format("Status: %s", tResult.status))

  resultWindow.setCursorPos(1, 2)
  if tResult.status == "error" then
    resultWindow.write(tResult.error)
  elseif tResult.status == "ok" then
    resultWindow.write(tResult.output)
  elseif tResult.status == "no-subcommand" then
    resultWindow.write(string.format("No subcommand: %s", tResult.subcommand))
  elseif tResult.status == "console" then
    resultWindow.write("Check console.")
  end
end

local function CommandPrint(tLines)
  print("# COMMAND RESULT #")
  for i = 1, #tLines do
    print(tLines[i])
  end
  print("##################")
end

local function DefineSettings()
  local function DefineDefault(sSetting, val)
    settings.define(sSetting, {type = type(val), default = val})
  end
  DefineDefault("server.channel", 458)
end
local function SaveRecords()
  local h = io.open(sSaveFile, 'w')
  if h then
    h:write(textutils.serialize(tClearances)):close()
    return true
  end
  return false
end

local function LoadRecords()
  local h = io.open(sSaveFile, 'r')
  if h then
    local data = h:read("*a")
    h:close()
    return textutils.unserialize(data)
  end
  return {} -- default case, return empty records
end

local function UpdateRecord(uuid, level)
  expect(1, uuid, "string")
  expect(2, level, "number", "nil")
  tClearances[uuid] = level
  SaveRecords()
end

local function rebootAll()
  for i, computer in ipairs(table.pack(peripheral.find("computer"))) do
    computer.shutdown()
    computer.turnOn()
  end
end

local function Action(command)
  expect(1, command, "string")

  local chunks = {}
  for substring in command:gmatch("%S+") do
     table.insert(chunks, string.lower(substring))
  end

  local actions = {}
  function actions.reboot(thing)
    if not thing then
      for i = 3, 0, -1 do
        CommandResult(command, {status = "ok", output = string.format("Rebooting in %d...", i)})
        os.sleep(1)
      end
      os.reboot()
    end
    if thing == "doors" then
      rebootAll()
      CommandResult(command, {status = "ok", output = string.format("%d computers rebooted.", select('#', peripheral.find("computer")))})
    else
      CommandResult(command, {status = "no-subcommand", subcommand = thing})
    end
  end
  function actions.clear()
    printWindow.clear()
    printWindow.setCursorPos(1, 1)
    CommandResult(command, {status = "ok", output = "Console cleared."})
  end
  function actions.lockdown(active)
    if active == "activate" or active == "true" or active == "yes" or active == "y" or active == "active" then
      -- activate lockdown
      if bLockDown then
        CommandResult(command, {status = "error", error = "Lockdown already in effect!"})
        return
      end
      bLockDown = true
      os.queueEvent("lockdown")
      CommandResult(command, {status = "ok", output = "Lockdown activated!"})
    elseif active == "deactivate" or active == "false" or active == "no" or active == "n" or active == "inactive" then
      -- deactivate lockdown
      if not bLockDown then
        CommandResult(command, {status = "error", error = "No lockdown in effect!"})
        return
      end
      bLockDown = false
      CommandResult(command, {status = "ok", output = "Lockdown deactivated!"})
    elseif active == "status" then
      -- show lockdown status
      CommandResult(command, {status = "ok", output = string.format("Lockdown status: %s", bLockDown and "ACTIVE" or "INACTIVE")})
    else
      CommandResult(command, {status = "no-subcommand", subcommand = active})
    end
  end
  function actions.record(_type, uuid, level)
    if _type == "add" then
      if tClearances[uuid] then
        CommandResult(command, {status = "error", error = "UUID already exists. Use 'record update <uuid>'."})
        return
      elseif not tonumber(level) then
        CommandResult(command, {status = "error", error = "Expected number as argument #4."})
        return
      end
      UpdateRecord(uuid, tonumber(level))
      CommandResult(command, {status = "ok", output = string.format("Added uuid %s with level %d", uuid, tonumber(level))})
    elseif _type == "update" then
      if not tClearances[uuid] then
        CommandResult(command, {status = "error", error = "UUID does not exist! Use 'record add <uuid>'."})
        return
      elseif not tonumber(level) then
        CommandResult(command, {status = "error", error = "Expected number as argument #4."})
        return
      end
      local old = tClearances[uuid]
      UpdateRecord(uuid, tonumber(level))
      CommandResult(command, {status = "ok", output = string.format("Updated uuid %s (%d --> %d)", uuid, old, level)})
    elseif _type == "remove" then
      if not tClearances[uuid] then
        CommandResult(command, {status = "error", error = "UUID does not exist!"})
        return
      end
      UpdateRecord(uuid, nil)
      CommandResult(command, {status = "ok", output = "UUID removed."})
    elseif _type == "list" then
      local lines = {}
      for uuid, level in pairs(tClearances) do
        lines[#lines + 1] = string.format("%s: %d", uuid, level)
      end
      CommandPrint(lines)
      CommandResult(command, {status = "console"})
    else
      CommandResult(command, {status = "no-subcommand", subcommand = _type})
    end
  end
  function actions.help(com)
    if not com or com == "help" then
      CommandResult(command, {status = "ok", output = "Usage: help <command>"})
      return
    elseif com == "record" then
      CommandPrint {
        "Usage: record add <uuid:string> <level:string>",
        "Usage: record update <uuid:string> <level:string>",
        "Usage: record remove <uuid:string>",
        "Usage: record list"
      }
      CommandResult(command, {status = "console"})
      return
    elseif com == "lockdown" then
      CommandPrint {
        "Usage: lockdown status",
        "Usage: lockdown activate",
        "Usage: lockdown deactivate"
      }
      return
     elseif com == "reboot" then
      CommandPrint {
        "Usage: reboot",
        "Usage: reboot doors"
      }
      return
    end
    CommandResult(command, {status = "error", error = string.format("No help records for %s.", com)})
  end
  function actions.commands()
    local lines = {}
    for k in pairs(actions) do
      lines[#lines + 1] = k
    end
    CommandPrint(lines)
    CommandResult(command, {status = "console"})
  end
  function actions.stop()
    CommandResult(command, {status = "error", error = "Halted."})
    error("Halted.", 0)
  end
  actions.halt = actions.stop

  if actions[chunks[1]] then
    actions[chunks[1]](table.unpack(chunks, 2, #chunks))
  else
    CommandResult(command, {status = "error", error = "Unknown Command"})
  end
end

local function Main()
  DefineSettings()
  tClearances = LoadRecords()
  rebootAll()
  redrawScreen()
  parallel.waitForAny(
    function() -- Transmission
      local Channel = settings.get("server.channel")
      local modem = peripheral.find("modem")
      assert(modem, "No modem attached!")
      assert(not modem.isWireless(), "Modem is not allowed to be wireless!")
      modem.open(Channel)

      print("Server running.")
      while true do
        local _, _, fRec, fReply, message = os.pullEvent("modem_message")
        if fRec == Channel and type(message) == "table" then
          print(message.type)
          if message.type == "Get-Clearance" then
            print(" ", message.uuid, message.id)
            local tResponse = {
              type = "Clearance",
              level = tClearances[message.uuid] or 1,
              id = message.id
            }
            print("Response ->", textutils.serialize(tResponse))
            modem.transmit(fReply, fRec, tResponse)
          else
            print("  Unknown message type")
          end
        end
      end
    end,
    function() -- User input controller
      while true do
        userWindow.clear()
        userWindow.setCursorPos(1, 1)
        userWindow.write("> ")
        term.setCursorPos(3, my)
        local command = read()
        Action(command)
        redrawScreen()
      end
    end,
    function() -- lockdown transmitter
      local modem = peripheral.find("modem")
      while true do
        while bLockDown do
          modem.transmit(nLockdownChannel, nLockdownChannel, {
            type = "LOCKDOWN",
            status = true,
            bypass = minLockdownLevel
          })
          os.sleep(2)
        end
        modem.transmit(nLockdownChannel, nLockdownChannel, {
          type = "LOCKDOWN",
          status = false
        })
        os.sleep(2)
      end
    end
  )
end

Main()
