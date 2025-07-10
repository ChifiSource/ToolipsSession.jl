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
### provides
###### session
- `AbstractEvent`
- `Event`
- `call!`
- `RPCEvent`
- `RPCClient`
- `RPCHost`
- `Session`
- `register!`
- `Toolips.kill!(::AbstractConnection)`
- `clear!`
- `event`
- `on`
- `ToolipsSession.bind`
- `InputMap`
- `SwipeMap`
- `KeyMap`
- `script!`
- `open_rpc!`
- `join_rpc!`
- `reconnect_rpc!`
- `close_rpc!`
- `rpc!`
###### component modifier
- `ComponentModifier`
- `button_select` <- random prebuilt component
- `set_selection!`
- `pauseanim!`
- `playanim!`
- `free_redirects!`
- `confirm_redirects!`
- `scroll_to!`
- `scroll_by!`
- `next!`
"""
module ToolipsSession
using Toolips
import Toolips: AbstractRoute, kill!, AbstractConnection, write!, route!, on_start, gen_ref, convert, convert!, write!, interpolate!
import Toolips.Components: ClientModifier, Servable, next!, Component, style!, AbstractComponentModifier, AbstractComponent
import Toolips.Components: on, bind, htmlcomponent, script
import Base: setindex!, getindex, push!, iterate, string, in
using Dates
# using WebSockets: serve, writeguarded, readguarded, @wslog, open, HTTP, Response, ServerWS
include("Modifier.jl")

function get_session_key(c::AbstractConnection)
    return(get_cookies(c)["key"].value)::String
end
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

abstract type SessionCommand{T} end

function do_session_command(c::AbstractConnection, command::Type{SessionCommand{<:Any}}, raw::String)
    delete!(c[:Session].events, get_session_key(c))
end

function document_linker(c::AbstractConnection, client_key::String)
    s::String = get_post(c)
    if contains(s, "|!|") && length(s) > 3
        do_session_command(c, SessionCommand{Symbol(s[1:3])}, s)
        return
    end
    ref::String = get_ref(s)
    s = replace(s, "â•ƒCM" => "", "â•ƒ" => "")
    cm = ComponentModifier(s)
    if contains(ref, "GLOBAL")
        client_key = "GLOBAL"
    end
    call!(c, c[:Session].events[client_key][ref], cm)
    write!(c, " ", cm)
    cm = nothing
    nothing::Nothing
end

get_ref(s::String) = begin
    reftag::UnitRange{Int64} = findfirst("â•ƒCM", s)
    reftagend::UnitRange{Int64} = findnext("â•ƒ", s, maximum(reftag))
    ref_r::UnitRange{Int64} = maximum(reftag) + 1:minimum(reftagend) - 1
    s[ref_r]::String
end

function document_linker(c::AbstractConnection, client_key::String, threaded::Bool)
    s::String = get_post(c)
    get_ref_job = Toolips.new_job(get_ref, s)
    procs = c[:procs]
    assigned_worker = Toolips.assign_open!(procs, get_ref_job, not = Toolips.ParametricProcesses.Async, sync = true)
    ref = waitfor(procs, assigned_worker ...)[1]
    s = replace(s, "â•ƒCM" => "", "â•ƒ" => "")
    cm = ComponentModifier(s)
    if contains(ref, "GLOBAL")
        ip = "GLOBAL"
    end
    call_job = new_job(call!, c[:Session].events[client_key][ref], cm)
    assigned_worker = assign_open!(procs, call_job, sync = true)
    ret = waitfor(procs, assigned_worker ...)
    write!(c, " ", ret[1])
    cm = nothing
    nothing::Nothing
end

"""
```julia
abstract type AbstractEvent <: Servable
```
An `Event` is a type of registered callback for `ToolipsSession` to call. 
    `ToolipsSession` provides the `Event`, `RPCClient`, and `RPCHost`. Events 
    are indexed by their `Event.name`. The `Function` `call!` is used on an 
    event whenever it is determined to be registered to an occurring input action.
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
function call!(c::AbstractConnection, event::AbstractEvent, cm::ComponentModifier)
    if length(methods(event.f)[1].sig.parameters) > 2
        event.f(c, cm)
        return(nothing)::Nothing
    end
    event.f(cm)
    nothing::Nothing
end
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

"""
```julia
call!(c::AbstractConnection, ...) -> ::Nothing
```
`call!` is used call events on a client. `call!` is used for RPC and by the document linker 
to call event references. The first method is indicitave of the latter:
```julia
call!(c::AbstractConnection, event::AbstractEvent, cm::ComponentModifier)
```
"""
function call! end

function call!(c::AbstractConnection, event::AbstractEvent, cm::ComponentModifier)
    if length(methods(event.f)[1].sig.parameters) > 2
        event.f(c, cm)
        return(nothing)::Nothing
    end
    event.f(cm)
    cm::ComponentModifier
end

function call!(event::AbstractEvent, cm::ComponentModifier)
    event.f(cm)
    cm::ComponentModifier
end


"""
```julia
abstract type RPCEvent <: AbstractEvent
```
An `RPCEvent` is an event that manages RPC changes for multiple clients. The main 
    two types of rpc events are the `RPCClient` and `RPCHost`. These events are 
    created whenever `join_rpc!` or `open_rpc!` is called.
- See also: `Session`, `on`, `AbstractEvent`, `Event`, `RPCHost`, `RPCClient`, `open_rpc!`
"""
abstract type RPCEvent <: AbstractEvent end

