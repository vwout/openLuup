#!/usr/bin/env wsapi.cgi

module(..., package.seeall)


ABOUT = {
  NAME          = "console.lua",
  VERSION       = "2018.03.23",
  DESCRIPTION   = "console UI for openLuup",
  AUTHOR        = "@akbooer",
  COPYRIGHT     = "(c) 2013-2018 AKBooer",
  DOCUMENTATION = "https://github.com/akbooer/openLuup/tree/master/Documentation",
  LICENSE       = [[
  Copyright 2013-18 AK Booer

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]
}

-- 2017.04.26  HTML menu improvement by @explorer (thanks!)
-- 2017.07.05  add user_data, status and sdata to openLuup menu

-- 2018.01.30  add invocations count to job listing
-- 2018.03.19  add Servers menu

-- TODO: HTML pages with sorted tables
-- see: https://www.w3schools.com/w3js/w3js_sort.asp

--  WSAPI Lua implementation

local lfs       = require "lfs"                   -- for backup file listing
local url       = require "socket.url"            -- for url unescape
local luup      = require "openLuup.luup"
local json      = require "openLuup.json"
local scheduler = require "openLuup.scheduler"    -- for job_list, delay_list, etc...
local xml       = require "openLuup.xml"          -- for escape()
local requests  = require "openLuup.requests"     -- for user_data, status, and sdata
local server    = require "openLuup.server"
local smtp      = require "openLuup.smtp"

local _log    -- defined from WSAPI environment as wsapi.error:write(...) in run() method.

local console_html = {

prefix = [[
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Console</title>
    <style>
      *    { box-sizing:border-box; margin:0px; padding:0px; }
      html { width:100%; height:100%; overflow:hidden; border:none 0px; }
      body { font-family:Arial; background:LightGray; width:100%; height:100%; overflow:hidden; padding-top:60px; }
      
      .menu { position:absolute; top:0px; width:100%; height:60px; }
      .content { width:100%; height:100%; overflow:scroll; padding:4px; }
      
      .dropbtn {
        background-color: Sienna;
        color: white;
        padding: 16px;
        font-size: 16px;
        line-height:18px;
        vertical-align:middle;
        border: none;
        cursor: pointer;
      }

      .dropdown {
        position: relative;
        display: inline-block;
      }

      .dropdown-content {
        display: none;
        position: absolute;
        background-color: Sienna;
        min-width: 160px;
        border-top:1px solid Gray;
        box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.5);
      }

      .dropdown-content a {
        color: white;
        padding: 12px 16px;
        text-decoration: none;
        display: block;
      }

      .dropdown-content a:hover {background-color: SaddleBrown}

      .dropdown:hover .dropdown-content {
        display: block;
      }

      .dropdown:hover .dropbtn {
        background-color: SaddleBrown;
      }
    </style>
  </head>
    <body>
    
    <div class="menu" style="background:DarkGrey;">
    
      <div class="dropdown" >
        <img src="https://avatars.githubusercontent.com/u/4962913" alt="X"  
                style="width:60px;height:60px;border:0;vertical-align:middle;">
      </div>

      <div class="dropdown">
        <button class="dropbtn">openLuup</button>
        <div class="dropdown-content">
          <a class="left" href="/console?page=about">About</a>
          <a class="left" href="/console?page=parameters">Parameters</a>
        </div>
      </div>

      <div class="dropdown">
        <button class="dropbtn">Scheduler</button>
        <div class="dropdown-content">
          <a class="left" href="/console?page=jobs">Jobs</a>
          <a class="left" href="/console?page=delays">Delays</a>
          <a class="left" href="/console?page=watches">Watches</a>
          <a class="left" href="/console?page=startup">Startup Jobs</a>
        </div>
      </div>

      <div class="dropdown">
        <button class="dropbtn">Servers</button>
        <div class="dropdown-content">
          <a class="left" href="/console?page=http">HTTP Web</a>
          <a class="left" href="/console?page=smtp">SMTP eMail</a>
        </div>
      </div>

      <div class="dropdown">
        <button class="dropbtn">Logs</button>
        <div class="dropdown-content">
          <a class="left" href="/console?page=log">Log</a>
          <a class="left" href="/console?page=log&version=1">Log.1</a>
          <a class="left" href="/console?page=log&version=2">Log.2</a>
          <a class="left" href="/console?page=log&version=3">Log.3</a>
          <a class="left" href="/console?page=log&version=4">Log.4</a>
          <a class="left" href="/console?page=log&version=5">Log.5</a>
          <a class="left" href="/console?page=log&version=startup">Startup Log</a>
        </div>
      </div>

      <div class="dropdown">
        <button class="dropbtn">Backups</button>
        <div class="dropdown-content">
          <a class="left" href="/console?page=backups">Files</a>
        </div>
      </div>
    </div>
    <div class="content">
    <pre>
]],
--     <div style="overflow:scroll; height:500px;">

  postfix = [[
    </pre>
    </div>

  </body>
</html>

]]
}

