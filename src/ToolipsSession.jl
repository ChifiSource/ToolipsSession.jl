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
using EzXML
using Toolips
import Toolips: ServerExtension, route!, style!, Servable, Connection
import Toolips: StyleComponent, get, kill!, animate!, SpoofConnection
import Base: setindex!, getindex, push!, append!
using Random, Dates

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
    on(c, "load") do c::ComponentModifier

    end
    write!(c, myp)
    write!(c, timer)
end
```
"""
function on(f::Function, c::Connection, event::AbstractString)

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
    s = getpost(c)
    reftag = findall("?CM?:", s)
    ref_r = reftag[1][2] + 4:length(s)
    ref = s[ref_r]
    s = replace(s, "?CM?:$ref" => "")
    cm = ComponentModifier(s)
    if getip(c) in keys(c[:Session].iptable)
        c[:Session].iptable[getip(c)] = now()
    else
        write!(c, "timeout"); return
    end
    if getip(c) in keys(c[:Session].events)
        c[:Session][getip(c)][ref](cm)
        write!(c, cm)
    else
        write!(c, "timeout")
    end
end

"""
### TimedTrigger
- time::Integer
- f::Function \
Creates a timer which will post to the function f.
##### example
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
------------------
##### constructors
TimedTrigger(func::Function, time::Integer)
"""
mutable struct TimedTrigger <: Servable
    time::Integer
    f::Function
    function TimedTrigger(func::Function, time::Integer)
        f(c::Connection) = begin
            ref = gen_ref()
            push!(c[:Session][getip(c)], ref => f)
               write!(c, """
               <script>
               setTimeout(function () {
                 sendpage('$ref');
              }, $time);
              </script>
              """)
            end
        new(time, f)
    end
end

"""
**Session Interface**
### observe!(f::Function, c::Connection, time::Integer) -> _
------------------
Creates a TimedTrigger, and then writes it to the connection.
#### example
```
route("/") do c::Connection
    observe!(c, 1000) do cm::ComponentModifier
        ...
    end
end
```
"""
function observe!(f::Function, c::Connection, time::Integer)
    write!(c, TimedTrigger(f, time))
end

"""
**Session Internals**
### htmlcomponent(s::String) -> ::Dict{String, Toolips.Component}
------------------
Converts HTML into a dictionary of components.
#### example
```
s = "<div id = 'hello' align = 'center'></div>"
comp = htmlcomponent(s)
comp["hello"]["align"]
    "center"
```
"""
function htmlcomponent(s::String)
    doc = parsehtml(s)
    ro = root(doc)
    rn = firstnode(ro)
    children = Dict()
    for n in eachelement(rn)
        if haselement(n)
            for node in eachelement(n)
                child = htmlcomponent(string(node))
                [push!(children, c) for c in child]
            end
        end
        comp = createcomp(n)
        push!(children, comp.name => comp)
    end
    properties = Dict()
    for property in eachattribute(ro)
        sc = replace(string(property), "\"" => "")
        sc = replace(sc, " " => "")
        scspl = split(sc, "=")
        proppair = string(scspl[1]) => string(scspl[2])
        push!(properties, proppair)
    end
    c = Component("main", string(ro.name), properties)
    push!(children, c.name => c)
    children
end

function createcomp(element)
    properties = Dict()
    for property in eachattribute(element)
        sc = replace(string(property), "\"" => "")
        sc = replace(sc, " " => "")
        scspl = split(sc, "=")
        proppair = string(scspl[1]) => string(scspl[2])
        push!(properties, proppair)
    end
    children = Dict()
        tag = string(element.name)
        properties[:text] = string(element.content)
        name = "undefined $tag"
        if "id" in keys(properties)
            name = properties["id"]
        end
    Component(name, tag, properties)
end

"""
### ComponentModifier
- rootc::Dict
- f::Function
- changes::Vector{String} \
The ComponentModifier stores a dictionary of components that can be indexed
using the Components themselves or their names. Methods push strings to the
changes Dict. This is passed as an argument into the function provided to the
on functions via the do syntax. Indexing will yield a given Component, setting
the index to a pair will modify said component.
##### example
```
route("/") do c::Connection
    mydiv = divider("mydiv", align = "center")
    on(c, mydiv, "click") do cm::ComponentModifier
        if cm[mydiv]["align"] == "center"
            cm[mydiv] = "align" => "left"
        else
            cm[mydiv] = "align" => "center"
        end
    end
    write!(c, mydiv)
end
```
------------------
##### constructors
ComponentModifier(html::String)
"""
mutable struct ComponentModifier <: Servable
    rootc::Dict
    f::Function
    changes::Vector{String}
    function ComponentModifier(html::String)
        rootc = htmlcomponent(html)
        f(c::Connection) = begin
            write!(c, join(changes))
        end
        changes = Vector{String}()
        new(rootc, f, changes)
    end
end

"""
**Session Interface**
### setindex!(cm::ComponentModifier, p::Pair, s::Component) -> _
------------------
Sets the property from p[1] to p[2] on the served Component s.
#### example
```
on(c, mydiv, "click") do cm::ComponentModifier
    if cm[mydiv]["align"] == "center"
        cm[mydiv] = "align" => "left"
    else
        cm[mydiv] = "align" => "center"
    end
end
```
"""
setindex!(cm::ComponentModifier, p::Pair, s::Component) = modify!(cm, s, p)

setindex!(cm::ComponentModifier, p::Pair, s::String) = modify!(cm, s, p)

"""
**Session Interface**
### getindex(cm::ComponentModifier, s::Component) -> ::Component
------------------
Gets the Component s from the ComponentModifier cm.
#### example
```
on(c, mydiv, "click") do cm::ComponentModifier
    mydiv = cm[mydiv]
    mydivalignment = mydiv["align"]
