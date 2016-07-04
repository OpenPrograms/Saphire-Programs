--This "downloader" was initially
--hacked together by Saphire Lattice
--on BTM16 (January 2nd and 3rd)
(function(...)
 local shell = require("shell")
 local args, opts = shell.parse(...)
 local c = require("component")
 local internet = require("internet")
 local term = require("term")
 local tape

 if opts["a"] then
     tape = c.proxy(c.get(opts["a"]))
     print("Using tape drive ["..tape.address.."]")
 else
     print("Using tape drive ["..tape.address.."]")
     i = 0
     for k in c.list("tape_drive") do
         i = i + 1
     end
     if i > 1 then
         print("WARNING! More than one tape drive detected! Are you sure you want to continue? [y/N]")
         if string.lower(string.sub(io.read(), 1, 1))~="y" then print("Exiting!") return end
     end
     tape = c.tape_drive
 end

 local b_size = 8 * 1024-- size of block/chunk that's written to tape
 local base_bitrate = 32
 local base_conv_url = "http://dfpwm.magik6k.net/conv"

 if opts["a"] then
     local base_conv_url = "http://dfpwm.magik6k.net/aconv"
     b_size = 12 * 1024
     base_bitrate = 48
 end

 local bitrate = base_bistrate

 if opts["b"] then
     if not tonumber(opts["b"]) then
         print("Please set option `b` to the desired bitrate (as a number).")
         return
     end
     bitrate = tonumber(opts["b"])
 else
     if opts["d"] then
        bitrate = bitrate * 2
     end
 end

 if not args[1] then
     print("Usage: ytdl - [options: dtsca] [list of youtube video IDs or URLs].")
     print("Options: d - Use double (64K or 96K) bitrate.")
     print("         b - Set bitrate. Negates effects of `d`.")
     print("         t - DISABLES automatic titling of tapes. Sets title if it's a string.")
     print("         s - Skip download of video. Mostly for titling untitled tapes.")
     print("         c - Continious write to the tape. Title of last video will be used as title if required.")
     print("         a - Use DFPWM 1a.")
     print("Missing argument(s)! No video id/link passed as argument(s). I can't read minds, you know?")
     return
 end

 local getId = function(str)
     if string.find(str, "youtube.com") then
         _a, _b,id = string.find(str, "v=([a-zA-Z0-9_-]+)")
     elseif string.find(str, "youtu.be") then
         _a, _b, id = string.find(str, "be/([a-zA-Z0-9_-]+)")
     else
         id = str
     end
     return id
 end

 local convertWrite = function(id, l_bitrate)
     print("Downloading " .. id)
     tape.seek(-tape.getSize())
     local url = base_conv_url .. (tostring(l_bitrate) or "") .. "/" .. id
     local h = internet.request(url)
     local size = 0
     print("Total downloaded: " .. string.rep(" ", 10 - #tostring(size)) .. "0" .. " bytes         " )
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
         print("Total downloaded: "..string.rep(" ",10-#tostring(size))..tostring(size).." bytes         ")
     end
     if chunk~="" and #chunk > b_size then
         tape.write(chunk)
     end
     print("Done downloading "..id.."!")
 end

 tape.stop()
 if not opts["c"] then
     tape.seek(tape.getSize())
 end
 for k,v in pairs(args) do
     local yt_id = getId(v)
     if not opts["s"] then
         convertWrite(yt_id, bitrate)
     else
         print("Skipping download of " .. yt_id .. "!")
     end

     if opts["t"] and type(opts["t"]) == "string" and not opts["c"] then
         tape.setLabel(opts["t"])
     elseif not opts["t"] and not opts["c"] then
         print("Using youtube title as tape label!")
         local h = internet.request("http://dfpwm.magik6k.net/title/" .. yt_id)
         local d = ""
         for a in h do
             d = d .. a
         end
         local web_title = string.gsub(d,"\n","")
         tape.setLabel(web_title.." ["..tostring(bitrate).."K]")
         print("New label: " .. web_title)
     end
     print("------")
 end

 if not opts["t"] and opts["c"] then
     print("Using _last_ youtube title as tape label!")
     local h = internet.request("http://dfpwm.magik6k.net/title/"..getId(args[#args]))
     local d = ""
     for a in h do
         d = d..a
     end
     local web_title = string.gsub(d,"\n","")
     tape.setLabel(web_title.." ["..tostring(bitrate).."K]")
 elseif opts["t"] and opts["t"] then
 end

 tape.setSpeed(bitrate/base_bitrate)
 print("Using bitrate "..tostring(bitrate).."K, speed is set to "..tostring(bitrate/32))

 tape.seek(-tape.getSize())
 print("Tape rewound.")
end)(...)
print("Exiting `ytdl`")
