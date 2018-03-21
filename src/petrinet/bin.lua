#! /usr/bin/env lua

package.path = "./src/?.lua;./src/?/init.lua;".. package.path

local Arguments = require "argparse"
local Et        = require "etlua"
local Analysis  = require "petrinet.analysis"

local parser = Arguments () {
  name        = "petri-sport",
  description = "",
}
parser:argument "petrinet" {
  description = "Petri net file to load",
  default     = "petrinet.example",
  convert     = function (x)
    if x:match ".lua$" then
      return assert (loadfile (x, "r"))
    else
      return require (x)
    end
  end,
}
parser:option "--free" {
  description = "number of free tokens",
  convert     = tonumber,
  default     = nil,
}
parser:flag "--deadlocks" {
  description = "show deadlocks",
  default     = false,
}

local arguments = parser:parse ()

do
  local state = State {
    petrinet = arguments.petrinet,
    free     = arguments.free or 0,
  }
  local dot      = state:to_dot ()
  local filename = os.tmpname ()
  local file     = io.open (filename, "w")
  file:write (dot)
  file:close ()
  os.execute (Et.render ([[
    neato -n -Tpdf <%- filename %> -o output.pdf
  ]], {
    filename = filename,
  }))
  os.remove (filename)
  print ("Model has been output in 'output.pdf'.")
end

local analysis  = Analysis {
  petrinet = arguments.petrinet,
}
for result in analysis (arguments.free) do
  print (Et.render ([[
- free tokens: <%- result.free %>
  choice:
    min  : <%- result.choice.min %>
    max  : <%- result.choice.max %>
    mean : <%- math.ceil (result.choice.mean*100)/100 %>
    ratio: <%- math.ceil (result.choice.ratio*100) %>%
  parallel:
    min  : <%- result.parallel.min %>
    max  : <%- result.parallel.max %>
    mean : <%- math.ceil (result.parallel.mean*100)/100 %>
    ratio: <%- math.ceil (result.parallel.ratio*100) %>%
  # of states     : <%- #result.states %>
  # of deadlocks  : <%- #result.deadlocks %>
  # of deadlocking: <%- #result.deadlocking %>
  % of deadlocking: <%- math.ceil (#result.deadlocking * 100 / #result.states) %>%
<% if arguments.deadlocks then -%>
<% for i, deadlock in ipairs (result.deadlocks) do -%>
  deadlock #<%- i %>:
    state : <%- deadlock.state %>
    path  : <%- deadlock.path %>
    length: <%- math.ceil (#deadlock.path / 2) %>
<% end -%>
<% end -%>]], {
    arguments = arguments,
    result    = result,
  }))
end
