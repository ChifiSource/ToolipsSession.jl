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
import Toolips: ServerExtension, Servable, Connection, AbstractComponent
import Toolips: AbstractRoute, kill!
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
function gen_ref(n::In64 = 16)
    Random.seed!( rand(1:100000) )
    randstring(n)::String
end

"""
### Session
- type::Vector{Symbol}
- f::Function
- active_routes::Vector{String}
- events::Dict{String, Pair{String, Function}}
- readonly::Dict{String, Vector{String}}
- iptable::Dict{String, Dates.DateTime}
- timeout::Integer\n
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
    events::Dict{String, Dict{String, Function}}
    readonly::Dict{String, Vector{String}}
    iptable::Dict{String, Dates.DateTime}
    peers::Dict{String, Dict{String, Vector{Servable}}}
    timeout::Integer
    function Session(active_routes::Vector{String} = ["/"];
        transition_duration::AbstractFloat = 0.5,
        transition::AbstractString = "ease-in-out", timeout::Integer = 30,
        path::AbstractRoute = Route("/modifier/linker", x -> 5))
        events = Dict{String, Dict{String, Function}}()
        peers::Dict{String, Dict{String, Vector{Servable}}} = Dict{String, Vector{Servable}}()
        iptable = Dict{String, Dates.DateTime}()
        readonly = copy(events)
        f(c::Connection, active_routes::Vector{String} = active_routes) = begin
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
        f(routes::Vector{AbstractRoute}, ext::Vector{ServerExtension}) = begin
            path.page = document_linker
            push!(routes, path)
        end
        new([:connection, :func, :routing], f, active_routes, events,
        readonly, iptable, peers, timeout)
    end
end


"""
**Session Interface**
### getindex(m::Session, s::AbstractString) -> ::Dict{String, Function}
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
**Session Interface**
### getindex(m::Session, d::Dict{String, Function}, s::AbstractString) -> _
------------------
Creates a new Session.
#### example
```
route("/") do c::Connection
    c[:Session][getip(c)] = Dict{String, Function}
end
```
"""
setindex!(m::Session, d::Any, s::AbstractString) = m.events[s] = d

"""
**Interface**
### on(f::Function, c::Connection, s::Component, event::AbstractString, readonly::Vector{String} = Vector{String})
------------------
Creates a new event for the current IP in a session. Performs the function on
    the event. The function should take a ComponentModifier as an argument.
#### example
```
route("/") do c::Connection
    myp = p("hello", text = "wow")
    on(c, myp, "click")
        if cm[myp][:text] == "wow"
            c[:Logger].log("wow.")
        end
    end
    write!(c, myp)
end
```
"""
function on(f::Function, c::Connection, s::AbstractComponent,
     event::AbstractString, readonly::Vector{String} = Vector{String}())
    name::String = s.name
    ip::String = string(getip(c))
    s["on$event"] = "sendpage('$event$name');"
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][ip], "$event$name" => f)
    else
        c[:Session].events[ip] = Dict("$event$name" => f)
    end
    if length(readonly) > 0
        c[:Session].readonly["$ip$event$name"] = readonly
    end
end

"""
**Session Interface**
### bind(f::Function, c::AbstractConnection, key::String;
    on::Symbol = :down, client::Bool == false)
------------------
The new interface for binding keys. Takes a a single key or series of keys. Note
    that when binding a series of keys, ctrl, alt and shift will become event keys.
    The **on** argument can be used to change whether this happens on key-up or
    keydown. **client** functions are another implementation that will be used
    to store functions on the client side for quicker access to different
        scripts (without Julia)
#### example
```

```
"""
function bind(f::Function, c::AbstractConnection, key::String;
    on::Symbol = :up, client::Bool = false)
    if client
        cm::Modifier = ClientModifier()
        f(cm)
        # now we write this into a into a binding for our script function name!
    end
end

"""
**Session Interface**
### bind(f::Function, c::AbstractConnection, Pair{Symbol, String};
    on::Symbol = :down, client::Bool == false)
------------------
The new interface for binding keys. Takes a a single key or series of keys. Note
    that when binding a series of keys, ctrl, alt and shift will become event keys.
    The **on** argument can be used to change whether this happens on key-up or
    keydown. **client** functions are another implementation that will be used
    to store functions on the client side for quicker access to different
        scripts (without Julia)
