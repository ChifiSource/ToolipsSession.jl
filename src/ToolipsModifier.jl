"""
Created in June, 2022 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
### ToolipsModifier
**Extension for:**
- [Toolips](https://github.com/ChifiSource/Toolips.jl) \
This module provides the capability to make web-pages interactive using
##### Module Composition
- [**ToolipsModifier**](https://github.com/ChifiSource/ToolipsModifier.jl)
"""
module ToolipsModifier

using Toolips
import Toolips: ServerExtension, route!, style!, animate!, Servable, Connection
import Toolips: StyleComponent
#import SpoofConnection, AbstractConnection
import Base: setindex!, getindex
using Random, Dates

function gen_ref()
    Random.seed!( rand(1:100000) )
    randstring(16)
end

"""
"""
mutable struct Modifier <: ServerExtension
    type::Vector{Symbol}
    f::Function
    active_routes::Vector{String}
    events::Dict
    iptable::Dict{String, Dates.DateTime}
    timeout::Integer
    function Modifier(active_routes::Vector{String} = ["/"];
        transition_duration::AbstractFloat = 0.5,
        transition::AbstractString = "ease-in-out", timeout::Integer = 10)
        events = Dict()
        iptable = Dict{String, Dates.DateTime}()
        f(c::Connection, active_routes = active_routes) = begin
            fullpath = c.http.message.target
            if contains(fullpath, '?')
                fullpath = split(c.http.message.target, '?')[1]
            end
            if fullpath in active_routes
                if ~(getip(c) in keys(events))
                    events[getip(c)] = Dict{String, Function}()
                else
                    if minute(now()) - minute(iptable[getip(c)]) >= timeout
                        delete!(iptable, getip(c))
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
                #felt div {
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
getindex(m::Modifier, s::AbstractString) = m.events[s]
getindex(m::Modifier, s::AbstractString) = m.events[s]
function on(f::Function, c::Connection, s::Component,
     event::AbstractString)
    ref = gen_ref()
    name = s.name
    s["on$event"] = "sendpage('$event$name');"
    push!(c[:mod][getip(c)], "$event$name" => f)
end

"""
"""
route!(se::ServerExtension, r::AbstractString) = push!(r.active_routes, r)

function observe!(f::Function, c::Connection; signal::Bool = false)
    TimedTrigger(f, time::Integer, signal = false)
    write!(c, TimedTrigger)
end
mutable struct TimedTrigger
    time::Integer
    f::Function
    ref::AbstractString
    signal::Bool
    function TimedTrigger(time::Integer, signal::Bool = false)
        ref = ""
        f(c::Connection) = begin
            ref = gen_ref()
            push!(c[Modifier][get_ip(c)], ref => f)
            if signal
                write!(c, """
                setTimeout(function () {
                  sendinfo('$ref');
               }, $time);
               """)
            else
               write!(c, """
               setTimeout(function () {
                 sendpage('$ref');
              }, $time);
              """)
            end
        end
        new(time, f, ref, signal)
    end
end

"""
### ComponentModifier <: Servable
A connection Servable is served by the ToolipsModifier.Modifier
ServerExtension, it is set to modify the  base components (not Servables, but
**Servables are planned in a future version**.)
###### fields
- name::AbstractString
- properties**::Dict** - Properties
- f**::Function**
###### example
"""
mutable struct ComponentModifier <: Servable
    html::AbstractString
    f::Function
    changes::Vector{String}
    function ComponentModifier(html)
        f(c::Connection) = begin
            write!(c, join(changes))
        end
        changes = Vector{String}()
        extras = Vector{Servable}()
        new(html, f, changes)
    end
end

function setindex!(cc::ComponentModifier, p::Pair, s::Component)
    modify!(cc, s, p)
end

function getindex(cc::ComponentModifier, s::Component)
    name = s.name
    tag = s.tag
    s = cc.html
    tagrange = findall("<$tag id=\"$name\"", s)[1]
    unsplit_props = s[tagrange[2]:findnext(">", s, tagrange[2])[1]]
    ps = split(unsplit_props, " ")
    pairs = Vector{Pair{Any, Any}}()
    for p in 1:length(ps)
        if ps[p] == "="
            ps[p] = replace(ps[p], " " => "")
            push!(pairs, string(ps[p - 1]) => replace(string(join([ps[p + 1]])),
             "\"" => ""))
        end
    end
    props = Dict(pairs)
    cname = ""
    if "id" in keys(props)
        cname = props["id"]
    else
        cname = "unknown"
    end
    props["children"] = Vector()
    props["text"] = ""
    c = Component(cname, tag, props)
    endtag = findnext("</$tag>", s, tagrange[2])
    if ~(contains(s[tagrange[2]:endtag[1]], "<$tag"))
        if ~(contains(s[tagrange[2]:endtag[1] - 1], "<"))
            c["text"] = s[tagrange[2] + 1:endtag[1] - 1]
        else
            comps = makefrom_string(s[tagrange[2] + 1:endtag[1] - 1])
            [push!(c, comp) for comp in comps]
        end
    else
        n_tags = findall("<$tagname", s[tagrange[2]:length(s)])
        tag_ends = findall("</$tagname>", s[tagrange[2]:length(s)])
        pos = 1
        for i in 1:length(tag_ends)
            if i in n_tags
                if n_tags[i][1] > tag_ends[i][1]
                    pos = i
                end
            else
                pos = i
            end
        end
        endtag = tag_ends[pos]
        comps = makefrom_string(s[tagrange[2] + 1:endtag[1] - 1])
        [push!(c, comp) for comp in comps]
    end
