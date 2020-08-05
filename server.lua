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
local printWindow = window.create(term.current(), 1, 1, mx, my - 1)
local userWindow  = window.create(term.current(), 1, my, mx, 1)

local oprint = print
local function print(...)
  local lx, ly = term.getCursorPos()
  local old = term.redirect(printWindow)

  oprint(...)

  term.redirect(old)
  term.setCursorPos(lx, ly)
end

-- [[ Functions ]] --
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

local function Action(command)
  expect(1, command, "string")
  print("COMMAND:", command)

  local chunks = {}
  for substring in command:gmatch("%S+") do
     table.insert(chunks, string.lower(substring))
  end

  local actions = {}
  function actions.record(_type, uuid, level)
    if _type == "add" then
      if tClearances[uuid] then
        print("  That uuid already exists! Use 'record update <uuid>' instead.")
        return
      elseif not tonumber(level) then
        print("  Usage: record add <uuid:string> <level:number>")
        return
      end
      UpdateRecord(uuid, tonumber(level))
      print("  Added uuid", uuid, "with level", level)
    elseif _type == "update" then
      if not tClearances[uuid] then
        print("  That uuid doesn't exist! Use 'record add <uuid>' instead.")
        return
      elseif not tonumber(level) then
        print("  Usage: record update <uuid:string> <level:number>")
        return
      end
      local old = tClearances[uuid]
      UpdateRecord(uuid, tonumber(level))
      print("  Updated uuid", uuid, " (", old, "-->", level, ")")
    elseif _type == "remove" then
      if not tClearances[uuid] then
        print("  That uuid doesn't exist!")
      end
      UpdateRecord(uuid, nil)
      print("  Record for uuid", uuid, "removed.")
    elseif _type == "list" then
      for k, v in pairs(tClearances) do
        print(" ", k, v)
      end
    end
  end
  function actions.help(command)
    if not command or command == "help" then
      print("  Usage: help <commandname>")
      return
    elseif command == "record" then
      print("  Usage: record add <uuid:string> <level:string>")
      print("  Usage: record update <uuid:string> <level:string>")
      print("  Usage: record remove <uuid:string>")
      print("  Usage: record list")
      return
    end
    print("  No help records for", command)
  end
  function actions.commands()
    print("  Command, one of the following:")
    for k in pairs(actions) do
      print("   ", k)
    end
  end
  function actions.stop()
    error("Halted.", 0)
  end
  actions.halt = actions.stop

  if actions[chunks[1]] then
    actions[chunks[1]](table.unpack(chunks, 2, #chunks))
  else
    print("  No command", chunks[1])
  end
end

local function Main()
  DefineSettings()
  tClearances = LoadRecords()
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
        printWindow.redraw()
        Action(command)
      end
    end
  )
end

Main()
