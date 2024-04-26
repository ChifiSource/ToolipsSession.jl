"""
Created in June, 2022 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
### ToolipsSession
`ToolipsSession` provides fullstack call-backs for `Toolips` `Components`, including
Input Maps (swipe and keyboard input), `rpc!` callbacks, Authentication, 
and `next!` animation callbacks.
```julia
module SampleServer
#  ---- dependencies
using Toolips
using Toolips.Components
using ToolipsSession
#  ---- create extensions
# create `Session`. Active route paths are provided to the constructor in a `Vector{String}`:
session = Session(["/"])

#  ---- routes
main = route("/") do c::AbstractConnection
    mainbut = button("examplebutton", text = "click me for a message!")
    appendbut = button("appendsample", text = "click me to append")
    on(c, mainbut, "click") do cm::ComponentModifier
        alert!(cm, "hello world!")
    end
    on(c, mainbut, "click") do cm::ComponentModifier

    end
end
#  ---- exports (load server components)
#   vvv Important! export Session! (`?(ToolipsSession.Toolips)`)
export main, session, start!
end
```
**Important**: `Session` callbacks might be made with closures, or functions 
as arguments. Closures **cannot** be 
serialized with `Toolips` multi-threading. In order for fullstack callbacks to work with 
multiple threads, you will need to define each callback as a `Function` within your `Module`. 
Provided functions can take either a `ComponentModifier`, as is usually seen with `do`, 
or a `Connection` and `ComponentModifier`. Not relevant to `ToolipsSession`, but also make sure 
the `Function` provided to `route` takes an `AbstractConnection`.
```julia

```
##### provides

"""
module ToolipsSession
using Toolips
import Toolips: AbstractRoute, kill!, AbstractConnection, write!, route!, on_start, gen_ref, convert, convert!, write!, interpolate!
import Toolips.Components: ClientModifier, script, Servable, next!, Component, style!, AbstractComponentModifier, AbstractComponent, on, bind, htmlcomponent, redirect!
import Base: setindex!, getindex, push!, iterate, string, in
using Dates
# using WebSockets: serve, writeguarded, readguarded, @wslog, open, HTTP, Response, ServerWS
include("Modifier.jl")
include("Auth.jl")
export authorize!
#==
Hello, welcome to the Session source. Here is an overview of the organization
that might help you out:
------------------
- ToolipsSession.jl
--- linker
--- Session extension
--- kill!
--- KeyMap
--- on
--- bind
--- script interface
--- rpc
------------------
- Modifier.jl
--- ComponentModifiers
--- Modifier functions
------------------
- Auth.jl
--- Auth
==#

function document_linker(c::AbstractConnection)
    s::String = get_post(c)
    ip::String = get_ip(c)
    reftag::UnitRange{Int64} = findfirst("â•ƒCM", s)
    reftagend = findnext("â•ƒ", s, maximum(reftag))
    ref_r::UnitRange{Int64} = maximum(reftag) + 1:minimum(reftagend) - 1
    ref::String = s[ref_r]
    s = replace(s, "â•ƒCM" => "", "â•ƒ" => "")
    cm = ComponentModifier(s)
    if contains(ref, "GLOBAL")
        ip = "GLOBAL"
    end
    call!(c, c[:Session].events[ip][ref], cm)
    write!(c, " ", cm)
    cm = nothing
    nothing::Nothing
end

#== WIP socket server
abstract type SocketServer <: Toolips.ServerTemplate end

function start!(mod::Module = server_cli(Main.ARGS), from::Type{SocketServer}; ip::IP4 = ip4_cli(Main.ARGS), 
    router_threads::Int64 = 1, threads::Int64 = 1)
    IP = Sockets.InetAddr(parse(IPAddr, ip.ip), ip.port)
    server::Sockets.TCPServer = Sockets.listen(IP)
    mod.server = server
    routefunc::Function, pm::ProcessManager = generate_router(mod, router_threads)
    if router_threads == 1
        w = pm["$mod router"]
        serve_router = @async HTTP.listen(routefunc, ip.ip, ip.port, server = server)
        w.task = serve_router
        w.active = true
        return(pm)::ProcessManager
    end
