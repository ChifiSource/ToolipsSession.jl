"""

"""
mutable struct ComponentModifier <: AbstractComponentModifier
    rootc::String
    changes::Vector{String}
    function ComponentModifier(html::String)
        changes::Vector{String} = Vector{String}()
        new(html, changes)::ComponentModifier
    end
end

string(cm::ComponentModifier) = join(cm.changes)::String

getindex(cc::ComponentModifier, s::AbstractComponent) = htmlcomponent(cc.rootc, [s.name])[1]

getindex(cc::ComponentModifier, s::String) = htmlcomponent(cc.rootc, [s])[1]

getindex(cc::ComponentModifier, s::AbstractComponent ...) = htmlcomponent(cc.rootc, [comp.name for comp in s])[1]

getindex(cc::ComponentModifier, s::String ...) = htmlcomponent(cc.rootc, [s ...])[1]

in(s::String, cm::ComponentModifier) = contains(cm.rootc, s)::Bool

# random component
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
function next!(cm::ComponentModifier, name::String, a::Toolips.ToolipsServables.KeyFrames;
    write::Bool = false)
    anendscr = script("$(a.name)endscr") do cm::ClientModifier
        animate!(cm, name, a, write = write)
        remove!(cm, "$(a.name)endscr")
    end
    cm[name] = "onanimationend" => "$(a.name)"
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
function next!(cm::ComponentModifier, s::AbstractComponent, a::Toolips.ToolipsServables.KeyFrames;
    write::Bool = false)
    next!(cm, s.name, a, write = write)
end

# emmy was here ! <3
function next!(f::Function, c::AbstractConnection, cm::ComponentModifier, s::Any)
    ref::String = gen_ref(5)
    register!(f, c, ref)
    cm[s] = "ontransitionend" => "sendpage(\\'$ref\\');"
    nothing::Nothing
end

"""
**Session Interface** 0.3
### set_selection!(cm::ComponentModifier, comp::Component{<:Any}, r::UnitRange{Int64})
------------------
Sets the selection to `r`.
#### example
```

```
"""
function set_selection!(cm::ComponentModifier, comp::AbstractComponent, r::UnitRange{Int64})
    push!(cm.changes, "document.getElementById('$name').setSelectionRange($(r[1]), $(maximum(r)))")
end
