"""
```julia
mutable struct ComponentModifier <: ToolipsServables.AbstractComponentModifier
```
- `rootc**::String**`
- `changes**::Vector{String}**`

The `ComponentModifier` is used in callback bindings to register outgoing changes 
to the components on a client's web-page. A `ComponentModifier` can be indexed with a `String` 
to yield that `Component`, which modified properties may then be read from the page with. We can also check
if elements are on the page by using `in` with a conditional.

- See also: `Session`, `on`, `ToolipsSession.bind`, `Toolips`, `ToolipsSession`
```julia
ComponentModifier(html::String)
```
---
A `ComponentModifier` is typically going to be used in a callback binding 
created with `on` or `ToolipsSession.bind`.
```example

```
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
"""
```julia
button_select(c::AbstractConnection, name::String, buttons::Vector{<:Servable}, 
unselected::Vector{Pair{String, String}} = ["background-color" => "blue",
     "border-width" => 0px],
    selected::Vector{Pair{String, String}} = ["background-color" => "green",
     "border-width" => 2px]))
```
A unique `Component` provided by `ToolipsSession` for building a selection system with multiple 
buttons. Will style unselected buttons with `unselected`, and as the user changes the button the styles 
will change along with the `value` property.
---
```example

```
"""
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
```julia
set_selection!(cm::ComponentModifier, comp::Any, r::UnitRange{Int64}) -> ::Nothing
```
Sets the focus selection range inside of the element `comp` (provided as the 
component's `name` (`String`), or the `Component` itself.)
---
```example

```
"""
function set_selection!(cm::ComponentModifier, comp::Any, r::UnitRange{Int64})
    if comp <: Toolips.AbstractComponent
        comp = comp.name
    end
    push!(cm.changes, "document.getElementById('$comp').setSelectionRange($(r[1]), $(maximum(r)))")
end

"""
```julia
pauseanim!(cm::AbstractComponentModifier, name::Any) -> ::Nothing
```
Pauses the animation on the `Component` or `Component` `name`.
---
```example

```
"""
function pauseanim!(cm::AbstractComponentModifier, name::Any)
    if name <: Toolips.AbstractComponent
        name = name.name
    end
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'paused';")
end

"""
```julia
playanim!(cm::AbstractComponentModifier, name::Any) -> ::Nothing
```
Pauses the animation on the `Component` or `Component` `name`.
---
```example

```
"""
function playanim!(cm::AbstractComponentModifier, comp::Any)
    if comp <: Toolips.AbstractComponent
        comp = comp.name
    end
    push!(cm.changes,
    "document.getElementById('$comp').style.animationPlayState = 'running';")
end

"""
```julia
free_redirects!(cm::AbstractComponentModifier) -> ::Nothing
```
Frees a `confirm_redirects!` " Page may have unsaved changes" call. After calling 
`confirm_redirects!`, call this to remove that confirmation.
---
```example

```
"""
function free_redirects!(cm::AbstractComponentModifier)
    push!(cm.changes, """window.onbeforeunload = null;""")
end

"""
```julia
confrim_redirects!(cm::AbstractComponentModifier) -> ::Nothing
```
Requires a user to confirm a redirects, providing a " Page may have unsaved changes" 
alert when the client tries to leave the page. This can be undone with `free_redirects!`
---
```example

```
"""
function confirm_redirects!(cm::AbstractComponentModifier)
    push!(cm.changes, """window.onbeforeunload = function() {
    return true;
};""")
end

"""
```julia
scroll_to(cm::AbstractComponentModifier, ...)
```

---
```example

```
"""
function scroll_to!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollTo($(xy[1]), $(xy[2]));""")
end

function scroll_to!(cm::AbstractComponentModifier, s::String,
    xy::Tuple{Int64, Int64})
    push!(cm.changes,
    """document.getElementById('$s').scrollTo($(xy[1]), $(xy[2]));""")
end

"""
```julia
scroll_to(cm::AbstractComponentModifier, ...)
```

---
```example

```
"""
function scroll_by!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollBy($(xy[1]), $(xy[2]));""")
end

function scroll_by!(cm::AbstractComponentModifier, s::String,
    xy::Tuple{Int64, Int64})
    push!(cm.changes,
    """document.getElementById('$s').scrollBy($(xy[1]), $(xy[2]))""")
end

"""
```julia
next!(f::Function, ...) -> ::Nothing
```
Performs `f` in a second callback after the first. This callback can be called in a certain period of time, 
in `ms` with `next!(::Function, ::AbstractComponentModifier, ::Integer)` or on the transition end of a given 
`Component` with `next!(::Function, ::AbstractConnection, ::AbstractComponentModifier, ::Any)`
```julia
next!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, s::Any)
next!(f::Function, cm::AbstractComponentModifier, time::Integer = 1000)
```
---
```example

```
"""
function next!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, s::Any)
    ref::String = gen_ref(5)
    register!(f, c, ref)
    cm[s] = "ontransitionend" => "sendpage(\\'$ref\\');"
    nothing::Nothing
end

function next!(f::Function, cm::AbstractComponentModifier, time::Integer = 1000)
    mod = ClientModifier()
    f(mod)
    push!(cm.changes,
    "new Promise(resolve => setTimeout($(Components.funccl(mod, gen_ref(5))), $time));")
end

# emmy was here ! <3