end

begin
    function handler(req)
        println("someone landed")
        open("ws://127.0.0.1:8000") do ws_client
            
        end
    end
    function wshandler(ws_server)
        println("websockethandled")
        writeguarded(ws_server, "Hello")
        readguarded(ws_server)
    end
    serverWS = ServerWS(handler, wshandler)
    servetask = @async with_logger(WebSocketLogger()) do
        serve(serverWS, port = 8000)
        "Task ended"
    end
end
==#

"""
```julia
abstract type AbstractEvent <: Servable
```
An `Event` is a type of registered callback for `ToolipsSession` to call. 
    `ToolipsSession` provides the `Event`, `RPCClient`, and `RPCHost`. Events 
    are indexed by their `Event.name`. The `Function` `call!` is used on an 
    event whenever it is determined to be registered to an occurring input action.
---
- See also: `Session`, `on`, `ToolipsSession`, `bind`, `Toolips`, `Event`, `RPCEvent`
"""
abstract type AbstractEvent <: Servable end

function getindex(v::Vector{AbstractEvent}, t::String)
    f = findfirst(e -> e.name == t, v)
    if isnothing(f)
        throw("$t not found")
    end
    v[f]
end

"""
```julia
struct Event <: Abstractevent
```
- `f`**::Function**
- `name`**::String**

An `Event` is the most simple form of `ToolipsSession` event. It has a `name`, 
usually a small reference code, and this name is called by the client before the `Function` 
`f` is called. These events are usually created through the 
`register!(::Function, ::AbstractConnection, ::String)` `Method` whenever `on` 
or `bind` is used to create an event.

```example

```
```julia
Event(f::Function, name::String)
```
- See also: `Session`, `on`, `ToolipsSession`, `bind`, `AbstractEvent`
"""
struct Event <: AbstractEvent
    f::Function
    name::String
end

function call!(c::AbstractConnection, event::AbstractEvent, cm::ComponentModifier)
    if length(methods(event.f)[1].sig.parameters) > 2
        event.f(c, cm)
        return(nothing)::Nothing
    end
    event.f(cm)
    nothing::Nothing
end

"""
```julia
abstract type RPCEvent <: AbstractEvent
```

---
- See also: `Session`, `on`, `ToolipsSession`, `bind`, `AbstractEvent`, `Event`
"""
abstract type RPCEvent <: AbstractEvent end

mutable struct RPCClient <: RPCEvent
    name::String
    host::String
    changes::Vector{String}
    RPCClient(c::AbstractConnection, host::String, ref) = new(ref, host, Vector{String}())
end

mutable struct RPCHost <: RPCEvent
    name::String
    clients::Vector{String}
    changes::Vector{String}
    RPCHost(ref::String) = new(ref, Vector{String}(), Vector{String}())
end

function call!(c::AbstractConnection, event::RPCEvent, cm::ComponentModifier)
    push!(cm.changes, join(event.changes))
    event.changes = Vector{String}()
    nothing::Nothing
end

mutable struct Session <: Toolips.AbstractExtension
    active_routes::Vector{String}
    events::Dict{String, Vector{AbstractEvent}}
    iptable::Dict{String, Dates.DateTime}
    gc::Int64
    timeout::Int64
    function Session(active_routes::Vector{String} = ["/"]; timeout = 5)
        events = Dict{String, Vector{AbstractEvent}}("GLOBAL" => Vector{AbstractEvent}()) 
        iptable = Dict{String, Dates.DateTime}()
        new(active_routes, events, iptable, 0, timeout)::Session
    end
end

