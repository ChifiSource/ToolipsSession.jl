"""
Created in June, 2022 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
### ToolipsSession
**Extension for:**
- [Toolips](https://github.com/ChifiSource/Toolips.jl) \
This module provides the capability to make web-pages interactive using
##### Module Composition
- [**ToolipsSession**](https://github.com/ChifiSource/ToolipsSession.jl)
"""
module ToolipsSession
using EzXML
using Toolips
import Toolips: ServerExtension, route!, style!, Servable, Connection
import Toolips: StyleComponent, get, kill!, animate!
import Base: setindex!, getindex, push!
using Random, Dates

function gen_ref()
    Random.seed!( rand(1:100000) )
    randstring(16)
end

"""
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
        transition::AbstractString = "ease-in-out", timeout::Integer = 10)
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
getindex(m::Session, s::AbstractString) = m.events[s]
getindex(m::Session, s::AbstractString) = m.events[s]

"""
"""
mutable struct TimedTrigger <: Servable
    time::Integer
    f::Function
    ref::AbstractString
    function TimedTrigger(func::Function, time::Integer)
        ref = ""
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
        new(time, f, ref)
    end
end

"""
"""
function observe!(f::Function, c::Connection)
    write!(c, TimedTrigger(f, 3000))
end

function htmlcomponent(s::String)
    doc = parsehtml(s)
    ro = root(doc)
    rn = firstnode(ro)
    children = Vector{Servable}()
    for n in eachelement(rn)
        if haselement(n)
            for node in eachelement(n)
                child = htmlcomponent(string(node))
                push!(children, child)
            end
        end
        comp = createcomp(n)
        comp[:children] = children
        push!(children, comp)
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
    c[:children] = children
    c
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
### ComponentModifier <: Servable
A connection Servable is passed as an argument to event functions, such as on.
###### fields
- name::AbstractString
- properties**::Dict** - Properties
- f**::Function**
###### example
home = route("/") do c::Connection
    mytext = p("green", text = "hello world!")
    on(c, mytext, "click") do cm::ComponentModifier
        current_text = cm[mytext][:text]
        cm[mytext] = "color" => current_text
        alert!(cm, "Color has been changed.")
    end
end
"""
mutable struct ComponentModifier <: Servable
    rootc::Component
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

function setindex!(cm::ComponentModifier, p::Pair, s::Component)
    modify!(cm, s, p)
end

function getindex(cc::ComponentModifier, s::Component)
    return(get(cc, s.name))
end

function get(cc::ComponentModifier, s::String)
    for child in cc.rootc[:children]
        if child.name == s
            return(child)
        end
        if has_children(c)
            get(c, s)
        end
    end
end

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
function modify!(cm::ComponentModifier, s::Servable, p::Pair)
    name = s.name
    key, val = p[1], p[2]
    push!(cm.changes,
    "document.getElementById('$name').setAttribute('$key','$val');")
end

"""
"""
function insert!(cm::ComponentModifier, s::Servable, s2::Servable)
     name = s.name
     ctag = s2.tag
     propities = copy(s2.properties)
     children = s2[:children]
     text = s2[:text]
     for prop in s2
         key, val = prop[1], prop[2]
     end
     "insertBefore(newDiv, currentDiv);"
     """var newelement = document.createElement("div");
     """
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
function set_text!(c::ComponentModifier, s::Servable, txt::String)
    push!(c.changes, "document.getElementById($name).innerHTML = $txt;")
end

function set_children!(cm::ComponentModifier, s::Servable, v::Vector{Servable})
    spoofconn = SpoofConnection()
    write!(spoofconn, v)
    txt = spoofconn.http.text
    set_text!(cm, s, txt)
end

"""
"""
get_children(cm::ComponentModifier, s::Component) = cm[s][:children]

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
function style!(cm::ComponentModifier, s::Servable, p::Vector{Pair{String, String}})
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

"""
"""
function on(f::Function, c::Connection, s::Component,
     event::AbstractString)
    name = s.name
    s["on$event"] = "sendpage('$event$name');"
    push!(c[:Session][getip(c)], "$event$name" => f)
end

"""
### document_linker(c::Connection) -> _

"""
function document_linker(c::Connection)
    s = getpost(c)
    reftag = findall("?CM?:", s)
    ref_r = reftag[1][2] + 4:length(s)
    ref = s[ref_r]
    s = replace(s, "?CM?:$ref" => "")
    cm = ComponentModifier(s)
    c[:Session].iptable[getip(c)] = now()
    if getip(c) in keys(c[:Session].events)
        c[:Session][getip(c)][ref](cm)
        write!(c, cm)
    else
        write!(c, "timeout")
    end
end

export Session, ComponentModifier, on, modify!, redirect!, TimedTrigger
export alert!, insert!, move!, remove!, get_text, get_children, observe!
export set_text!, move!, pauseanim!, playanim!, set_children!
end # module