"""
```julia
mutable struct RPCClient <: RPCEvent
```
- name**::String**
- host**::String**
- changes**::Vector{String}**

The `RPCClient` is used to track the `changes` and `host` from other clients sharing 
its RPC session.

- See also: `open_rpc!`, `RPCEvent`, `RPCHost`, `rpc!`, `call!`
```julia
RPCClient(c::AbstractConnection, host::String, ref::String)
```
```example

```
"""
mutable struct RPCClient <: RPCEvent
    name::String
    host::String
    changes::Vector{String}
    RPCClient(c::AbstractConnection, host::String, ref) = new(ref, host, Vector{String}())
end

"""
```julia
mutable struct RPCHost <: RPCEvent
```
- name**::String**
- clients**::Vector{String}**
- changes**::Vector{String}**

The `RPCHost` is the partner to the `RPCClient`, created by calling `open_rpc!` this host will 
track the changes to itself, as well as which clients are meant to be part of its RPC session.

- See also: `open_rpc!`, `RPCEvent`, `RPCClient`, `rpc!`, `call!`, `Event`, `Session`
```julia
RPCHost(ref::String)
```
```example

```
"""
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

"""
```julia
mutable struct Session <: Toolips.AbstractExtension
```
- active_routes**::Vector{String}**
- events**::Dict{String, Vector{AbstractEvent}}**
- iptable**::Dict{String, Dates.DateTime}**
- gc**::Int64**
- timeout**::Int64**

`Session` provides fullstack `Event` callbacks to your `Toolips` server. This is a `Toolips` extension; 
in order to load it, construct it and then `export` it from your `Module`. From here, callbacks can be 
registered using `on`, `script!`, or `bind`. `on` must be provided a `Connection` in order to pass a 
`ComponentModifier`, which will allow to us to interact with the server.
```julia
module SessionServer
using Toolips
using Toolips.Components
using ToolipsSession

      #   v only operating on `/`, with a timeout of 5 minutes.
session = Session()

main = route("/") do c::AbstractConnection
    mybutton = button("click-me", text = "click me!")
    style!(mybutton, "background-color" => "white", "transition" => 500ms)
    on(c, mybutton, "click") do cm::ComponentModifier
        style!(cm, mybutton, "background-color" => "red")
    end
    bod = body("main-body")
    push!(bod, mybutton)
    write!(c, bod)
end

export main, session
end
```
Provided functions are able to take either a `ComponentModifier`, or a `Connection` and a `ComponentModifier` as arguments.
- See also: `open_rpc!`, `script!`, `on`, `ToolipsSession.bind`, `ComponentModifier`
```julia
Session(active_routes::Vector{String} = ["/"]; timeout::Int64 = 5)
```
"""
mutable struct Session{THREAD <: Any} <: Toolips.AbstractExtension
    active_routes::Vector{String}
    events::Dict{String, Vector{AbstractEvent}}
    invert_active::Bool
    function Session(active_routes::Vector{String} = ["/"]; timeout::Int64 = 10, invert_active::Bool = false, threaded::Bool = false)
        events = Dict{String, Vector{AbstractEvent}}("GLOBAL" => Vector{AbstractEvent}()) 
        new{threaded}(active_routes, events, invert_active)::Session{threaded}
    end
end