on_start(ext::Session, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    if ~(:Session in keys(data))
        push!(data, :Session => ext)
    end
end

function route!(c::AbstractConnection, e::Session)
    if get_route(c) in e.active_routes
        e.gc += 1
        if e.gc == 1000
            e.gc = 0
            [begin
                time = active_client[2]
                current_time = now()
                if hour(current_time) != hour(time)
                    if ~(minute(current_time) < e.timeout)
                        delete!(e.events, active_client[1])
                        delete!(e.iptable, active_client[1])
                    end
                elseif minute(current_time) - minute(time) > e.timeout
                    delete!(e.events, active_client[1])
                    delete!(e.iptable, active_client[1])
                end
                nothing
            end for active_client in e.iptable]::Vector
        end
        if get_method(c) == "POST"
            document_linker(c)
            return(false)::Bool
        elseif ~(get_ip(c) in keys(e.iptable))
            push!(e.events, get_ip(c) => Vector{AbstractEvent}())
        end
        e.iptable[get_ip(c)] = now()
        write!(c, """<script>
        const parser = new DOMParser();
        function sendpage(ref) {
        var bodyHtml = document.getElementsByTagName('body')[0].innerHTML;
        sendinfo('╃CM' + ref + '╃' + bodyHtml);
        }
        function sendinfo(txt) {
        let xhr = new XMLHttpRequest();
        xhr.open("POST", "$(get_route(c))");
        xhr.setRequestHeader("Accept", "application/json");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onload = () => eval(xhr.responseText);
        xhr.send(txt);
        }
        </script>
        <style type="text/css">
        #div {
        -webkit-transition: 1s ease-in-out;
        -moz-transition: 1s ease-in-out;
        -o-transition: 1s ease-in-out;
        transition: 1s ease-in-out;
        }
        </style>
        """)
    end
end

register!(f::Function, c::AbstractConnection, name::String) = push!(c[:Session].events[get_ip(c)], Event(f, name))

getindex(m::Session, s::AbstractString) = m.events[s]

setindex!(m::Session, d::Any, s::AbstractString) = m.events[s] = d

"""
**Session Interface**
### kill!(c::AbstractConnection)
------------------
Kills a Connection's saved events.
#### example
```
using Toolips
using ToolipsSession

route("/") do c::AbstractConnection
    on(c, "load") do cm::ComponentModifier
        alert!(cm, "this text will never appear.")
    end
    println(length(keys(c[:Session].iptable)))
    kill!(c)
    println(length(keys(c[:Session].iptable)))
end
```
"""
function kill!(c::AbstractConnection)
    delete!(c[:Session].iptable, get_ip(c))
    delete!(c[:Session].events, get_ip(c))
end

function clear!(c::AbstractConnection)
    c[:Session].events[get_ip(c)] = Vector{AbstractEvent}()
end

event(f::Function, session::Session, name::String) = begin
    push!(session.events["GLOBAL"], Event(f, "GLOBAL-" * name))
end

on(name::String, c::AbstractConnection, event::String; 
    prevent_default::Bool = false) = begin
    name::String = "GLOBAL-" * name
    write!(c, "<script>document.addEventListener('$event', sendpage('$name'));</script>")
end

on(name::String, c::AbstractConnection, comp::Component{<:Any}, event::String; 
    prevent_default::Bool = false) = begin
    name::String = "GLOBAL-" * name
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    s["on$event"] = "$(prevent)sendpage('$name');"
end

"""

"""
function on(f::Function, c::AbstractConnection, event::AbstractString, 
    prevent_default::Bool = false)
    ref::String = Toolips.gen_ref(5)
    ip::String = get_ip(c)
    write!(c,
        "<script>document.addEventListener('$event', sendpage('$ref'));</script>")
    register!(f, c, ref)
end

function on(f::Function, c::AbstractConnection, s::AbstractComponent, event::AbstractString, 
    prevent_default::Bool = false)
    ref::String = gen_ref(5)
    ip::String = string(get_ip(c))
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    s["on$event"] = prevent * "sendpage('$ref');"
    register!(f, c, ref)
end

function on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, event::AbstractString)
    ip::String = get_ip(c)
    ref::String = gen_ref(5)
    push!(cm.changes, """setTimeout(function () {
    document.addEventListener('$event', function () {sendpage('$ref');});}, 1000);""")
    register!(f, c, ref)
end

function on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, comp::Component{<:Any},
     event::AbstractString)
     name::String = comp.name
     ref::String = gen_ref(5)
     push!(cm.changes, """setTimeout(function () {
     document.getElementById('$name').addEventListener('$event',
     function () {sendpage('$ref');});
     }, 1000);""")
     register!(f, c, ref)
end

