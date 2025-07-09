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

getindex(cc::ComponentModifier, s::AbstractComponent) = htmlcomponent(cc.rootc, s.name)::Component{<:Any}

getindex(cc::ComponentModifier, s::String) = htmlcomponent(cc.rootc, s)::Component{<:Any}

getindex(cc::ComponentModifier, s::AbstractComponent ...) = htmlcomponent(cc.rootc, [comp.name for comp in s])

getindex(cc::ComponentModifier, s::String ...) = htmlcomponent(cc.rootc, [s ...])

in(s::String, cm::ComponentModifier) = contains(cm.rootc, "id=\"$s\"")::Bool

# random component

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
```example

```
"""
function next!(f::Function, c::AbstractConnection, cm::AbstractComponentModifier, s::Any)
    ref::String = gen_ref(5)
    register!(f, c, ref)
    cm[s] = "ontransitionend" => "sendpage(\\'$ref\\');"
    nothing::Nothing
end

# emmy was here ! <3