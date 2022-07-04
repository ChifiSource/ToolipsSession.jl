"""
Created in June, 2022 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
### ToolipsSession
**Extension for:**
- [Toolips](https://github.com/ChifiSource/Toolips.jl) \
This module provides the capability to make web-pages interactive by simply
adding the Session extension to your ServerTemplate before starting. There are
also methods contained for modifying Servables.
##### Module Composition
- [**ToolipsSession**](https://github.com/ChifiSource/ToolipsSession.jl)
"""
module ToolipsSession
using Toolips
import Toolips: ServerExtension, Servable, Connection
import Base: setindex!, getindex, push!
using Random, Dates
include("Modifier.jl")

"""
**Session**
### gen_ref() -> ::String
------------------
Creates a random string of 16 characters. This is used to map connections
to specific events by the session.
#### example
```
gen_ref()
"jfuR2wgprielweh3"
```
"""
function gen_ref()
    Random.seed!( rand(1:100000) )
    randstring(16)
end

"""
### Session
- type::Vector{Symbol}
- f::Function
- active_routes::Vector{String}
- events::Dict{String, Pair{String, Function}}
- iptable::Dict{String, Dates.DateTime}
- timeout::Integer \
Provides session capabilities and full-stack interactivity to a toolips server.
Note that the route you want to be interactive **must** be in active_routes!
##### example
```
exts = [Session()]
st = ServerTemplate(extensions = exts)
server = st.start()

route!(server, "/") do c::Connection
    myp = p("myp", text = "welcome to my site")
    on(c, myp, "click") do cm::ComponentModifier
        if cm[myp][:text] == "welcome to my site"
            set_text!(cm, myp, "unwelcome to my site")
        else
            set_text!(cm, myp, "welcome to my site")
        end
    end
    write!(c, myp)
end
```
------------------
##### constructors
Session(active_routes::Vector{String} = ["/"];
        transition_duration::AbstractFloat = 0.5,
        transition::String = "ease-in-out",
        timeout::Integer = 30
        )
"""
mutable struct Session <: ServerExtension
    type::Vector{Symbol}
    f::Function
    active_routes::Vector{String}
    events::Dict
    iptable::Dict{String, Dates.DateTime}
    timeout::Integer
    function Session(active_routes::Vector{String} = ["/"];
        transition_duration::AbstractFloat = 0.5,
        transition::AbstractString = "ease-in-out", timeout::Integer = 30)
        events = Dict()
        timeout = timeout
        transition = transition
        iptable = Dict{String, Dates.DateTime}()
        f(c::Connection, active_routes = active_routes) = begin
            fullpath = c.http.message.target
            if contains(fullpath, '?')
                fullpath = split(c.http.message.target, '?')[1]
            end
            if fullpath in active_routes
                if ~(getip(c) in keys(iptable))
                    push!(events, getip(c) => Dict{String, Function}())
                    iptable[getip(c)] = now()
                else
                    if minute(now()) - minute(iptable[getip(c)]) >= timeout
                        kill!(c)
                    end
                end
                durstr = string(transition_duration, "s")
                write!(c, """<script>
                function sendpage(ref) {
                var ref2 = '?CM?:' + ref;
            var bodyHtml = document.getElementsByTagName('body')[0].innerHTML;
                sendinfo(bodyHtml + ref2);
                }
                function sendinfo(txt) {
                let xhr = new XMLHttpRequest();
                xhr.open("POST", "/modifier/linker");
                xhr.setRequestHeader("Accept", "application/json");
                xhr.setRequestHeader("Content-Type", "application/json");
                xhr.onload = () => eval(xhr.responseText);
                xhr.send(txt);
                }
                </script>
                <style type="text/css">
                #div {
                -webkit-transition: $durstr $transition;
                -moz-transition: $durstr $transition;
                -o-transition: $durstr $transition;
                transition: $durstr $transition;
                }
                </style>
                """)
            end
        end
        f(routes::Dict, ext::Dict) = begin
            routes["/modifier/linker"] = document_linker
        end
        new([:connection, :func, :routing], f, active_routes, events,
        iptable, timeout)
    end
end

"""
**Session Interface**
### getindex(m::Session, s::AbstractString) -> ::Vector{Pair}
------------------
Gets a session's refs by ip.
#### example
```
route("/") do c::Connection
    c[:Session][getip(c)]
end
```
"""
getindex(m::Session, s::AbstractString) = m.events[s]