on_start(ext::Session{<:Any}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    if ~(:Session in keys(data))
        push!(data, :Session => ext)
    end
end

on_start(ext::Session{true}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    if ~(:Session in keys(data))
        push!(data, :Session => ext)
    end
    Main.eval(Meta.parse("""using Toolips: @everywhere; @everywhere begin
            using ToolipsSession
            using Dates
        end"""))
    put!(data[:procs], Toolips.worker_pids(data[:procs], Toolips.ParametricProcesses.Threaded), ToolipsSession)
end

function write_doclinker!(c::AbstractConnection, e::Session{<:Any})
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
        <script>
        window.addEventListener('unload', function (e) {
            e.preventDefault()
            sendinfo('DIS|!|')
        })
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

function route!(c::AbstractConnection, e::Session{<:Any})
    if ~ e.invert_active && get_route(c) in e.active_routes || e.invert_active && ~(get_route(c) in e.active_routes)
        cooks = get_cookies(c)
        if get_method(c) == "POST"
            if ~("key" in cooks)
                return(true)
            end
            document_linker(c, cooks["key"].value)
            return(false)::Bool
        elseif ~("key" in cooks) || ~(haskey(e.events, cooks["key"].value))
            new_key = gen_ref(10)
            if "key" in cooks && ~(haskey(e.events, cooks["key"]))
                Toolips.clear_cookies!(c)
            end
            push!(e.events, new_key => Vector{AbstractEvent}())
            respond!(c, "<script>location.href='$(c.stream.message.target)'</script>", 
            [Toolips.Cookie("key", new_key)])
            return(false)
        end
        write_doclinker!(c, e)
    end
end

function route!(c::AbstractConnection, e::Session{true})
    if ~ e.invert_active && get_route(c) in e.active_routes || e.invert_active && ~(get_route(c) in e.active_routes)
        cooks = get_cookies(c)
        if get_method(c) == "POST"
            if ~("key" in cooks)
                return(true)
            end
            document_linker(c, cooks["key"].value, true)
            return(false)::Bool
        elseif ~("key" in cooks) || ~(haskey(e.events, cooks["key"].value))
            new_key = gen_ref(10)
            if "key" in cooks && ~(haskey(e.events, cooks["key"]))
                Toolips.clear_cookies!(c)
            end
            push!(e.events, new_key => Vector{AbstractEvent}())
            respond!(c, "<script>location.href='$(c.stream.message.target)'</script>", 
            [Toolips.Cookie("key", new_key)])
            return(false)
        end
        write_doclinker!(c, e)
    end
end

register!(f::Function, c::AbstractConnection, name::String; ref::Bool = true) = begin
    client_events = c[:Session].events[get_cookies(c)["key"].value]
    found = findfirst(event::AbstractEvent -> event.name == name, client_events)
    if ~(isnothing(found))
        deleteat!(client_events, found)
    end
    push!(client_events, Event(f, name))
end

getindex(m::Session, s::AbstractString) = m.events[s]

setindex!(m::Session, d::Any, s::AbstractString) = m.events[s] = d

"""
```julia
kill!(c::AbstractConnection) -> ::Nothing
```
Deletes a `Connection`'s active session, removing the client from 
the `iptable` and removing all events associated with the client.
- See also: `Session`, `clear!`, `on`, `ToolipsSession.bind`
```julia
module InstantKill
using Toolips
using ToolipsSession

session = Session()

main = route("/") do c::AbstractConnection

end

export main, session
end
```
"""
function kill!(c::AbstractConnection)
    delete!(c[:Session].events, get_session_key(c))
end

"""
```julia
clear!(c::AbstractConnection) -> ::Nothing
```
Deletes a `Connection`'s active session.
```julia
call!(c::AbstractConnection, event::AbstractEvent, cm::ComponentModifier)
```
"""
function clear!(c::AbstractConnection)
    c[:Session].events[get_session_key(c)] = Vector{AbstractEvent}()
end

"""
```julia
on(f::Function, session::Session, name::String) -> ::Nothing
```
This binding is used to bind events and save them for later, referencing them by their 
    provided `name`.
```example
on(sess, "sample") do cm::ComponentModifier
    style!(cm, "samp", "color" => "blue")
end

main = route("/") do c::Toolips.AbstractConnection
    mainbody = body("mainbod")
    on("sample", c, mainbody, "click")
    write!(c, mainbody)
end
```
"""
on(f::Function, session::Session, name::String) = begin
    push!(session.events["GLOBAL"], Event(f, "GLOBAL-" * name))
end

"""
```julia
on(name::String, ...; prevent_default::Bool = false) -> ::Nothing
```
These `on` bindings are used to bind existing events, registered using `on(::Function, ::Session, ::String)` 
to components and `Connections`. This makes it possible to create reusable global bindings for each client, for 
callbacks that have no variation and don't require function variables. Anytime the `Connection` is provided, 
this will be a server-side callback.
```julia
on(name::String, c::AbstractConnection, event::String; 
    prevent_default::Bool = false)
on(name::String, comp::Component{<:Any}, event::String; 
    prevent_default::Bool = false)
on(f::Function, cm::AbstractComponentModifier, comp::Component{<:Any}, event::String;
    prevent_default::Bool = false)
```
```julia
module SampleServer
using Toolips
using Toolips.Components
using Toolips
session = Session()
on(sess, "sample") do cm::ComponentModifier
    style!(cm, "samp", "color" => "blue")
end

main = route("/") do c::Toolips.AbstractConnection
    mainbody = body("mainbod")
    on("sample", c, mainbody, "click")
    write!(c, mainbody)
end

export main, session
end
```
"""
on(name::String, c::AbstractConnection, event::String; 
    prevent_default::Bool = false) = begin
    name::String = "GLOBAL-" * name
    write!(c, "<script>document.addEventListener('$event', sendpage('$name'));</script>")
end


on(name::String, comp::Component{<:Any}, event::String; 
    prevent_default::Bool = false) = begin
    name::String = "GLOBAL-" * name
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    comp["on$event"] = "$(prevent)sendpage('$name');"
end


function on(f::Function, cm::AbstractComponentModifier, comp::Component{<:Any}, event::String;
    prevent_default::Bool = false)
    name::String = comp.name
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    cl = Toolips.ClientModifier(); f(cl)
    push!(cm.changes, """setTimeout(function (event) {
        document.getElementById('$name').addEventListener('$event',
        function (event) {
            $prevent$(join(cl.changes))
        });
        }, 1000);""")
end

"""
```julia
on(f::Function, c::AbstractConnection, args ...; prevent_default::Bool = false)
```
`ToolipsSession` extends `on`, providing each `on` dispatch with a `Connection` equivalent 
that makes a callback to the server. This allows us to access data, or do more calculations 
than would otherwise be possible with a `ClientModifier`.
```julia
on(f::Function, c::AbstractConnection, event::AbstractString; prevent_default::Bool = false)
on(f::Function, c::AbstractConnection, s::AbstractComponent, event::AbstractString, 
    prevent_default::Bool = false)
on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, event::AbstractString)
on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, comp::Component{<:Any},
     event::AbstractString)
```
- See also: `script!`, `ToolipsSession.bind`, `KeyMap`, `open_rpc!`, `join_rpc!`, `Session`, `ToolipsSession`, `ComponentModifier`
```julia
module SampleServer
using Toolips
using Toolips.Components

session = Session()
main = route("/") do c::AbstractConnection
    txtbox = textdiv("entertxt")
    style!(txtbox, "width" => 10percent, "border-width" => 3px, "border-color" => "gray", "border-style" => "solid")
end

export main, session
end
```
"""
function on(f::Function, c::AbstractConnection, event::AbstractString;
    prevent_default::Bool = false)
    ref::String = Toolips.gen_ref(8)
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    write!(c,
        "<script>document.addEventListener('$event', $(prevent)sendpage('$ref'));</script>")
    register!(f, c, ref)
end

function on(f::Function, c::AbstractConnection, s::AbstractComponent, event::AbstractString;
    prevent_default::Bool = false)
    ref::String = gen_ref(8)
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    s["on$event"] = prevent * "sendpage('$ref');"
    register!(f, c, ref)
end

on(f::Function, c::AbstractConnection, time::Int64; recurring::Bool = false, 
    prevent_default::Bool = false) = begin
    name::String = gen_ref(8)
    type::String = "Timeout"
    if recurring
        type = "Interval"
    end
    obsscript::Component{:script} = script(name, text = """
    set$(type)(function () { sendpage('$name'); }, $time);
    """)
    register!(f, c, name)
    write!(c, obsscript)
end

on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, time::Int64; recurring::Bool = false, 
    prevent_default::Bool = false) = begin
    ref::String = gen_ref(8)
    type::String = "Timeout"
    if recurring
        type = "Interval"
    end
    push!(cm.changes, "set$type(function () { sendpage('$ref'); }, $time);;")
    register!(f, c, ref)
end

function on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, event::AbstractString; 
    prevent_default::Bool = false)
    ref::String = gen_ref(8)
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    push!(cm.changes, """setTimeout(function () {
    document.addEventListener('$event', function (event) {$(prevent)sendpage('$ref');});}, 1000);""")
    register!(f, c, ref)