#### example
```

```
"""
function bind(f::Function, comp::AbstractComponent, c::AbstractConnection,
    keys::Vector{String}; on::Symbol = :up, client::Bool = false)
    if client
        cm::Modifier = ClientModifier()
        f(cm)
        # now we write this into a into a binding for our script function name!
    end
end

"""
**Session Interface**
### bind(f::Function, c::AbstractConnection, Pair{Symbol, Pair{Symbol, String}};
    on::Symbol = :down, client::Bool == false)
------------------
The new interface for binding keys. Takes a a single key or series of keys. Note
    that when binding a series of keys, ctrl, alt and shift will become event keys.
    The **on** argument can be used to change whether this happens on key-up or
    keydown. **client** functions are another implementation that will be used
    to store functions on the client side for quicker access to different
        scripts (without Julia)
#### example
```

```
"""
function bind(f::Function, comp::AbstractComponent, c::AbstractConnection,
    keys::Vector{String}; on::Symbol = :up, client::Bool = false)
    if client
        cm::Modifier = ClientModifier()
        f(cm)
        # now we write this into a into a binding for our script function name!
    end
end

function script!(f::Function, c::Connection, name::String, event::String,
    readonly::Vector{String} = Vector{String}(); time::Integer = 1000)
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], event => f)
    else
        c[:Session][getip(c)] = Dict(event => f)
    end
    obsscript = script(event, text = """
    new Promise(resolve => setIntervalimeout(sendpage('$event'), $time));
   """)
   if length(readonly) > 0
       c[:Session].readonly["$ip$event$name"] = readonly
   end
   return(obsscript)
end

#==
TODO We also need ClientModifier Scripts that can be binded with `on`. This
should be the ultimate goal, though not the current expectation. (this function
is not yet written) What we do is make the script into a `script component using
a modifier, that way we can create client functions on a whim and call them at
will. The implications of this are pretty sweet considering set_children!, and
other functions like that. I need to make more functions like that, as well.`
==#
function script(f::Function, name::String)
    modif::ClientModifier = ClientModifier()
    inner_f = f(modif)
end


"""
**Session Interface**
### on(f::Function, c::Connection, event::AbstractString, readonly::Vector{String} = Vector{String}())
------------------
Creates a new event for the current IP in a session. Performs the function on
    the event. The function should take a ComponentModifier as an argument.
    readonly will provide certain names to be read into the ComponentModifier.
    This can help to improve Session's performance, as it will need to parse
    less Components.
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
function on(f::Function, c::Connection, event::AbstractString,
    readonly::Vector{String} = Vector{String}())
    ref = gen_ref()
    write!(c,
        "<script>document.addEventListener('$event', sendpage($ref));</script>")
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], "$ref" => f)
    else
        c[:Session][getip(c)] = Dict("$ref" => f)
    end
    if length(readonly) > 0
        c[:Session].readonly["$ip$event$name"] = readonly
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
    ip::String = getip(c)
    reftag::Vector{UnitRange{Int64}} = findall("?CM?:", s)
    ref_r::UnitRange{Int64} = reftag[1][2] + 4:length(s)
    ref::String = s[ref_r]
    s = replace(s, "?CM?:$ref" => "")
    if ip in keys(c[:Session].iptable)
        c[:Session].iptable[ip] = now()
    end
    if ip in keys(c[:Session].events)
        if ip * ref in keys(c[:Session].readonly)
            cm::ComponentModifier = ComponentModifier(s, c[:Session].readonly[ip * ref])
        else
            cm = ComponentModifier(s)
        end
        c[:Session][ip][ref](cm)
        write!(c, " ")
        write!(c, cm)
    end
end

"""
**Session Interface**
### kill!(c::Connection, event::AbstractString, s::Servable) -> _
------------------
Removes a given event call from a connection's Session.
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
function kill!(c::Connection, fname::AbstractString, s::Servable)
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

"""
**Session Interface**
### create_peers(c::Connection)
------------------
Creates a new peer `Connection` inside of ToolipsSession. This is still
expiremental and in an early stage of development, but soon this will be an
easy to use method system for working between many different peers and communicating
    data easily.
#### example
```

```
"""
function open_rpc!(c::Connection)

end

function close_rpc!(c::Connection)

end

function join_rpc!(c::Connection, token::String)

end

function rpc!(c::Connection, cm::ComponentModifier)

end

export Session, on, on_keydown, on_keyup
export TimedTrigger, observe!, ComponentModifier, animate!, pauseanim!
export playanim!, alert!, redirect!, modify!, move!, remove!, set_text!
export set_children!, get_text, style!, free_redirects!, confirm_redirects!
export Keys

end # module