local state =  {[-1] = "No Job", [0] = "Wait", "Run", "Error", "Abort", "Done", "Wait", "Requeue", "Pending"} 
local line = "%20s  %8s  %12s  %s %s"
local date = "%Y-%m-%d %H:%M:%S"


-- global entry point called by WSAPI connector

--[[

The environment is a Lua table containing the CGI metavariables (at minimum the RFC3875 ones) plus any 
server-specific metainformation. It also contains an input field, a stream for the request's data, 
and an error field, a stream for the server's error log. 

The input field answers to the read([n]) method, where n is the number
of bytes you want to read (or nil if you want the whole input). 

The error field answers to the write(...) method.

return values: the HTTP status code, a table with headers, and the output iterator. 

--]]

function run (wsapi_env)
  _log = function (...) wsapi_env.error:write(...) end      -- set up the log output, note colon syntax

  local lines     -- print buffer
  local function print (a,b)
    local fmt = "%5s %s \n"
    lines[#lines+1] = fmt: format (a, b or '')
  end

  local job_list = scheduler.job_list
  local startup_list = scheduler.startup_list
  local delay_list = scheduler.delay_list ()

  local function joblist (job_list)
    local jlist = {}
    for _,b in pairs (job_list) do
      local status = table.concat {state[b.status] or '', '[', b.logging.invocations, ']'}
      jlist[#jlist+1] = {
        t = b.expiry,
        l = line: format (os.date (date, b.expiry + 0.5), b.devNo or "system", 
                            status, b.type or '?', b.notes or '')
      }
    end
    return jlist
  end

  local function watchlist ()
    local W = {}
    local line = "%5s   :watch   %s (%s.%s.%s)"
    local function isW (w, d,s,v)
      if next (w.watchers) then
        for _, what in ipairs (w.watchers) do
          W[#W+1] = line:format (what.devNo, what.name or '?', d,s or '*',v or '*')
        end
      end
    end

    for d,D in pairs (luup.devices) do
      isW (D, d)
      for s,S in pairs (D.services) do
        isW (S, d,s)
        for v,V in pairs (S.variables) do
          isW (V, d,s,v)
        end
      end
    end

    print ("Variable Watches, " .. os.date "%c")
    print ('#', line: format ('dev', 'callback', "device","serviceId","variable"))
    table.sort (W)
    for i,w in ipairs (W) do
      print (i,w)
    end    
  end
  
  local jlist = joblist (job_list)
  local slist = joblist (startup_list)

  local dlist = {}
  local delays = "%4.0fs :callback %s"
  for _,b in pairs (delay_list) do
    local dtype = delays: format (b.delay, b.type or '')
    dlist[#dlist+1] = {
      t = b.time,
      l = line: format (os.date (date, b.time), b.devNo, "Delay", dtype, '')
    }
  end

  local function listit (list, title)
    print (title .. ", " .. os.date "%c")
    table.sort (list, function (a,b) return a.t < b.t end)
    print ('#', (line: format ("date       time    ", "device", "status[n]","info", '')))
    for i,x in ipairs (list) do print (i, x.l) end
    print ''
  end

  local function printlog (p)
    local name = luup.attr_get "openLuup.Logfile.Name" or "LuaUPnP.log"
    local ver = p.version
    if ver then
      if ver == "startup" then
        name = "logs/LuaUPnP_startup.log"
      else
        name = table.concat {name, '.', ver}
      end
    end
    local f = io.open (name)
    if f then
      local x = f:read "*a"
      f: close()
      print (xml.escape (x))       -- thanks @a-lurker
    end
  end
  
  local function backups (p)
    local dir = luup.attr_get "openLuup.Backup.Directory" or "backup/"
    print ("Backup directory: ", dir)
    print ''
    local pattern = "backup%.openLuup%-%w+%-([%d%-]+)%.?%w*"
    local files = {}
    for f in lfs.dir (dir) do
      local date = f: match (pattern)
      if date then
        local attr = lfs.attributes (dir .. f) or {}
        local size = tostring (math.floor (((attr.size or 0) + 500) / 1e3))
        files[#files+1] = {date = date, name = f, size = size}
      end
    end
    table.sort (files, function (a,b) return a.date > b.date end)       -- newest to oldest
    local list = "%-12s %4s   %s"
    print (list:format ("yyyy-mm-dd", "(kB)", "filename"))
    for _,f in ipairs (files) do 
      print (list:format (f.date, f.size, f.name)) 
    end
  end
  
  local function uncompressform ()
    print [[
 <form action="/console">
    <input type="hidden" name="page" value="uncompress">
    <input type="file" name="unlzap" accept=".lzap" formmethod="get">
    <label for="file">Choose a file</label>
    <input type="Submit" value="Uncompress" class="dropbtn"><br>
 </form>     
    ]]
  end
  
  local function uncompress (p)
    for a,b in pairs(p) do
      print (a .. " : " .. tostring(b))
    end
--    local codec = compress.codec (nil, "LZAP")        -- full-width binary codec with header text
--    local code = compress.lzap.decode (code, codec)   -- uncompress the file
-- TODO:  UNCOMPRESS... following code lifted from backup module compression
--[[
    local f
    f, msg = io.open (fname, 'wb')
    if f then 
      local codec = compress.codec (nil, "LZAP")  -- full binary codec with header text
      small = compress.lzap.encode (ok, codec)
      f: write (small)
      f: close ()
      ok = #ok / 1000    -- convert to file sizes
      small = #small / 1000
    else
      ok = false
    end
  end
  
  local headers = {["Content-Type"] = "text/plain"}
  local status, return_content
  if ok then 
    msg = ("%0.0f kb compressed to %0.0f kb (%0.1f:1)") : format (ok, small, ok/small)
    local body = html: format (msg, fname, fname)
    headers["Content-Type"] = "text/html"
    status, return_content = 200, body
  else
    status, return_content = 500, "backup failed: " .. msg
  end
  _log (msg)

--]]

  end

  local function number (n) return ("%7d  "): format (n) end

  local function httplist ()
    local layout = "     %-42s %s %s"
    local function printout (a,b,c) print (layout: format (a,b or '',c or '')) end
    
    local function printinfo (requests)
      local calls = {}
      for name in pairs (requests) do calls[#calls+1] = name end
      table.sort (calls)
      for _,name in ipairs (calls) do
        local call = requests[name]
        local count = call.count
        local status = call.status
        if count and count > 0 then
          printout (name, "  "..status, number(count))
        end
      end
    end
    
    print ("HTTP Web Server, " .. os.date "%c")
    
    print "\n Most recent incoming connections:"
    printout ("IP address", "date       time")
    for ip, req in pairs (server.iprequests) do
      printout (ip, os.date(date, req.date))
    end
    
      print "\n /data_request?"
      printout ("id=... ","status", " #requests")
      printinfo (server.http_handler)
      
      print "\n CGI requests"
      printout ("URL ","status"," #requests")
      printinfo (server.cgi_handler)
      
      print "\n File requests"
      printout ("filename ","status"," #requests")
      printinfo (server.file_handler)
    
  end
  
  local function smtplist ()
    local layout = "     %-32s %s %s"
    local none = "--- none ---"
    local function printout (a,b,c) print (layout: format (a,b or '',c or '')) end
    
    local function devname (d)
      local d = tonumber(d) or 0
      local name = (luup.devices[d] or {}).description or 'system'
      return table.concat {'[', d, '] ', name: match "^%s*(.+)"}
    end
    
    print ("SMTP eMail Server, " .. os.date "%c")
    
    print "\n Received connections:"
    printout("IP address", "#connects", "    date     time\n")
    if not next (smtp.iprequests) then printout (none) end
    for ip, req in pairs (smtp.iprequests) do
      local connects = number (req.connects)
      printout (ip, connects, os.date(date, req.date))
    end
    
    print "\n Registered email sender IPs:"
    printout ("IP address", "#messages", "for device\n")
    local n = 0
    for ip,dest in pairs (smtp.destinations) do
      local name = devname (dest.devNo)
      local count = number (dest.count)
      if not ip: match "@" then n=n+1; printout (ip, count, name) end
    end
    if n == 0 then printout (none) end
    
    print "\n Registered destination mailboxes:"
    printout ("eMail address", "#messages", "for device\n")
    for email,dest in pairs (smtp.destinations) do
      local name = devname (dest.devNo)
      local count = number (dest.count)
      if email: match "@" then printout (email, count, name) end
    end
    
    print "\n Blocked senders:"
    printout ("eMail address", '', '\n')
    if not next (smtp.blocked) then printout (none) end
    for email in pairs (smtp.blocked) do
      printout (email)
    end
  end
  
  
  local pages = {
    about   = function () for a,b in pairs (ABOUT) do print (a .. ' : ' .. b) end end,
    backups = backups,
    delays  = function () listit (dlist, "Delayed Callbacks") end,
    jobs    = function () listit (jlist, "Scheduled Jobs") end,
    log     = printlog,
    startup = function () listit (slist, "Startup Jobs") end,
    watches = watchlist,
    http    = httplist,
    smtp    = smtplist,
    
    uncompress      = uncompress,
    uncompressform  = uncompressform,
    
    parameters = function ()
      local info = luup.attr_get "openLuup"
      local p = json.encode (info or {})
      print (p or "--- none ---")
    end,
    
    userdata = function ()
      local u = requests.user_data()
      print(u)
    end,
    
    status = function ()
      local s = requests.status()
      print(s)
    end,
    
    sdata = function ()
      local d = requests.sdata()
      print(d)
    end,
    
  }

  
  -- unpack the parameters and read the data
  local p = {}
  for a,b in (wsapi_env.QUERY_STRING or ''): gmatch "([^=]+)=([^&]*)&?" do
    p[a] = url.unescape (b)
  end
  
  lines = {console_html.prefix}
  local status = 200
  local headers = {}
  
  local page = p.page or ''
  
  do (pages[page] or function () end) (p) end
  headers["Content-Type"] = "text/html"
  
  print (console_html.postfix)
  local return_content = table.concat (lines)

  
  local function iterator ()     -- one-shot iterator, returns content, then nil
    local x = return_content
    return_content = nil 
    return x
  end

  return status, headers, iterator
end

-----