end

function makefrom_string(s::AbstractString)
    comps = []
    stap = [start:stop for (start, stop) in zip(findall("<", s), findall(">"))]
    for range in stap
        name_start = findall("id=", s[range])[1][2] + 1
        name_end = findnext(" ", s[range], name_sart)[2] - 1
        tag = s[range[1] + 1:findnext(" ", s, r[1])]
        push!(comps, s[name_start:name_end])
    end
    [comps = cc[Component(c[1], c[2])] for c in comps]
end

alert!(cm::ComponentModifier, s::AbstractString) = push!(cc.changes, "alert('$s');")

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

function modify!(cm::ComponentModifier, s::Servable, p::Pair ...)
    p = [pair for pair in p]
    modify!(cm, s, p)
end

function modify!(cm::ComponentModifier, s::Servable,
    p::Vector{Pair{String, String}})
    name = s.name
    key, val = p[1], p[2]
    push!(cc.changes,
"document.getElementById('$name').setAttribute('$key','$val');")
end

modify!(cm::ComponentModifier, s::Servable, p::Pair) = modify!(cm, s, [p])

function add_child!(cm::ComponentModifier, s::Servable, s2::Servable, ;
     at::Integer = 0)
     comp = cm[s]
     inner = ""
end

function get_inner()

end

function get_text()

end

function style!(cm::ComponentModifier, s::Servable, p::Pair{String, String} ...)
    p = [pair for pair in p]
    style!(cm::ComponentModifier, s::Servable, p::Pair{String, String})
end

function style!(cm::ComponentModifier, s::Servable, p::Vector{Pair{String, String}})
    name = s.name
    getelement = "var new_element = document.getElementById('$name');"
    push!(c.changes, getelement)
    for pair in p
        value = p[2]
        key = p[1]
        push!(c.changes, "new_element.style['$key'] = '$value';")
    end
end

function remove!(c::Connection, fname::AbstractString, s::Servable)
    refname = s.name * fname
    delete!(c[Modifier][get_ip()], refname)
end

function kill_session!(c::Connection)
    delete!(c[Modifier].iptable, getip(c))
    delete!(c[Modifier].refs, get_ip(c))
end

"""
"""
function document_linker(c::Connection)
    s = getpost(c)
    reftag = findall("?CM?:", s)
    ref_r = reftag[1][2] + 4:length(s)
    ref = s[ref_r]
    s = replace(s, "?CM?:$ref" => "")
    cm = ComponentModifier(s)
    c[:mod].iptable[getip(c)] = now()
    if ref in
        c[:mod][getip(c)][ref](cm)
    else
        write!(c, "timeout")
    end
end

"""

"""
function parse_comphtml(s::AbstractString)
    open_tags = findall("<", s)
    close_tags = findall(">", s)
    # for the future, we can zip this and make it one line with one of these
    open_close = [open_tags[i][1]:close_tags[i][1] for i in 1:length(open_tags)]
    Servables = []
    for n in 1:length(open_close)
        tagrange = open_close[n]

        if isnothing(endtag)
            push!(Servables, tagrange[2]:maximum(tagrange) + 1 => c)
        else
            push!(Servables, tagrange[2]:endtag[1] => c)
        end
    end
    news = []
    for Servable in Servables
        if Servable[1][2] - 1 == Servable[1][1]
            push!(news, Servable[2])
            continue
        end
        for (n, p) in enumerate(Servables)
            if p[1][1] in Servable[1]
                push!(Servable[2], p[2])
                deleteat!(Servables, n)
                push!(news, Servable[2])
            else
                Servable[2][:text] = s[Servable[1]]
            end
        end
    end
    return(Dict([s[2].name => s[2] for s in Servables]))
end

export Modifier, ComponentModifier, on
end # module
