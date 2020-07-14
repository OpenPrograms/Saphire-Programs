--This "downloader" was initially
--hacked together by Saphire Lattice
--on BTM16 (January 2nd and 3rd)

local shell = require("shell")
local args, opts = shell.parse(...)
local c = require("component")
local internet = require("internet")
local term = require("term")
local tape

if opts["A"] then
    if type(opts["A"]) ~= "string" then
        print("Usage of flag A:")
        print("    ytdl --A=address ...")
        os.exit(1)
    end
    tape = c.proxy(c.get(opts["A"]))
    print("Using tape drive ["..tape.address.."]")
else
    tape = c.tape_drive
    print("Using tape drive ["..tape.address.."]")
    i = 0
    for k in c.list("tape_drive") do
        i = i + 1
    end
    if i > 1 then
        print("WARNING! More than one tape drive detected! Are you sure you want to continue? [y/N]")
        if string.lower(string.sub(io.read(), 1, 1))~="y" then print("Exiting!") os.exit(1) end
    end
end

local base_site = "http://dfpwm.catgirl.services"
local base_bitrate = 48
local base_conv_url = base_site .. "/aconv"

if not opts["a"] and opts["o"] then
    base_conv_url = base_site .. "/conv"
    base_bitrate = 32
end

local bitrate = base_bitrate

if opts["b"] or opts["bitrate"] then
    if not tonumber(opts["b"] or opts["bitrate"]) then
        print("Please set option `b` to the desired bitrate (as a number).")
        os.exit(1)
    end
    bitrate = tonumber(opts["b"] or opts["bitrate"])
    local ratio = bitrate / base_bitrate
    if ratio < 0.25 or ratio > 2 then
        print(string.format("Bitrate cannot be set to thisi value, min %d, max %d.", math.floor(base_bitrate / 4), math.floor(base_bitrate * 2)))
        os.exit(1)
    end
else
    if opts["d"] then
        bitrate = bitrate * 2
    end
end

if not args[1] then
    print("Usage: ytdl - [options: dAscRaot] [list of youtube video IDs or URLs].")
    print("Options: d - Use double the default bitrate (96K for v1a or 64K for v1). More quality but bigger size.")
    print("         A - Set address of tape to be used. Can be partial.")
    print("         s - Skip download of video. Mostly for titling untitled tapes.")
    print("         c - Continious write to the tape. Title of last video will be used as title if required.")
    print("         a - Use DFPWM 1a. Default, priority over flag o.")
    print("         o - Use older DFPWM 1 format, pre-1.8.9. Can be played later, but speed needs to be adjusted")
    print("         t/title    - DISABLES automatic titling of tapes. Sets title if it's a string.")
    print("         b/bitrate  - Set bitrate. Negates effects of `d`. Minimum 12 or 8, maximum 96 or 64. Usage: --b=number")
    print("Missing argument(s)! No video id/link passed as argument(s).")
    return
end

local getId = function(str)
    if string.find(str, "youtube.com") then
        _a, _b,id = string.find(str, "v=([a-zA-Z0-9_-]+)")
    elseif string.find(str, "youtu.be/") then
        _a, _b, id = string.find(str, "be/([a-zA-Z0-9_-]+)")
    else
        id = str
    end
    return id
end

local function printSize(bytes)
    print(string.format("Total downloaded: % 10d bytes", bytes))
end

local function downloadAudio(id, l_bitrate)
    local b_size = bitrate * 256
    print("Downloading " .. id)

    local url = base_conv_url .. (tostring(l_bitrate) or "") .. "/" .. id
    local h = internet.request(url)
    local size = 0
    printSize(size)
    local x, y = term.getCursor()
    chunk = ""
    for a in h do
        size = size + #a
        chunk = chunk .. a
        if #chunk > b_size then
            tape.write(chunk)
            chunk = ""
        end
        term.setCursor(x, y-1)
        printSize(size)
    end
    if chunk~="" and #chunk > b_size then
        tape.write(chunk)
    end
    print("Done downloading "..id.."!")
end

local function setLabel(id, needCont)
    local cont = cont or false
    if opts["t"] and type(opts["t"]) == "string" and opts["c"] == cont then
        print("Using option -t value as tape label!")
        tape.setLabel(opts["t"])
    elseif not opts["t"] and opts["c"] == cont then
        print("Using youtube title as tape label!")
        local h = internet.request(base_site .. "/title/" .. yt_id)
        local d = ""
        for a in h do
            d = d .. a
        end
        local web_title = string.gsub(d,"\n","")
        tape.setLabel(web_title.." ["..tostring(bitrate).."K]")
        print("New label: " .. web_title)
    end
end

tape.stop()
if not opts["c"] then
    tape.seek(-math.huge)
end

for k,v in pairs(args) do
    local yt_id = getId(v)
    if not opts["s"] then
        downloadAudio(yt_id, bitrate)
    else
        print("Skipping download of " .. yt_id .. "!")
    end

    setLabel(yt_id, false)

    print("------")
end

setLabel(yt_id, true)

tape.setSpeed(bitrate / base_bitrate)
print("Using bitrate "..tostring(bitrate).."K, speed is set to "..tostring(bitrate / base_bitrate))

if not opts["c"] then
    tape.seek(-math.huge)
    print("Tape rewound.")
end
