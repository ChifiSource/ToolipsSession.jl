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
import Toolips: ServerExtension, Servable, route!
import Base: setindex!, getindex
using Random
function gen_ref()
    Random.seed!( rand(1:100000) )
    randstring(16)
end
"""
"""
mutable struct Modifier <: ServerExtension
    type::Vector{Symbol}
    f::Function
    refs::Dict
    active_routes::Vector{String}
    on::Function
    function Modifier(active_routes::Vector{String} = ["/"])
        f(c::Connection, active_routes = active_routes) = begin
            fullpath = c.http.message.target
            if contains(fullpath, '?')
                fullpath = split(c.http.message.target, '?')[1]
            end
            if fullpath in active_routes
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
                """)
            end
        end
        f(routes::Dict, ext::Dict) = begin
            routes["/modifier/linker"] = document_linker
        end
        refs = Dict()

        function on(f::Function, s::Component, event::String, refs = refs)
            ref = gen_ref()
            s["on$event"] = "sendpage($ref);"
            refs[Symbol(ref)] = f
        end

        function onkey(f::Function, s::Symbol)

        end
        new([:connection, :func, :routing], f, refs, active_routes, on)
    end
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
    name::String
    tag::String
    properties::Dict
    f::Function
    changes::Dict
    function ComponentModifier(name::String, tag::String,
         properties::Dict = Dict())
        f(c::Connection) = begin
    write!(c, "</script>console.log('ComponentModifier was queried.');</script")
        end
        changes = Dict()
        new(name, tag, properties, f, changes)
    end
end
setindex!(cc::ComponentModifier, a::Any, s::String) = cc.changes[a] = s
getindex(cc::ComponentModifier, a::Any) = cc.changes[a]


"""
"""
function document_linker(c::Connection)
    s = getpost(c)
    reftag = findall(s, "?CM?:")
    ref_r = maximum(ref) + 1:length(s)
    ref = ref[ref_r]
    s = replace(s, "?CM?:$ref" => "")
    s = parse_comphtml(s)
    vs = Vector{Servable}(values(s))
    c[Modifier].refs[Symbol(ref)](c, vs)
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
        if contains(s[tagrange], "/")
            continue
        end
        println(tagrange)
        println(length(s))
        if tagrange[2] + 1 != length(s)
            tagname_r = tagrange[1] + 1:findnext(" ", s, tagrange[1])[1] - 1
        else
            tagname_r = tagrange[1] + 1:length(s)
        end
        tagname = s[tagname_r]
        unsplit_props = s[maximum(tagname_r) + 1:maximum(tagrange) - 1]
        unsplit_props = replace(unsplit_props, "=" => ":")
        ps = split(unsplit_props, " ")
        pairs = Vector{Pair{Any, Any}}()
        for p in 1:length(ps)
            if ps[p] == ":"
                ps[p] = replace(ps[p], " " => "")
                push!(pairs, string(ps[p - 1]) => replace(string(join([ps[p + 1]])), "\"" => ""))
            end
        end
        props = Dict(pairs)
        println(props)
        cname = props["name"]
        props["children"] = Vector()
        props["text"] = ""
        c = ComponentModifier(cname, tagname, props)
        endtag = findnext("</$tagname>", s, tagrange[2])
        push!(servables, tagrange[2]:endtag[1] => c)
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

export Modifier, ComponentModifier
end # module