end

function on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, comp::Component{<:Any},
     event::AbstractString; prevent_default::Bool = false)
     name::String = comp.name
     ref::String = gen_ref(8)
     prevent::String = ""
     if prevent_default
         prevent = "event.preventDefault();"
     end
     push!(cm.changes, """setTimeout(function () {
     document.getElementById('$name').addEventListener('$event',
     function (event) {$(prevent)sendpage('$ref');});
     }, 1000);""")
     register!(f, c, ref)
     nothing::Nothing
end

"""
```julia
bind(f::Function, c::AbstractConnection, args ...; prevent_default::Bool = true) -> ::Nothing
```
`ToolipsSession.bind` (`TooipsServables.bind`) is used to add less-traditional controls to `Toolips` 
web-pages. `ToolipsSession` adds server-side callbacks to this binding interface. The base `bind` methods will take a `Connection`, and 
will be provided with a normal event function, along with a key to bind it to. 
    Keys are represented the same as they are in JavaScript -- uppercase for 
    single letter keys, and initial uppercase for key names. For example...
```julia
module MyServer
using Toolips
using ToolipsSession

main = route("/") do c::AbstractConnection
    mainbody = body(children = [h2(text = "press keys ...")], align = "center")
    ToolipsSession.bind(c, "Enter") do cm::ComponentModifier
        alert!(cm, "enter was pressed")
    end
    ToolipsSession.bind(c, "X") do cm::ComponentModifier
        alert!(cm, "X was pressed")
    end
    ToolipsSession.bind(c, "ArrowRight") do cm::ComponentModifier
        alert!(cm, "the right arrow key was pressed")
    end
    write!(c, mainbody)
end

export session, main
end
```
`ToolipsSession.bind` can also handle these key-presses alongside a 
control, alt, and shift combination.These are provided as symbols.
```julia
main = route("/") do c::AbstractConnection
    mainbody = body(children = [h2(text = "press keys ...")], align = "center")
    ToolipsSession.bind(c, "Enter", :ctrl, :shift) do cm::ComponentModifier
        alert!(cm, "ctrl + shift + enter was pressed")
    end
    write!(c, mainbody)
end
```
Keep in mind that the dispatches taking the `ComponentModiifer` are for callbacks, 
    whereas exclusively the `Connection` is for responses.
```julia
bind(f::Function, c::AbstractConnection, key::String, eventkeys::Symbol ...; on::Symbol = :down, 
prevent_default::Bool = true)
bind(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, key::String,
    eventkeys::Symbol ...; on::Symbol = :down, mark::String = "none")
bind(f::Function, c::AbstractConnection, comp::Component{<:Any},
    key::String, eventkeys::Symbol ...; on::Symbol = :down)
bind(f::Function, c::AbstractConnection, comp::Component{<:Any},
    key::String, eventkeys::Symbol ...; on::Symbol = :down)
bind(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, comp::Component{<:Any},
    key::String, eventkeys::Symbol ...; on::Symbol = :down)
```
"""
function bind(f::Function, c::AbstractConnection, key::String, eventkeys::Symbol ...;
    on::Symbol = :down, prevent_default::Bool = true)
    cm::Toolips.ToolipsServables.ClientModifier = ClientModifier()
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    eventstr::String = join([begin " event.$(event)Key && "
                            end for event in eventkeys])
    ref::String = gen_ref(8)
    write!(c, """<script>
document.addEventListener('key$on', function(event) {
    if ($eventstr event.key == "$(key)") {
    $(prevent)sendpage('$ref');
    }
    });</script>
    """)
    register!(f, c, ref)
    nothing::Nothing