"""
**Interface**
### on(f::Function, c::Connection, s::Component, event::AbstractString)
------------------
Creates a new event for the current IP in a session. Performs the function on
    the event. The function should take a ComponentModifier as an argument.
#### example
```
route("/") do c::Connection
    myp = p("hello", text = "wow")
    timer = TimedTrigger(5000) do cm::ComponentModifier
        if cm[myp][:text] == "wow"
            c[:Logger].log("wow.")
        end
    end
    write!(c, myp)
    write!(c, timer)
end
```
"""
function on(f::Function, c::Connection, s::Component,
     event::AbstractString)
    name = s.name
    s["on$event"] = "sendpage('$event$name');"
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], "$event$name" => f)
    else
        c[:Session][getip(c)] = Dict("$event$name" => f)
    end
end

"""
**Session Interface**
### on(f::Function, c::Connection, event::AbstractString)
------------------
Creates a new event for the current IP in a session. Performs the function on
    the event. The function should take a ComponentModifier as an argument.
#### example
```
route("/") do c::Connection
    myp = p("hello", text = "wow")
    on(c, "load") do cm::ComponentModifier
        set_text!(cm, myp, "not so wow")
    end
    write!(c, myp)
end
```
"""
function on(f::Function, c::Connection, event::AbstractString)
    ref = gen_ref()
    write!(c,
        "<script>document.addEventListener('$event', sendpage($ref));</script>")
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], "$ref" => f)
    else
        c[:Session][getip(c)] = Dict("$ref" => f)
    end
end

"""
**Session Interface**
### on_keydown(f::Function, c::Connection, key::AbstractString)
------------------
Creates a new event for the current IP in a session. Performs f when the key
    is pressed.
#### example
```

```
"""
function on_keydown(f::Function, c::Connection, key::String)
    write!(c, """<script>
    document.addEventListener('keydown', function(event) {
        if (event.key == "$key") {
        sendpage(event.key);
        }
    });</script>
    """)
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], key => f)
    else
        c[:Session][getip(c)] = Dict(ref => f)
    end
end

"""
**Session Interface**
### on_keyup(f::Function, c::Connection, key::AbstractString)
------------------
Creates a new event for the current IP in a session. Performs f when the key
    is brought up.
#### example
```

```
"""
function on_keyup(f::Function, c::Connection, key::String)
    write!(c, """<script>
    document.addEventListener('keyup', function(event) {
        if (event.key == "$key") {
        sendpage(event.key);
        }
    });</script>
    """)
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], key => f)
    else
        c[:Session][getip(c)] = Dict(ref => f)
    end
end

"""
**Session Internals**
### document_linker(c::Connection) -> _
------------------
Served to /modifier/linker by the Session extension. This is where incoming
data is posted to for a response.
#### example
```

```
"""
function document_linker(c::Connection)
    s::String = getpost(c)
    reftag::String = findall("?CM?:", s)
    ref_r::UnitRange = reftag[1][2] + 4:length(s)
    ref::String = s[ref_r]
    s = replace(s, "?CM?:$ref" => "")
    cm::ComponentModifier = ComponentModifier(s)
    if getip(c) in keys(c[:Session].iptable)
        c[:Session].iptable[getip(c)] = now()
    else
        write!(c, "timeout"); return
    end
    if getip(c) in keys(c[:Session].events)
        c[:Session][getip(c)][ref](cm)
        write!(c, " ")
        write!(c, cm)
    else
        write!(c, "timeout")
    end
end

"""
**Session Interface**
### remove!(c::Connection, fname::AbstractString, s::Servable) -> _
------------------
Removes a given function call from a connection's Session.
#### example
```

```
"""
function remove!(c::Connection, fname::AbstractString, s::Servable)
    refname = s.name * fname
    delete!(c[:Session][getip()], refname)
end

"""
**Session Interface**
### kill!(c::Connection)
------------------
Kills a Connection's saved events.
#### example
```

```
"""
function kill!(c::Connection)
    delete!(c[:Session].iptable, getip(c))
    delete!(c[:Session].events, getip(c))
end


export Session, on, on_keydown, on_keyup
export TimedTrigger, observe!, ComponentModifier, animate!, pauseanim!
export playanim!, alert!, redirect!, modify!, move!, remove!, set_text!
export set_children!, get_text, style!, free_redirects!, confirm_redirects!

end # module