function on(f::Function, cm::AbstractComponentModifier, comp::Component{<:Any}, event::String)
    name = comp.name
    cl = Toolips.ClientModifier(); f(cl)
    push!(cm.changes, """setTimeout(function (event) {
        document.getElementById('$name').addEventListener('$event',
        function (e) {
            $(join(cl.changes))
        });
        }, 1000);""")
end

function button_select(c::AbstractConnection, name::String, buttons::Vector{<:Servable},
    unselected::Vector{Pair{String, String}} = ["background-color" => "blue",
     "border-width" => 0px],
    selected::Vector{Pair{String, String}} = ["background-color" => "green",
     "border-width" => 2px])
    selector_window = div(name, value = first(buttons)[:text])
    document.getElementById("xyz").style = "";
    [begin
    style!(butt, unselected)
    on(c, butt, "click") do cm
        [style!(cm, but, unselected) for but in buttons]
        cm[selector_window] = "value" => butt[:text]
        style!(cm, butt, selected)
    end
    end for butt in buttons]
    selector_window[:children] = Vector{Servable}(buttons)
    selector_window::Component{:div}
end

abstract type InputMap end

mutable struct SwipeMap <: InputMap
    bindings::Dict{String, Function}
    SwipeMap() = new(Dict{String, Function}())
end

function bind(f::Function, c::AbstractConnection, sm::SwipeMap, swipe::String)
    swipes = ["left", "right", "up", "down"]
    if ~(swipe in swipes)
        throw(
        "Swipe is not a proper direction, please use up, down, left, or right!")
    end
    sm.bindings[swipe] = f
end

function bind(c::AbstractConnection, sm::SwipeMap,
    readonly::Vector{String} = Vector{String}())
    swipes = keys
    swipes = ["left", "right", "up", "down"]
    newswipes = Dict([begin
        if swipe in keys(sm.bindings)
            ref::String = ToolipsSession.gen_ref(5)
            register!(sm.bindings[swipe], c, ref)
            swipe => "sendpage('$ref');"
        else
            swipe => ""
        end
    end for swipe in swipes])
    sc::Component{:script} = script("swipemap", text = """
    document.addEventListener('touchstart', handleTouchStart, false);
document.addEventListener('touchmove', handleTouchMove, false);

var xDown = null;
var yDown = null;

function getTouches(evt) {
  return evt.touches ||             // browser API
         evt.originalEvent.touches; // jQuery
}

function handleTouchStart(evt) {
    const firstTouch = getTouches(evt)[0];
    xDown = firstTouch.clientX;
    yDown = firstTouch.clientY;
};

function handleTouchMove(evt) {
    if ( ! xDown || ! yDown ) {
        return;
    }

    var xUp = evt.touches[0].clientX;
    var yUp = evt.touches[0].clientY;

    var xDiff = xDown - xUp;
    var yDiff = yDown - yUp;

    if ( Math.abs( xDiff ) > Math.abs( yDiff ) ) {/*most significant*/
        if ( xDiff > 0 ) {
            $(newswipes["left"])
        } else {

            $(newswipes["right"])
        }
    } else {
        if ( yDiff > 0 ) {
            $(newswipes["up"])
        } else {
            $(newswipes["down"])
        }
    }
    /* reset values */
    xDown = null;
    yDown = null;
};

""")
    write!(c, sc)
end

"""
### KeyMap
- keys::Dict{String, Pair{Tuple, Function}}

The `KeyMap` allows one to `bind!` more than one key press with incredible ease.
##### example
```
r = route("/") do c::AbstractConnection
    km = KeyMap()
    bind!(km, "S", :ctrl) do cm::ComponentModifier
        alert!(cm, "saved!")
    end
    bind!(km, "C", :ctrl) do cm::ComponentModifier
        alert!(cm, "copied!")
    end
    bind!(c, km)
end
```
------------------
##### constructors
- KeyMap()
"""
mutable struct KeyMap <: InputMap
    keys::Dict{String, Pair{Tuple, Function}}
    prevents::Vector{String}
    KeyMap() = new(Dict{String, Pair{Tuple, Function}}(), Vector{String}())
end