end

function bind(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, key::String,
    eventkeys::Symbol ...; on::Symbol = :down, mark::String = "none", prevent_default::Bool = false)
    eventstr::String = join([begin " event.$(event)Key && "
                            end for event in eventkeys])
    ref = gen_ref(8)
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    push!(cm.changes, """
    setTimeout(function () {
    document.addEventListener('key$on', (event) => {
            if ($eventstr event.key == "$(key)") {
            $(prevent)sendpage('$ref');
            }
            });}, 1000);""")
    register!(f, c, ref)
    nothing::Nothing
end

function bind(f::Function, c::AbstractConnection, comp::Component{<:Any},
    key::String, eventkeys::Symbol ...; on::Symbol = :down, prevent_default::Bool = false)
    cm::AbstractComponentModifier = Toolips.Components.ClientModifier()
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    eventstr::String = join((begin " event.$(event)Key && "
                            end for event in eventkeys))
    ref::String = gen_ref(8)
    write!(c, """<script>
    setTimeout(function () {
    document.getElementById('$(comp.name)').addEventListener('key$on', function(event) {
        if ($eventstr event.key == "$(key)") {
        $(prevent)sendpage('$ref');
        }
});}, 1000)</script>
    """)
    register!(f, c, ref)
    nothing::Nothing
end


function bind(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, comp::Component{<:Any},
    key::String, eventkeys::Symbol ...; on::Symbol = :down, prevent_default::Bool = false)
    ref::String = gen_ref(8)
    name::String = comp.name
    prevent::String = ""
    if prevent_default
        prevent = "event.preventDefault();"
    end
    eventstr::String = join([begin " event.$(event)Key && "
                            end for event in eventkeys])
push!(cm.changes, """setTimeout(function () {
document.getElementById('$(name)').onkeydown = function(event){
        if ($eventstr event.key == '$(key)') {
        $(prevent)sendpage('$ref')
        }
        }}, 1000);""")
    register!(f, c, ref)
    nothing::Nothing
end

"""
```julia
abstract type InputMap
```
The `InputMap` is used to bind multiple event references into one 
client-side function. This is necessary for binding multiple keys, for 
example, as there is only one `keydown` event.
- See also: `ToolipsSession.bind`, `KeyMap`, `SwipeMap`, `Session`, `on`
"""
abstract type InputMap end

"""
```julia
mutable struct SwipeMap <: InputMap
```
- `bindings`**::Dict{String, Function}**

A `SwipeMap` is used to bind swipes to different events. These swipe 
events include `"left"`, `"right"`, `"up"`, `"down"`. The events are 
bound with `bind(::Function, ::AbstractConnection, sm::SwipeMap, swipe::String)` 
to a `SwipeMap` and then bound to a `Connection` with `bind(::AbstractConnection, ::SwipeMap)`.
```example
module MobileSample
using Toolips
using Toolips.Components
using ToolipsSession

page1 = div("sample")
push!(page1, h2(text = "welcome to my page"))
push!(page1, p("main", text = "swipe to change colors"))

session = Session()

mob = route("/") do c::Connection
    mainbody::Component{:body} = body("main-body")
    style!(mainbody, "transition" => 1s)
    sm = SwipeMap()
    ToolipsSession.bind(c, sm, "left") do cm::ComponentModifier
        style!(cm, mainbody, "background-color" => "orange")
        set_text!(cm, "main", "swiped left")
    end
    ToolipsSession.bind(c, sm, "up") do cm::ComponentModifier
        style!(cm, mainbody, "background-color" => "blue")
        set_text!(cm, "main", "swiped up")
    end
    push!(mainbody, page1)
    write!(c, mainbody)
    ToolipsSession.bind(c, sm)
end

export mob, start!, session
end
```
```julia
Event(f::Function, name::String)
```
- See also: `Session`, `on`, `ToolipsSession`, `bind`, `AbstractEvent`
"""
mutable struct SwipeMap <: InputMap
    bindings::Dict{String, Function}
    SwipeMap() = new(Dict{String, Function}())
end

function bind(f::Function, sm::SwipeMap, swipe::String)
    swipes = ("left", "right", "up", "down")
    if ~(swipe in swipes)
        throw(
        "Swipe is not a proper direction, please use up, down, left, or right!")
    end
    sm.bindings[swipe] = f
end