end
```
"""
getindex(cc::ComponentModifier, s::Component) = cc.rootc[s.name]

"""
**Session Interface**
### getindex(cm::ComponentModifier, s::String) -> ::Component
------------------
Gets the a Component by name from cm.
#### example
```
on(c, mydiv, "click") do cm::ComponentModifier
    mydiv = cm["mydiv"]
    mydivalignment = mydiv["align"]
end
```
"""
getindex(cc::ComponentModifier, s::String) = cc.rootc[s]

"""
**Interface**
### properties!(::Servable, ::Servable) -> _
------------------
Copies properties from s,properties into c.properties.
#### example
```

```
"""
function animate!(cm::ComponentModifier, s::Servable, a::Animation;
     play::Bool = true)
     playstate = "running"
     if ~(play)
         playstate = "paused"
     end
    name = s.name
    animname = a.name
    time = string(a.length) * "s"
     push!(cm.changes,
     "document.getElementById('$name').style.animation = '$time 1 $animname';")
     push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = '$playstate';")
end

function pauseanim!(cm::ComponentModifier, s::Servable)
    name = s.name
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'paused';")
end
function playanim!(cm::ComponentModifier, s::Servable)
    name = s.name
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'paused';")
end

alert!(cm::ComponentModifier, s::AbstractString) = push!(cm.changes,
                                                            "alert('$s');")

function redirect!(cm::ComponentModifier, url::AbstractString, delay::Int64 = 0)
    push!(cm.changes, """
    setTimeout(function () {
      window.location.href = "$url";
   }, $delay);
   """)
end

function style!(cc::ComponentModifier, s::Servable,  p::Style)
    name = s.name
    sname = p.name
    push!(cc.changes, "document.getElementById('$name').className = '$sname';")
end

"""
"""
function modify!(cm::ComponentModifier, s::Servable, p::Pair ...)
    p = [pair for pair in p]
    modify!(cm, s, p)
end

"""
"""
function modify!(cm::ComponentModifier, s::Servable,
    p::Vector{Pair{String, String}})
    [modify!(cm, s, z) for z in p]
end

"""
"""
modify!(cm::ComponentModifier, s::Servable, p::Pair) = modify!(cm, s.name, p)

function modify!(cm::ComponentModifier, s::String, p::Pair)
    key, val = p[1], p[2]
    push!(cm.changes,
    "document.getElementById('$s').setAttribute('$key','$val');")
end


function move!(cm::ComponentModifier, p::Pair{Servable, Servable})
    firstname = p[1].name
    secondname = p[2].name
    push!(cm.changes, "
    document.getElementById('$firstname').appendChild(
    document.getElementById('$secondname')
  );
  ")
end

function remove!(cm::ComponentModifier, s::Servable)
    name = s.name
    push!(cm.changes, "document.getElementById('$name').remove();")
end

function remove!(cm::ComponentModifier, s::Servable, child::Servable)
    name, cname = s.name, child.name
    push!(cm.changes, "document.getElementById('$name').removeChild('$cname');")
end

function set_text!(c::ComponentModifier, s::Servable, txt::String)
    name = s.name
    push!(c.changes, "document.getElementById('$name').innerHTML = `$txt`;")
end

function set_children!(cm::ComponentModifier, s::Servable, v::Vector{Servable})
    spoofconn::SpoofConnection = SpoofConnection()
    write!(spoofconn, v)
    txt::String = spoofconn.http.text
    set_text!(cm, s, txt)
end

function append!(cm::ComponentModifier, s::Servable, child::Servable)
    name = s.name
    ctag = child.tag
    exstr = "var element = document.createElement($ctag);"
    for prop in child.properties
        if prop[1] == :children
            spoofconn::SpoofConnection = SpoofConnection()
            write!(spoofconn, prop[2])
            txt = spoofconn.http.text
            push!(cm.changes, "element.innerHTML = `$txt`;")
        elseif prop[1] == :text
            txt = prop[2]
            push!(cm.changes, "element.innerHTML = `$txt`;")
        else
            key, val = prop[1], prop[2]
            push(cm.changes, "element.setAttribute('$key',`$val`);")
        end
    end
    push!(cm.changes, "document.getElementById('$name').appendChild(element);")
end

"""
"""
get_text(cm::ComponentModifier, s::Component) = cm[s][:text]

"""
"""
function style!(cm::ComponentModifier, s::Servable, p::Pair{String, String} ...)
    p = [pair for pair in p]
    style!(cm::ComponentModifier, s::Servable, p)
end

function style!(cm::ComponentModifier, s::Servable, p::Pair)
    name = s.name
    push!(cm.changes,
        "document.getElementById('$name').style['$key'] = '$value';")
end
"""
"""
function style!(cm::ComponentModifier, s::Servable,
    p::Vector{Pair{String, String}})
    name = s.name
    getelement = "var new_element = document.getElementById('$name');"
    push!(cm.changes, getelement)
    for pair in p
        value = pair[2]
        key = pair[1]
        push!(cm.changes, "new_element.style['$key'] = '$value';")
    end
end

"""
"""
function remove!(c::Connection, fname::AbstractString, s::Servable)
    refname = s.name * fname
    delete!(c[:Session][getip()], refname)
end

"""
"""
function kill!(c::Connection)
    delete!(c[:Session].iptable, getip(c))
    delete!(c[:Session].events, getip(c))
end


export Session, ComponentModifier, on, modify!, redirect!, TimedTrigger
export alert!, insert!, move!, remove!, get_text, get_children, observe!
export set_text!, move!, pauseanim!, playanim!, set_children!

end # module