"""
**Session**
### bind!(f::Function, km::KeyMap, key::String, event::Symbol ...)
------------------
binds the `key` with the event keys (:ctrl, :shift, :alt) to `f` in `km`.
#### example
```
r = route("/") do c::AbstractConnection
    km = KeyMap()
    bind!(km, "S", :ctrl) do cm::ComponentModifier
        alert!(cm, "saved!")
    end
    bind!(km, "C", :ctrl) do cm::ComponentModifier
        alert!(cm, "copied!")
    end
    bind!(c, km)
end
```
"""
function bind(f::Function, km::KeyMap, key::String, event::Symbol ...; prevent_default::Bool = true)
    if prevent_default == true
        push!(km.prevents, key * join([string(ev) for ev in event]))
    end
    if key in keys(km.keys)
        l = length(findall(k -> k == key, collect(keys(km.keys))))
        km.keys["$key;$l"] = event => f
        return
    end
    km.keys[key] = event => f
end

function bind(f::Function, km::KeyMap, vs::Vector{String}; prevent_default::Bool = true)
    if length(vs) > 1
        event = Tuple(vs[2:length(vs)])
    else
        event = Tuple()
    end
    key = vs[1]
    if prevent_default == true
        push!(km.prevents, key * join([string(ev) for ev in event]))
    end
    if key in keys(km.keys)
        l = length(findall(k -> k == key, collect(keys(km.keys))))
        key ="$key;$l"
    end
    km.keys[key] = event => f
end