"""
```julia
bind(c::AbstractConnection, sm::SwipeMap)
bind(f::Function, c::AbstractConnection, sm::SwipeMap, swipe::String)
```
`ToolipsSession.bind` is *also* used to bind new swipes to a `SwipeMap`. A `SwipeMap` is an `InputMap` that processes swipe input. The swipes come in 
the form of 4-way strings, `left`, `right`, `up`, and `down`. These are bound to a 
constructed `SwipeMap` with `bind(f::Function, c::AbstractConnection, sm::SwipeMap, swipe::String)` 
and then binded to the `Connection` with `bind(c::AbstractConnection, sm::SwipeMap)`
```julia
home = route("/") do c::Connection
    main_body = body("main")
    sm = ToolipsSession.SwipeMap
    bind(sm, "left") do cm::ComponentModifier
        style!(cm, main_body, "background-color" => "green")
    end
    # bind to connection
    bind(c, sm)
end
```
"""
function bind(c::AbstractConnection, sm::SwipeMap)
    swipes = keys
    swipes = ("left", "right", "up", "down")
    newswipes = Dict([begin
        if swipe in keys(sm.bindings)
            ref::String = ToolipsSession.gen_ref(8)
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
```julia
KeyMap() <: ToolipsSession.InputMap
```
The `KeyMap` is used to handle more complicated inputs with `ToolipsSession` 
events. This is *the* way to bind multiple keys to the same function, for example.
The `KeyMap` is bound using `ToolipsSession.bind(f::Function, km::KeyMap, key::String, event::Symbol ...; prevent_default::Bool = true)` 
and then bound again to the `Connection` -- and optionally in a callback with a `ComponentModifier`, or with a 
`Connection`.
```julia
- `KeyMap()` -> ::KeyMap
```
```julia
# binding to keymap
bind(f::Function, km::KeyMap, key::String, event::Symbol ...; prevent_default::Bool = true)
#                            e.g. ["Enter", "ctrl"]
bind(f::Function, km::KeyMap, events::Vector{String}; prevent_default::Bool = true)
# binding to connection
bind(c::AbstractConnection, km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
bind(c::AbstractConnection, cm::ComponentModifier, km::KeyMap, on::Symbol = :down, prevent_default::Bool = true)
bind(c::AbstractConnection, cm::ComponentModifier, comp::Component{<:Any},
    km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
```
```julia
module KeyMapSample
using Toolips
using Toolips.Components
using ToolipsSession
session = Session()

main = route("/") do c::AbstractConnection
    txtbox = textdiv("text-input")
    km = ToolipsSession.KeyMap()
    ToolipsSession.bind(km, "C", :ctrl) do cm::ComponentModifier
        alert!(cm, "copied")
    end
    ToolipsSession.bind(km, "V", :ctrl) do cm::ComponentModifier
        alert!(cm, "pasted")
    end
    ToolipsSession.bind(c, txtbox, km)
    mainbody = body()
    push!(mainbody, txtbox)
    write!(c, mainbody)
end

export session, main
end
```
- See also: `ToolipsSession.bind`, `on`, `ToolipsSession`, `Session`, `InputMap`, `SwipeMap`
"""
mutable struct KeyMap <: InputMap
    keys::Dict{String, Pair{Tuple, Function}}
    prevents::Vector{String}
    KeyMap() = new(Dict{String, Pair{Tuple, Function}}(), Vector{String}())
end

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


function build_inner_keymap_str!(c::AbstractConnection, km::KeyMap, first_line::String)
    for binding in km.keys
        default::String = ""
        key = binding[1]
        if contains(key, ";")
            key = split(key, ";")[1]
        end
        if (key * join([string(ev) for ev in binding[2][1]])) in km.prevents
            default = "event.preventDefault();"
        end
        ref::String = gen_ref(8)
        eventstr::String = join([" event.$(event)Key && " for event in binding[2][1]])
        first_line = first_line * """ else if ($eventstr event.key == "$key") {$default
                sendpage('$(ref)');
                return 0;
                }"""
        register!(binding[2][2], c, ref)
    end
    return(first_line)::String
end

"""
```julia
# binding to keymap
bind(f::Function, km::KeyMap, key::String, event::Symbol ...; prevent_default::Bool = true)
#                            e.g. ["Enter", "ctrl"]
bind(f::Function, km::KeyMap, events::Vector{String}; prevent_default::Bool = true)
# binding to connection
bind(c::AbstractConnection, km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
bind(c::AbstractConnection, cm::ComponentModifier, km::KeyMap, on::Symbol = :down, prevent_default::Bool = true)
bind(c::AbstractConnection, cm::ComponentModifier, comp::Component{<:Any},
    km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
```
`ToolipsSession.bind` is used to bind keys to a `KeyMap` (as well as other `InputMap`s.) 
The `KeyMap` is bound by providing it to `ToolipsSession.bind` in place of the `Connection`, 
and then binding it to the `Connection` all at once with one `Connection`/`ComponentModifier` 
bindings.
```julia
route("/") do c::AbstractConnection
    km = ToolipsSession.KeyMap()
    bind(km, "A") do cm::ComponentModifier
        alert!(cm, "pressed A")
    end
    bind(km, "D") do cm::ComponentModifier
        alert!(cm, "pressed D")
    end
    action_box = Components.textdiv("mybox")
    bind(c, action_box, km, on = :down)
end
```
"""
function bind(c::AbstractConnection, km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
    first_line::String = """
    setTimeout(function () {
    document.addEventListener('key$on', function (event) { if (1 == 2) {}"""
    first_line = build_inner_keymap_str!(c, km, first_line)
    first_line = first_line * "}.bind(event));}, 500);"
    scr::Component{:script} = script(gen_ref(), text = first_line)
    write!(c, scr)
end

function bind(c::AbstractConnection, comp::Component{<:Any}, km::KeyMap; on::Symbol = :down, prevent_default::Bool = true)
    first_line::String = """
    setTimeout(function () {
    document.getElementById('$(comp.name)').addEventListener('key$on', function (event) { if (1 == 2) {}"""
    first_line = build_inner_keymap_str!(c, km, first_line)
    first_line = first_line * "}.bind(event));}, 500);"
    scr::Component{:script} = script(gen_ref(), text = first_line)
    write!(c, scr)
end

function bind(c::AbstractConnection, cm::ComponentModifier, km::KeyMap, on::Symbol = :down, prevent_default::Bool = true)
    first_line::String = """
    setTimeout(function () {
    document.addEventListener('key$on', function (event) { if (1 == 2) {}"""
    first_line = build_inner_keymap_str!(c, km, first_line)
    first_line = first_line * "}.bind(event));}, 500);"
    push!(cm.changes, first_line)
end

function bind(c::AbstractConnection, cm::ComponentModifier, comp::Component{<:Any},
    km::KeyMap; on::Symbol = :down)
    firsbind = first(km.keys)
    first_line::String = """
    setTimeout(function () {
    document.getElementById('$(comp.name)').addEventListener('key$on', function (event) { if (1 == 2) {}"""
    first_line = build_inner_keymap_str!(c, km, first_line)
    first_line = first_line * "}.bind(event));}, 500);"
    push!(cm.changes, first_line)
end

#==
script!
==#
"""
```julia
script!(f::Function, c::AbstractConnection, ...; time::Integer = 500, type::String = "Interval")
```
Spawns a `Component{:script}` on the client, which makes callbacks to the server 
without a triggering event. The `time` is the number of ms between each call, or the first 
call. `type` is the type of event that should be ran -- `Interval` is the default, and this will 
create a recurring event call. 


- **SCRIPT! IS NOW DEPRECATED, USE ON INSTEAD.**
- The method list below includes `on` equivalents. This will be removed in `Session` `0.5`.
```julia
script!(f::Function, c::AbstractConnection, name::String = gen_ref(8); time::Integer = 500, 
type::String = "Interval")
# use this instead:
on(f::Function, c::AbstractConnection, time::Int64; recurring::Bool = false)

script!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier; time::Integer = 1000, type::String = "Timeout")
# use this instead:
on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, time::Int64; recurring::Bool = false)
```
"""
function script!(f::Function, c::AbstractConnection, name::String = gen_ref(8); time::Integer = 500,
    type::String = "Interval")
    obsscript::Component{:script} = script(name, text = """
    set$(type)(function () { sendpage('$name'); }, $time);
   """)
   register!(f, c, name)
   @warn "Deprecation warning: In `ToolipsSession` 0.5, `script! will be deprecated in favor of using `on`."
   @info "e.g. on(f::Function, c::AbstractConnection, time::Int64; recurring::Bool = false)"
   write!(c, obsscript)
end

function script!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier; time::Integer = 1000, type::String = "Timeout")
   ref = gen_ref(8)
   push!(cm.changes, "set$type(function () { sendpage('$ref'); }, $time);")
   @warn "Deprecation warning: In `ToolipsSession` 0.5, `script! will be deprecated in favor of using `on`."
   @info "e.g. on(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, time::Int64; recurring::Bool = false)"
   register!(f, c, ref)
end

#==
rpc
==#

"""
```julia
open_rpc!(c::AbstractConnection, ...; tickrate::Int64 = 500)
```
Opens an `RPCHost` event with the current client, which can then be joined 
by other clients with `join_rpc!`. Can be done inside of both a callback and a response.
`tickrate` is the number of milliseconds between each update; which is when each Remote Procedure Call 
is made for each peer.
```julia
open_rpc!(c::AbstractConnection; tickrate::Int64 = 500)
open_rpc!(c::AbstractConnection, cm::ComponentModifier; tickrate::Int64 = 500)
```
```example

```
"""
function open_rpc!(c::AbstractConnection; tickrate::Int64 = 500)
    client_events = c[:Session].events[get_session_key(c)]
    found = findfirst(e::AbstractEvent -> typeof(e) <: RPCEvent, client_events)
    if ~(isnothing(found))
        ref = client_events[found].name
        write!(c,  script(ref, text = """setInterval(function () { sendpage('$ref'); }, $tickrate);"""))
        return
    end
    ref::String = gen_ref(8)
    event::RPCHost = RPCHost(ref)
    write!(c,  script(ref, text = """setInterval(function () { sendpage('$ref'); }, $tickrate);"""))
    push!(c[:Session].events[get_session_key(c)], event)
    nothing::Nothing
end

function open_rpc!(c::AbstractConnection, cm::ComponentModifier; tickrate::Int64 = 500)
    client_events = c[:Session].events[get_session_key(c)]
    found = findfirst(e::AbstractEvent -> typeof(e) <: RPCEvent, client_events)
    if ~(isnothing(found))
        ref = client_events[found].name
        push!(cm.changes, "setInterval(function () { sendpage('$ref'); }, $tickrate);")
        return
    end
    ref::String = gen_ref(8)
    event::RPCHost = RPCHost(ref)
    push!(cm.changes, "setInterval(function () { sendpage('$ref'); }, $tickrate);")
    push!(c[:Session].events[get_session_key(c)], event)
    nothing::Nothing
end

"""
```julia
reconnect_rpc!(c::AbstractConnection; tickrate::Int64 = 500)
```
Used to reconnect an incoming client who disconnects to an existing RPC session. This 
just respawns the event that calls the Remote Procedure Calls accumulated by the peers. For 
example, this function would be called when a peer refreshes the page in an active RPC session.
```example

```
"""
reconnect_rpc!(c::Connection; tickrate::Int64 = 500) = begin
    events::Vector{AbstractEvent} = c[:Session].events[get_session_key(c)]
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
```julia
close_rpc!(c::AbstractConnection) -> ::Nothing
```
`close_rpc!` will remove an active RPC session, whether from client or host. 
If host, all subsequent clients will also have their RPC closed.
```example

```
"""
function close_rpc!(c::AbstractConnection)
    close_rpc!(c[:Session], get_session_key(c))
    nothing
end

"""
```julia
join_rpc!(c::AbstractConnection, ...; tickrate::Int64 = 500)
```
`join_rpc` is the companion to `open_rpc!`. This takes one additional argument, 
the IP of the host who we want to join the RPC of. We get their ip with `get_ip(c)`, 
and then we later connect a partner client to that session. Like `open_rpc!` this can 
be done in both a response and a callback using the appropriate functions.
```julia
join_rpc!(c::AbstractConnection, host::String; tickrate::Int64 = 500)
join_rpc!(c::AbstractConnection, cm::ComponentModifier, host::String; tickrate::Int64 = 500)
```
```example

```
"""
function join_rpc!(c::AbstractConnection, host::String; tickrate::Int64 = 500)
    client_events = c[:Session].events[get_session_key(c)]
    found = findfirst(e::AbstractEvent -> typeof(e) <: RPCEvent, client_events)
    if ~(isnothing(found))
        ref = client_events[found].name
        write!(c,  script(ref, text = """setInterval(function () { sendpage('$ref'); }, $tickrate);"""))
        return
    end
    ref::String = gen_ref(8)
    event::RPCClient = RPCClient(c, host, ref)
    write!(c, 
    script(ref, text = """setInterval(function () { sendpage('$ref'); }, $tickrate);"""))
    push!(c[:Session].events[get_session_key(c)], event)
    push!(find_host(c).clients, get_session_key(c))
    nothing::Nothing
end

function join_rpc!(c::AbstractConnection, cm::ComponentModifier, host::String; tickrate::Int64 = 500)
    client_events = c[:Session].events[get_session_key(c)]
    found = findfirst(e::AbstractEvent -> typeof(e) <: RPCEvent, client_events)
    if ~(isnothing(found))
        ref = client_events[found].name
        push!(cm.changes, "setInterval(function () { sendpage('$ref'); }, $tickrate);")
        return
    end
    ref::String = gen_ref(8)
    event::RPCClient = RPCClient(c, host, ref)
    push!(cm.changes, "setInterval(function () { sendpage('$ref'); }, $tickrate);")
    push!(c[:Session].events[get_session_key(c)], event)
    push!(find_host(c).clients, get_session_key(c))
    nothing::Nothing
end

"""
```julia
find_host(c::AbstractConnection) -> ::RPCEvent
```
Finds the `RPCHost` of an actively connected RPC session.
```example

```
"""
function find_host(c::AbstractConnection)
    events = c[:Session].events
    ip::String = get_session_key(c)
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
```julia
rpc!(c::AbstractConnection, cm::ComponentModifier) -> ::Nothing
```
Performs an RPC call on all peers connected to the same RPC session as the 
client associated with `c`, the `Connection`. `rpc!` is used to run these on all 
peers, whereas `call!(::AbstractConnection, ::ComponentModifier)` is used to run on all other peers or a certain peer by IP.
For changes on the client associated with `c` without using RPC, simply use the `ComponentModifier`.

Note that changes will clear with the use of `call!` or `rpc!`, so changes to the client making the 
call will always happen last. The order of `call!` and `rpc!` does not matter, so long as it is before 
`rpc!`.
```example

```
"""
function rpc!(c::AbstractConnection, cm::ComponentModifier)
    rpc!(c[:Session], find_host(c), cm)
end


function rpc!(f::Function, c::AbstractConnection, cm::ComponentModifier)
    cm2 = ComponentModifier(cm.rootc)
    f(cm2)
    rpc!(c[:Session], find_host(c), cm2)
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

"""
```julia
call!(c::AbstractConnection, cm::ComponentModifier, args ...) -> ::Nothing
```
`call!` performs a remote procedure call on either all other clients, or a peer client by IP. 
This is similar to `rpc!`, which will perform the action on all clients.
```julia
call!(c::AbstractConnection, cm::ComponentModifier)
call!(c::AbstractConnection, cm::ComponentModifier, peerip::String)
```
```example

```
"""
function call!(c::AbstractConnection, cm::ComponentModifier)
    call!(c[:Session], find_host(c), cm, get_session_key(c))
end

function call!(f::Function, c::AbstractConnection, cm::ComponentModifier)
    cm2 = ComponentModifier(cm.rootc)
    f(cm2)
    call!(c[:Session], find_host(c), cm2, get_session_key(c))
end

function call!(c::AbstractConnection, cm::ComponentModifier, peerip::String)
    call!(c[:Session], find_host(c), cm, get_session_key(c), peerip)
end

export Session, on, script!, ComponentModifier, call!, get_ref
export rpc!, call!, disconnect_rpc!, find_client, join_rpc!, close_rpc!, open_rpc!, reconnect_rpc!
end # module
