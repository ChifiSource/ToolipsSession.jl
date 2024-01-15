using Toolips
import Toolips: StyleComponent, get, kill!, animate!, SpoofConnection
import Toolips: style!, Servable, Connection, Modifier, string
import Base: setindex!, getindex, push!, append!, insert!

"""

"""
mutable struct ComponentModifier <: AbstractComponentModifier
    rootc::Vector{Servable}
    changes::Vector{String}
    function ComponentModifier(html::String)
        rootc::Vector{Servable} = htmlcomponent(html)
        changes::Vector{String} = Vector{String}()
        new(rootc, changes)::ComponentModifier
    end
    function ComponentModifier(html::String, readonly::Vector{String})
        rootc::Vector{Servable} = htmlcomponent(html, readonly)
        changes::Vector{String} = Vector{String}()
        new(rootc, changes)::ComponentModifier
    end
end

getindex(cc::ComponentModifier, s::AbstractComponent) = cc.rootc[s.name]

getindex(cc::ComponentModifier, s::String) = cc.rootc[s]

"""
**Session Interface**
### animate!(cm::AbstractComponentModifier, s::String, a::Animation; play::Bool) -> _
------------------
Updates the servable with name s's animation with the animation a.
#### example
```
s = divider("mydiv")
a = Animation("fade")
a[:from] = "opacity" => "0%"
a[:to] = "opacity" => "100%"
# where c is the Connection.
on(c, s, "click") do cm::AbstractComponentModifier
    animate!(cm, s, a)
end
     ```
     """
function animate!(cm::AbstractComponentModifier, s::String, a::Animation;
    play::Bool = true)
    playstate = "running"
    if ~(play)
        playstate = "paused"
    end
    animname = a.name
    time = string(a.length) * "s"
     push!(cm.changes,
     "document.getElementById('$s').style.animation = '$time 1 $animname';")
     push!(cm.changes,
    "document.getElementById('$s').style.animationPlayState = '$playstate';")
end

"""

"""
pauseanim!(cm::AbstractComponentModifier, s::AbstractComponent) = pauseanim!(cm, s.name)

"""

"""
playanim!(cm::AbstractComponentModifier, s::AbstractComponent) = playanim!(cm, s.name)

"""

"""
function pauseanim!(cm::AbstractComponentModifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'paused';")
end

"""

"""
function playanim!(cm::AbstractComponentModifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'running';")
end

"""

"""
function free_redirects!(cm::AbstractComponentModifier)
    push!(cm.changes, """window.onbeforeunload = null;""")
end

"""

"""
function confirm_redirects!(cm::AbstractComponentModifier)
    push!(cm.changes, """window.onbeforeunload = function() {
    return true;
};""")
end

"""

"""
function scroll_to!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollTo($(xy[1]), $(xy[2]));""")
end

"""

"""
function scroll_by!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollBy($(xy[1]), $(xy[2]));""")
end

"""

"""
function scroll_to!(cm::AbstractComponentModifier, s::AbstractComponent,
     xy::Tuple{Int64, Int64})
     scroll_to!(cm, s, xy)
end

"""
**Session Interface**
### scroll_by!(cm::AbstractComponentModifier, s::AbstractComponent, xy::Tuple{Int64, Int64}) -> _
------------------
Scrolls the Component `s` by xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        scroll_by!(cm, mydiv, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_by!(cm::AbstractComponentModifier, s::AbstractComponent,
    xy::Tuple{Int64, Int64})
    scroll_by!(cm, s, xy)
end

"""

"""
function scroll_to!(cm::AbstractComponentModifier, s::String,
     xy::Tuple{Int64, Int64})
     push!(cm.changes,
     """document.getElementById('$s').scrollTo($(xy[1]), $(xy[2]));""")
end

"""

"""
function scroll_by!(cm::AbstractComponentModifier, s::String,
    xy::Tuple{Int64, Int64})
    push!(cm.changes,
    """document.getElementById('$s').scrollBy($(xy[1]), $(xy[2]))""")
end

"""

"""
function script!(f::Function, c::Connection, cm::AbstractComponentModifier, name::String,
     readonly::Vector{String} = Vector{String}(); time::Integer = 1000, type::String = "Interval")
    ip = getip(c)
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], name => f)
    else
        c[:Session][getip(c)] = Dict(name => f)
    end
    push!(cm.changes, "set$type(function () { sendpage('$name'); }, $time);")
    if length(readonly) > 0
        c[:Session].readonly["$ip$name"] = readonly
    end
end

function script!(f::Function, cm::AbstractComponentModifier, name::String;
    time::Integer = 1000)
    mod = ClientModifier()
    f(mod)
    push!(cm.changes,
    "new Promise(resolve => setTimeout($(funccl(mod, name)), $time));")
end

"""
**Session Interface** 0.3
### next!(f::Function, c::AbstractConnection, comp::Component{<:Any}, cm::ComponentModifier, readonly::Vector{String} = Vector{String}())
------------------
This method can be used to chain animations (or transitions.) We can do this
by calling next on our ComponentModifier, the same could also be done with a
`Component{:script}` (usually made with) `script(::String, properties ...)` or
the `script(::Function, ::String)` function from this module. Note that **transitions**
have not been verified to work with this syntax (yet).
#### example
```

```
"""

"""
**Session Interface** 0.3
### next!(f::Function, name::String, cm::ComponentModifier, a::Animation)
------------------
This method can be used to chain animations (or transitions.) Using the `Animation`
dispatch for this will simply set the next animation on completion of the previous.
#### example
```

```
"""
function next!(cm::ComponentModifier, name::String, a::Animation;
    write::Bool = false)
    anendscr = script("$(a.name)endscr") do cm::ClientModifier
        animate!(cm, name, a, write = write)
        remove!(cm, "$(a.name)endscr")
    end
    cm[name]["onanimationend"] = "$(a.name)endscr()"
    playstate = "running"
    if ~(play)
        playstate = "paused"
    end
    animname = a.name
    time = string(a.length) * "s"
     push!(cm.changes,
     "document.getElementById('$s').style.animation = '$time 1 $animname';")
     push!(cm.changes,
    "document.getElementById('$s').style.animationPlayState = '$playstate';")
    if write
        push!(cm, a)
    end
end

"""
**Session Interface** 0.3
### next!(f::Function, name::String, cm::ComponentModifier, a::Animation)
------------------
This method can be used to chain animations (or transitions.) Using the `Animation`
dispatch for this will simply set the next animation on completion of the previous.
#### example
```

```
"""
function next!(cm::ComponentModifier, s::AbstractComponent, a::Animation;
    write::Bool = false)
    next!(cm, s.name, a, write = write)
end

# emmy was here ! <3

"""
**Session Interface** 0.3
### set_selection!(cm::ComponentModifier, comp::Component{<:Any}, r::UnitRange{Int64})
------------------
Sets the selection to `r`.
#### example
```

```
"""
function set_selection!(cm::ComponentModifier, comp::Component{<:Any}, r::UnitRange{Int64})
    push!(cm.changes, "document.getElementById('$name').setSelectionRange($(r[1]), $(maximum(r)))")
end