"""
**Session**
### bind!(c::AbstractConnection, cm::ComponentModifier, km::KeyMap, readonly::Vector{String} = Vector{String}; on = :down)
------------------
Binds the `KeyMap` `km` to the `Connection` in a `ComponentModifier` callback.
#### example
```
r = route("/") do c::AbstractConnection
    km = KeyMap()
    bind!(km, "S", :ctrl) do cm::ComponentModifier
        alert!(cm, "saved!")
    end
    bind!(km, "C", :ctrl) do cm::ComponentModifier
        alert!(cm, "copied!")
    end
    bind!(c, km)
end
```
"""
function bind(c::AbstractConnection, km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
    firsbind = first(km.keys)
    first_line::String = """setTimeout(function () {
    document.addEventListener('key$on', function(event) { if (1 == 2) {}"""
    for binding in km.keys
        default::String = ""
        key = binding[1]
        if contains(key, ";")
            key = split(key, ";")[1]
        end
        if key * join([string(bin) for bin in binding[2][1]]) in km.prevents
            default = "event.preventDefault();"
        end
        eventstr::String = join([" event.$(event)Key && " for event in binding[2][1]])
        ref::String = gen_ref(5)
        first_line = first_line * """ elseif ($eventstr event.key == "$(binding[1])") {$default
                sendpage('$ref');
        }"""
        register!(binding[2][2], c, ref)
    end
    first_line = first_line * "});}, 1000);"
    scr::Component{:script} = script(gen_ref(), text = first_line)
    write!(c, scr)
end

"""
**Session**
### bind!(c::AbstractConnection, cm::ComponentModifier, km::KeyMap, readonly::Vector{String} = Vector{String}; on = :down)
------------------
Binds the `KeyMap` `km` to the `Connection` in a `ComponentModifier` callback.
#### example
```
r = route("/") do c::AbstractConnection
    km = KeyMap()
    bind!(km, "S", :ctrl) do cm::ComponentModifier
        alert!(cm, "saved!")
    end
    bind!(km, "C", :ctrl) do cm::ComponentModifier
        alert!(cm, "copied!")
    end
    bind!(c, km)
end
```
"""
function bind(c::AbstractConnection, cm::ComponentModifier, km::KeyMap, on::Symbol = :down, prevent_default::Bool = true)
    firsbind = first(km.keys)
    first_line::String = """setTimeout(function () {
    document.addEventListener('key$on', function(event) { if (1 == 2) {}"""
    for binding in km.keys
        default::String = ""
        key = binding[1]
        if contains(key, ";")
            key = split(key, ";")[1]
        end
        if key * join([string(ev) for ev in binding[2][1]]) in km.prevents
            if binding[2] == km.prevents[binding[1]]
                default = "event.preventDefault();"
            end
        end
        eventstr::String = join([" event.$(event)Key && " for event in binding[2][1]])
        ref::String = gen_ref(5)
        first_line = first_line * """else if ($eventstr event.key == "$(binding[1])") {$default
                sendpage('$ref');
        }"""
        register!(binding[2][2], c, ref)
    end
    first_line = first_line * "});}, 1000);"
    push!(cm.changes, first_line)
end

"""
**Session**
### bind!(c::AbstractConnection, comp::Component, km::KeyMap, readonly::Vector{String} = Vector{String}; on = :down)
------------------
Binds the `KeyMap` `km` to the `comp`.
#### example
```

```
"""
function bind(c::AbstractConnection, cm::ComponentModifier, comp::Component{<:Any},
    km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
    firsbind = first(km.keys)
    first_line::String = """
    setTimeout(function () {
    document.getElementById('$(comp.name)').addEventListener('key$on', function (event) { if (1 == 2) {}"""
    n = 1
    for binding in km.keys
        default::String = ""
        key = binding[1]
        if contains(key, ";")
            key = split(key, ";")[1]
        end
        if (key * join([string(ev) for ev in binding[2][1]])) in km.prevents
            default = "event.preventDefault();"
        end
        ref::String = gen_ref(5)
        eventstr::String = join([" event.$(event)Key && " for event in binding[2][1]])
        first_line = first_line * """ else if ($eventstr event.key == "$key") {$default
                sendpage('$(comp.name * key * ref)');
                }"""
        register!(binding[2][2], c, ref)
    end
    first_line = first_line * "}.bind(event));}, 500);"
    push!(cm.changes, first_line)
end

"""
**Session Interface** 0.3
### bind!(f::Function, c::AbstractConnection, key::String, readonly::Vector{String} = [];
    on::Symbol = :down, client::Bool == false)  -> _
------------------

Binds a key event to a `Component`.
#### example
```

```
"""
function bind(f::Function, c::AbstractConnection, comp::Component{<:Any},
    key::String, eventkeys::Symbol ...; on::Symbol = :down)
    cm::AbstractComponentModifier = Toolips.Components.ClientModifier()
    eventstr::String = join((begin " event.$(event)Key && "
                            end for event in eventkeys))
    ref::String = gen_ref(5)
    write!(c, """<script>
    setTimeout(function () {
    document.getElementById('$(comp.name)').addEventListener('key$on', function(event) {
        if ($eventstr event.key == "$(key)") {
        sendpage('$ref');
        }
});}, 1000)</script>
    """)
    register!(f, c, ref)
end

"""
**Session Interface** 0.3
### bind!(f::Function, c::AbstractConnection, key::String, readonly::Vector{String} = [];
    on::Symbol = :down, client::Bool == false)  -> _
------------------
Binds a key event to a `Connection`.
#### example
```

```
"""
function bind(f::Function, c::AbstractConnection, key::String, eventkeys::Symbol ...;
    on::Symbol = :down, prevent_default::Bool = true)
    cm::Modifier = ClientModifier()
    eventstr::String = join([begin " event.$(event)Key && "
                            end for event in eventkeys])
    ref::String = gen_ref(5)
    write!(c, """<script>
    setTimeout(function () {
document.addEventListener('key$on', function(event) {
    if ($eventstr event.key == "$(key)") {
    sendpage('$ref');
    }
});}, 1000);</script>
    """)
    register!(f, c, ref)
end

"""
**Session Interface** 0.3
### bind!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, key::String, eventkeys::Symbol ...; readonly::Vector{String} = [];
    on::Symbol = :down, client::Bool == false)  -> _
------------------
Binds a key event to a `Connection` in a `ComponentModifier` callback.
#### example
```

```
"""
function bind(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, key::String,
    eventkeys::Symbol ...; on::Symbol = :down, mark::String = "none")
    eventstr::String = join([begin " event.$(event)Key && "
                            end for event in eventkeys])
    ref = gen_ref(5)
    push!(cm.changes, """
    setTimeout(function () {
    document.addEventListener('key$on', (event) => {
            if ($eventstr event.key == "$(key)") {
            sendpage('$ref');
            }
            });}, 1000);""")
    register!(f, c, ref)
end

"""
**Session Interface** 0.3
### bind!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, comp::Component{<:Any}, key::String, eventkeys::Symbol ...; readonly::Vector{String} = [];
    on::Symbol = :down, client::Bool == false)  -> _
------------------
Binds a key event to a `Component` in a `ComponentModifier` callback.
#### example
```

```
"""
function bind(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, comp::Component{<:Any},
    key::String, eventkeys::Symbol ...; on::Symbol = :down)
    ref::String = gen_ref(5)
    name::String = comp.name
    eventstr::String = join([begin " event.$(event)Key && "
                            end for event in eventkeys])
push!(cm.changes, """setTimeout(function () {
document.getElementById('$(name)').onkeydown = function(event){
        if ($eventstr event.key == '$(key)') {
        sendpage('$ref')
        }
        }}, 1000);""")
    register!(f, c, ref)
end

#==
script!
==#
"""

"""
function script!(f::Function, c::AbstractConnection, name::String; time::Integer = 500,
    type::String = "Interval")
    obsscript::Component{:script} = script(name, text = """
    set$(type)(function () { sendpage('$name'); }, $time);
   """)
   register!(f, c, name)
   write!(c, obsscript)
end

function script!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier; time::Integer = 1000, type::String = "Timeout")
   ref = gen_ref(5)
   push!(cm.changes, "set$type(function () { sendpage('$ref'); }, $time);")
   register!(f, c, ref)
end

function script!(f::Function, cm::AbstractComponentModifier, name::String;
   time::Integer = 1000)
   mod = ClientModifier()
   f(mod)
   push!(cm.changes,
   "new Promise(resolve => setTimeout($(Components.funccl(mod, name)), $time));")
end


script(cl::AbstractComponentModifier) = begin
    script(cl.name, text = join(cl.changes))
end

function script(f::Function, s::String = gen_ref(5))
    cl = ClientModifier(s)
    f(cl)
    script(cl.name, text = funccl(cl))::Component{:script}
end

#==
rpc
==#

"""

"""
function open_rpc!(c::AbstractConnection; tickrate::Int64 = 500)
    ref::String = gen_ref(5)
    event::RPCHost = RPCHost(ref)
    write!(c, 
    script(ref, text = """setInterval(function () { sendpage('$ref'); }, $tickrate);"""))
    push!(c[:Session].events[get_ip(c)], event)
    nothing::Nothing
end

"""

"""
function open_rpc!(c::AbstractConnection, cm::ComponentModifier; tickrate::Int64 = 500)
    ref::String = gen_ref(5)
    event::RPCHost = RPCHost(ref)
    push!(cm.changes, "setInterval(function () { sendpage('$ref'); }, $tickrate);")
    push!(c[:Session].events[get_ip(c)], event)
    nothing::Nothing
end

reconnect_rpc!(c::Connection; tickrate::Int64 = 500) = begin
    events::Vector{AbstractEvent} = c[:Session].events[get_ip(c)]
    found = findfirst(event::AbstractEvent -> typeof(event) <: RPCEvent, events)
    if isnothing(found)
        throw("RPC Error: Trying to reconnect RPC that does not exist.")
    end
    ref = events[found].name
    write!(c, "setInterval(function () { sendpage('$ref'); }, $tickrate);")
end

function close_rpc!(session::Session, ip::String)
    found = findfirst(event::AbstractEvent -> typeof(event) <: RPCEvent, session.events[ip])
    if isnothing(found)
        throw("RPC Error: You are trying to close an RPC session that does not exist.")
    end
    event = session.events[ip][found]
    if typeof(event) == RPCHost
        [close_rpc!(session, client) for client in event.clients]
    else
        host_event = findfirst(event::AbstractEvent -> typeof(event) == RPCHost,
        session.events[event.host])
        if ~(isnothing(host_event))
            host_event = session.events[event.host][host_event]
            client_rep = findfirst(client_ip::String -> client_ip == ip, host_event.clients)
            if ~(isnothing(client_rep))
                deleteat!(host_event.clients, client_rep)
            end
        end
    end
    deleteat!(events[ip], found)
    nothing::Nothing
end

"""

"""
function close_rpc!(c::AbstractConnection)
    close_rpc!(c[:Session], get_ip(c))
    nothing
end

"""

"""
function join_rpc!(c::AbstractConnection, host::String; tickrate::Int64 = 500)
    ref::String = gen_ref(5)
    event::RPCClient = RPCClient(c, host, ref)
    write!(c, 
    script(ref, text = """setInterval(function () { sendpage('$ref'); }, $tickrate);"""))
    push!(c[:Session].events[get_ip(c)], event)
    push!(find_host(c).clients, get_ip(c))
    nothing::Nothing
end

"""

"""
function join_rpc!(c::AbstractConnection, cm::ComponentModifier, host::String; tickrate::Int64 = 500)
    ref::String = gen_ref(5)
    event::RPCClient = RPCClient(c, host, ref)
    push!(cm.changes, "setInterval(function () { sendpage('$ref'); }, $tickrate);")
    push!(c[:Session].events[get_ip(c)], event)
    push!(find_host(c).clients, get_ip(c))
    nothing::Nothing
end

function find_host(c::AbstractConnection)
    events = c[:Session].events
    ip::String = get_ip(c)
    found = findfirst(event::AbstractEvent -> typeof(event) <: RPCEvent, events[ip])
    if isnothing(found)
        throw("RPC error: unable to find RPC event")
    elseif typeof(events[ip][found]) == RPCClient
        host = events[ip][found].host
        found = findfirst(event::AbstractEvent -> typeof(event) == RPCHost, events[host])
        return(events[host][found])::RPCHost
    end
    return(events[ip][found])::RPCEvent
end

function rpc!(session::Session, event::RPCHost, cm::ComponentModifier)
    changes::String = join(cm.changes)
    push!(event.changes, changes)
    [begin 
        found = findfirst(e -> typeof(e) == RPCClient, session.events[client])
        push!(session.events[client][found].changes, changes)
    end for client in event.clients]
    cm.changes = Vector{String}()
    nothing::Nothing
end

"""

"""
function rpc!(c::AbstractConnection, cm::ComponentModifier)
    rpc!(c[:Session], find_host(c), cm)
end

function call!(session::Session, event::RPCHost, cm::ComponentModifier, ip::String)
    changes::String = join(cm.changes)
    if ip in event.clients
        push!(event.changes, changes)
    end
    filt = filter(e -> e != ip, event.clients)
    [begin 
        found = findfirst(e -> typeof(e) == RPCClient, session.events[client])
        push!(session.events[client][found].changes, changes)
    end for client in filt]
    cm.changes = Vector{String}()
    nothing::Nothing
end

function call!(session::Session, event::RPCHost, cm::ComponentModifier, ip::String, target::String)
    changes::String = join(cm.changes)
    found = findfirst(e -> typeof(e) <: RPCEvent, session.events[target])
    push!(session.events[target][found].changes, changes)
    cm.changes = Vector{String}()
    nothing::Nothing
end

function call!(c::AbstractConnection, cm::ComponentModifier)
    call!(c[:Session], find_host(c), cm, get_ip(c))
end

function call!(c::AbstractConnection, cm::ComponentModifier, peerip::String)
    call!(c[:Session], find_host(c), cm, get_ip(c), peerip)
end

"""
**Session Interface**
### is_dead(c::AbstractConnection) -> ::Bool
------------------
Checks if the current `Connection` is still connected to `Session`
#### example
```

```
"""
is_dead(c::AbstractConnection) = get_ip(c) in keys(c[:Session].iptable)

export Session, on, bind!, script!, script, ComponentModifier, ClientModifier
export KeyMap
export playanim!, alert!, redirect!, modify!, move!, remove!, set_text!
export update!, insert_child!, append_first!, animate!, pauseanim!, next!
export set_children!, get_text, style!, free_redirects!, confirm_redirects!, store!
export scroll_by!, scroll_to!, focus!, set_selection!, blur!
export rpc!, disconnect_rpc!, find_client, join_rpc!, close_rpc!, open_rpc!
export join_rpc!, is_client, is_dead, is_host, call!
end # module
