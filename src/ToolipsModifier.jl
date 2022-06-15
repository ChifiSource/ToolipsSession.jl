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
import Toolips: ServerExtension, Servable, route!, style!, animate!
import Toolips: StyleComponent, SpoofConnection
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
    iptable::Dict{String, String}
    timeout::Integer
    function Modifier(active_routes::Vector{String} = ["/"];
        transition_duration::AbstractFloat = 0.5,
        transition::String = "ease-in-out", timeout::Integer = 10)
        events = Dict()
        f(c::Connection, active_routes = active_routes) = begin
            fullpath = c.http.message.target
            if contains(fullpath, '?')
                fullpath = split(c.http.message.target, '?')[1]
            end
            if fullpath in active_routes
                if ~(getip(c) in keys(events))
                    events[getip(c)] = Vector{Pair}()
                else
                    if iptable[getip(c)].minutes >= timeout
                        delete!(iptable, getip(c))
                    end
                end
                durstr = string(transition_duration, "s")
                write!(c, """<script>
                function sendpage(ref) {
                var ref2 = '?CM?:' + ref;
                var bodyHtml = document.getElementsByTagName('body')[0].innerHTML;
                let xhr = new XMLHttpRequest();
                xhr.open("POST", "/modifier/linker");
                xhr.setRequestHeader("Accept", "application/json");
                xhr.setRequestHeader("Content-Type", "application/json");
                xhr.onload = () => eval(xhr.responseText);
                xhr.send(bodyHtml + ref2);
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
        Dict{String, String}(), timeout)
    end
end
getindex(m::Modifier, s::String) = m.events[s]
setindex!(m::Modifier, a::Function, s::String) = m.events[s] = a
function on(f::Function, c::Connection, s::Component,
     event::String)
     Random.seed!( rand(1:100000) )
     randstring(16)
    ref = gen_ref()
    name = s.name
    s["on$event"] = "sendpage('$event$name');"
    push!(c[:mod][getip(c)], "$event$name" => f)
end

"""
"""
route!(se::ServerExtension, r::String) = push!(r.active_routes, r)

"""
### ComponentModifier <: Servable
A connection Servable is served by the ToolipsModifier.Modifier
ServerExtension, it is set to modify the  base components (not servables, but
**servables are planned in a future version**.)
###### fields
- name::String
- properties**::Dict** - Properties
- f**::Function**
###### example
"""
mutable struct ComponentModifier <: Servable
    html::String
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
    name = s.name
    value = p[2]
    prop = p[1]
    push!(cc.changes, "document.getElementById('$name').$prop = '$value';")
end

function getindex(cc::ComponentModifier, s::Component)
    name = s.name
    tag = s.tag
    s = cc.html
    tagrange = findall("<$tag id='$name'", s)[1]
    unsplit_props = s[tagrange[2]:findnext(">", s[tagrange], tagrange[2])]
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
    if "id" in props
        cname = props["id"]
    else
        cname = "unknown"
    end
    props["children"] = Vector()
    props["text"] = ""
    c = ComponentModifier(cname, tagname, props)
    endtag = findnext("</$tagname>", s, tagrange[2])
    if ~(contains(s[tagrange[2]:endtag[1]], "<$tagname>"))
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

function makefrom_string(s::String)
    stap = [start:stop for (start, stop) in zip(findall("<", s), findall(">"))]
    for range in stap
        tagrange = range[1]:findnext(" ", s, range[1])[1] - 1
        name_r = findall("id=", s[range]) + 1:
    end
    [comps = cc[Component(c[1], c[2])] for c in comps]
end

alert!(cm::ComponentModifier, s::String) = push!(cc.changes, "alert('$s');")

function redirect!(cm::ComponentModifier, url::String, delay::Int64 = 0)
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

    push!(cc.changes,
"document.getElementById('$name').setAttribute('style','$style');")
end

modify!(cm::ComponentModifier, s::Servable, p::Pair)

function add_child!(cm::ComponentModifier, s::Servable, s::Servable, ;
     at::Integer = 0)
     comp = cm[s]
     if at == 0
         at = length(comp[:children])
     end

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
function parse_comphtml(s::String)
    open_tags = findall("<", s)
    close_tags = findall(">", s)
    # for the future, we can zip this and make it one line with one of these
    open_close = [open_tags[i][1]:close_tags[i][1] for i in 1:length(open_tags)]
    servables = []
    for n in 1:length(open_close)
        tagrange = open_close[n]

        if isnothing(endtag)
            push!(servables, tagrange[2]:maximum(tagrange) + 1 => c)
        else
            push!(servables, tagrange[2]:endtag[1] => c)
        end
    end
    news = []
    for servable in servables
        if servable[1][2] - 1 == servable[1][1]
            push!(news, servable[2])
            continue
        end
        for (n, p) in enumerate(servables)
            if p[1][1] in servable[1]
                push!(servable[2], p[2])
                deleteat!(servables, n)
                push!(news, servable[2])
            else
                servable[2][:text] = s[servable[1]]
            end
        end
    end
    return(Dict([s[2].name => s[2] for s in servables]))
end

export Modifier, ComponentModifier, on
end # module
