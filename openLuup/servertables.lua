-- mimetypes
-- 2016/04/14
-- thanks to @explorer for suggesting a separate file

-- these entries are used to determine the response type of HTML
-- file transfer requests using the file extension code
-- syntax is extension = "return type",
-- feel free to add what you need

-- 2016.07.14  added status_codes for server response
-- 2016.10.17  added CGI prefixes and aliases
-- 2016.11.17  change location of graphite_cgi to openLuup folder
-- 2016.11.18  added CGI console.lua

-- 2018.02.19  added directory aliases (for file access requests)
-- 2018.03.06  added SMTP status codes
-- 2018.03.09  added myIP, moved from openLuup.server
-- 2018.03.15  updated SMTP reply codes according to RFC 5321

-- http://forums.coronalabs.com/topic/21105-found-undocumented-way-to-get-your-devices-ip-address-from-lua-socket/

local socket = require "socket"

local function myIP ()    
  local mySocket = socket.udp ()
  mySocket:setpeername ("42.42.42.42", "424242")  -- arbitrary IP and PORT
  local ip = mySocket:getsockname () 
  mySocket: close()
  return ip or "127.0.0.1"
end


local mimetypes = {
  css  = "text/css", 
  gif  = "image/gif",
  html = "text/html", 
  htm  = "text/html", 
  ico  = "image/x-icon",
  jpeg = "image/jpeg",
  jpg  = "image/jpeg",
  js   = "application/javascript",
  json = "application/json",
  mid  = "audio/mid",
  mp3  = "audio/mpeg",
  png  = "image/png",
  txt  = "text/plain",
  wav  = "audio/wav",
  xml  = "application/xml",
}


-- HTTP status codes (from wsapi.common)
local status_codes = {
   [100] = "Continue",
   [101] = "Switching Protocols",
   [200] = "OK",
   [201] = "Created",
   [202] = "Accepted",
   [203] = "Non-Authoritative Information",
   [204] = "No Content",
   [205] = "Reset Content",
   [206] = "Partial Content",
   [300] = "Multiple Choices",
   [301] = "Moved Permanently",
   [302] = "Found",
   [303] = "See Other",
   [304] = "Not Modified",
   [305] = "Use Proxy",
   [307] = "Temporary Redirect",
   [400] = "Bad Request",
   [401] = "Unauthorized",
   [402] = "Payment Required",
   [403] = "Forbidden",
   [404] = "Not Found",
   [405] = "Method Not Allowed",
   [406] = "Not Acceptable",
   [407] = "Proxy Authentication Required",
   [408] = "Request Time-out",
   [409] = "Conflict",
   [410] = "Gone",
   [411] = "Length Required",
   [412] = "Precondition Failed",
   [413] = "Request Entity Too Large",
   [414] = "Request-URI Too Large",
   [415] = "Unsupported Media Type",
   [416] = "Requested range not satisfiable",
   [417] = "Expectation Failed",
   [500] = "Internal Server Error",
   [501] = "Not Implemented",
   [502] = "Bad Gateway",
   [503] = "Service Unavailable",
   [504] = "Gateway Time-out",
   [505] = "HTTP Version not supported",
}


local smtp_codes = {
  [211] = "System status, or system help reply",
  [214] = "Help message",
  [220] = "%s Service ready",                                               -- <domain>
  [221] = "%s Service closing transmission channel",                        -- <domain>
  [250] = "OK",      -- Requested mail action okay
  [251] = "User not local; will forward to <%s>",                             -- <forward-path>
  [252] = "Cannot VRFY user, but will accept message and attempt delivery",
  [354] = "Start mail input; end with <CRLF>.<CRLF>",
  [421] = "%s Service not available, closing transmission channel",         -- <domain>
  [450] = "Requested mail action not taken: mailbox <%s> unavailable",        -- <mailbox>
  [451] = "Requested action aborted: local error in processing",
  [452] = "Requested action not taken: insufficient system storage",
  [455] = "Server unable to accommodate parameters",
  [500] = "Syntax error, command <%s> unrecognized",                           -- <command>
  [501] = "Syntax error in parameters or arguments <%s>",
  [502] = "Command <%s> not implemented",                                      -- <command>
  [503] = "Bad sequence of commands",
  [504] = "Command parameter not implemented",
  [550] = "Requested action not taken: <%s> unavailable",                       -- <mailbox>
  [551] = "User not local; please try <%s>",                                   -- <forward-path>
  [552] = "Requested mail action aborted: exceeded storage allocation",
  [553] = "Requested action not taken: mailbox name not allowed",
  [554] = "Transaction failed",
  [555] = "MAIL FROM/RCPT TO parameters not recognized or not implemented",
}


-- CGI prefixes: HTTP requests with any of these path roots are treated as CGIs
local cgi_prefix = {
    "cgi",          -- standard CGI directory
    "cgi-bin",      -- ditto
    
    "console",      -- openLuup console interface
    
    "dashboard",    -- for graphite_api (requires DataYours plugin)
    "metrics",      -- ditto
    "render",       -- ditto
    
    "upnp",         -- for Luup HAG requests --- DEPRECATED, Feb 2018 ---
    
    "ZWaveAPI",     -- Z-Wave.me Advanced API (requires Z-Way plugin)
    "ZAutomation",  -- Z-Wave.me Virtual Device API
  }

-- CGI aliases: any matching full CGI path is redirected accordingly

local graphite_cgi = "openLuup/graphite_cgi.lua"

local cgi_alias = setmetatable ({
    
    ["cgi-bin/cmh/backup.sh"]     = "openLuup/backup.lua",
    ["cgi-bin/cmh/sysinfo.sh"]    = "openLuup/sysinfo.lua",
    ["upnp/control/hag"]          = "openLuup/hag.lua", --- DEPRECATED, Feb 2018 ---
    ["console"]                   = "openLuup/console.lua",
    
    -- graphite_api support
    ["metrics"]             = graphite_cgi,
    ["metrics/find"]        = graphite_cgi,
    ["metrics/expand"]      = graphite_cgi,
    ["metrics/index.json"]  = graphite_cgi,
    ["render"]              = graphite_cgi,
  },
  
  -- special handling of Zway requests (all directed to same handler)
  { __index = function (_, path)
      if path: match "^ZWaveAPI"
      or path: match "^ZAutomation" then
        return "cgi/zway_cgi.lua"
      end
    end
  })

-- Directory redirect aliases

local dir_alias = {
    ["cmh/skins/default/img/devices/device_states/"] = "icons/",  -- redirect UI7 icon requests
    ["cmh/skins/default/icons/"] = "icons/",                      -- redirect UI5 icon requests
    ["cmh/skins/default/img/icons/"] = "icons/" ,                 -- 2017.11.14 
  }
  
--

return {
    myIP          = myIP (),
    cgi_prefix    = cgi_prefix,
    cgi_alias     = cgi_alias,
    dir_alias     = dir_alias,
    mimetypes     = mimetypes,
    smtp_codes    = smtp_codes,     -- SMTP
    status_codes  = status_codes,   -- HTTP
  }
  
-----
