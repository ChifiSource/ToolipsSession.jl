using Toolips
import Toolips: StyleComponent, get, kill!, animate!, SpoofConnection
import Toolips: style!, Servable, Connection, Modifier, string
import Base: setindex!, getindex, push!, append!, insert!

"""
### ComponentModifier <: AbstractComponentModifier
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
    on(c, mydiv, "click") do cm::AbstractComponentModifier
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
- ComponentModifier(html::String)
- ComponentModifier(html::String, readonly::Vector{String})
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


"""
**Session Interface**
### setindex!(cm::AbstractComponentModifier, p::Pair, s::Component) -> _
------------------
Sets the property from p[1] to p[2] on the served Component s.
#### example
```
on(c, mydiv, "click") do cm::AbstractComponentModifier
    if cm[mydiv]["align"] == "center"
        cm[mydiv] = "align" => "left"
    else
        cm[mydiv] = "align" => "center"
    end
end
```
"""


"""
**Session Interface**
### getindex(cm::AbstractComponentModifier, s::Component) -> ::Component
------------------
Gets the Component s from the ComponentModifier cm.
#### example
```
on(c, mydiv, "click") do cm::AbstractComponentModifier
    mydiv = cm[mydiv]
    mydivalignment = mydiv["align"]
end
```
"""
getindex(cc::ComponentModifier, s::AbstractComponent) = cc.rootc[s.name]

"""
**Session Interface**
### getindex(cm::AbstractComponentModifier, s::String) -> ::Component
------------------
Gets the a Component by name from cm.
#### example
```
on(c, mydiv, "click") do cm::AbstractComponentModifier
    mydiv = cm["mydiv"]
    mydivalignment = mydiv["align"]
end
```
"""
getindex(cc::ComponentModifier, s::String) = cc.rootc[s]

"""
**Session Interface**
### animate!(cm::AbstractComponentModifier, s::Servable, a::Animation; play::Bool) -> _
------------------
Updates the servable s's animation with the animation a.
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
animate!(cm::AbstractComponentModifier, s::AbstractComponent, a::Animation;
     play::Bool = true) = animate!(cm, s.name, a; play = play)

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
**Session Interface**
### pauseanim!(cm::AbstractComponentModifier, s::Servable) -> _
------------------
Pauses the servable's animation.
#### example
```
on(c, s, "click") do cm::AbstractComponentModifier
    pauseanim!(cm, s)
end
```
"""
pauseanim!(cm::AbstractComponentModifier, s::AbstractComponent) = pauseanim!(cm, s.name)

"""
**Session Interface**
### playanim!(cm::AbstractComponentModifier, s::Servable) -> _
------------------
Plays the servable's animation.
#### example
```
on(c, s, "click") do cm::AbstractComponentModifier
    playanim!(cm, s)
end
```
"""
playanim!(cm::AbstractComponentModifier, s::AbstractComponent) = playanim!(cm, s.name)

"""
**Session Interface**
### pauseanim!(cm::AbstractComponentModifier, name::String) -> _
------------------
Pauses a servable's animation by name.
#### example
```
on(c, s, "click") do cm::AbstractComponentModifier
    pauseanim!(cm, s.name)
end
```
"""
function pauseanim!(cm::AbstractComponentModifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'paused';")
end

"""
**Session Interface**
### playanim!(cm::AbstractComponentModifier, name::String) -> _
------------------
Plays a servable's animation by name.
#### example
```
on(c, s, "click") do cm::AbstractComponentModifier
    playanim!(cm, s.name)
end
```
"""
function playanim!(cm::AbstractComponentModifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'running';")
end

set_text!(cm::AbstractComponentModifier, s::Servable, txt::String) = set_text!(cm,
                                                                    s.name, txt)

"""
**Session Interface**
### set_text!(cm::AbstractComponentModifier, s::String, txt::String) -> _
------------------
Sets the inner HTML of a Servable by name
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change text")
    on(c, "mybutton", "click") do cm::AbstractComponentModifier
        set_text!(cm, mybutton, "changed text")
    end
    write!(c, mybutton)
end
```
"""


"""
**Session Interface**
### set_children!(cm::AbstractComponentModifier, s::Servable, v::Vector{Servable}) -> _
------------------
Sets the children of a given component.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        set_children!(cm, mydiv, [mybutton])
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""

"""
**Session Interface**
### append!(cm::AbstractComponentModifier, s::Servable, child::Servable) -> _
------------------
Appends child to the servable s.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    newptext = p("newp", text = "this text is added to our div")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        append!(cm, mydiv, newptext)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function append!(cm::AbstractComponentModifier, s::Servable, child::Servable)
    append!(cm, s.name, child)
end

"""
**Session Interface**
### append!(cm::AbstractComponentModifier, name::String, child::Servable) -> _
------------------
Appends child to the servable s by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    newptext = p("newp", text = "this text is added to our div")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        append!(cm, "mydiv", newptext)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""


"""
**Session Interface**
### insert!(cm::AbstractComponentModifier, into::Servable, i::Int64, child::Servable)
------------------
inserts `child` into `into` at index `i`. Note that this uses Julian indexing
(indexes start at 1).
#### example
```
function home(c::Connection)
    write!(c, h("insertheading", text = "insert"))
    insertbutt = button("insertbutton", text = "insert")
    example_div = div("examp3")
    push!(example_div, h("exampleh1", 5, text = "first"), h("exampleh3", 5, text = "third"))
    on(c, insertbutt, "click") do cm
        ToolipsSession.insert!(cm, example_div 2, h("examph2", 5, text = "second"))
    end
    write!(c, insertbutt)
    write!(c, example_div)
end
```
"""
function insert!(cm::AbstractComponentModifier, into::Servable, i::Int64, child::Servable)
    insert!(cm, into.name, i, child)
end

"""
**Session Interface**
### insert!(cm::AbstractComponentModifier, name::String, i::Int64, child::Servable)
------------------
inserts `child` into `into` at index `i` by name. Note that this uses Julian indexing
(indexes start at 1).
#### example
```
function home(c::Connection)
    write!(c, h("insertheading", text = "insert"))
    insertbutt = button("insertbutton", text = "insert")
    example_div = div("examp3")
    push!(example_div, h("exampleh1", 5, text = "first"), h("exampleh3", 5, text = "third"))
    on(c, insertbutt, "click") do cm
        ToolipsSession.insert!(cm, "examp3" 2, h("examph2", 5, text = "second"))
    end
    write!(c, insertbutt)
    write!(c, example_div)
end
```
"""

"""
**Session Interface**
### get_text(cm::AbstractComponentModifier, s::Component) -> ::String
------------------
Retrieves the text of a given Component.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        current_buttont = get_text(cm, mybutton)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
get_text(cm::AbstractComponentModifier, s::Component) = cm[s][:text]

"""
**Session Interface**
### get_text(cm::AbstractComponentModifier, s::String) -> ::String
------------------
Retrieves the text of a given Component by name
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        current_buttont = get_text(cm, "mybutton")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
get_text(cm::AbstractComponentModifier, s::String) = cm[s][:text]

"""
**Session Interface**
### style!(cm::AbstractComponentModifier, s::Servable, style::Style) -> _
------------------
Changes the style class of s to the style p. Note -- **styles must be already
written to the Connection** prior.
#### example
```
function home(c::Connection)
    mystyle = Style("newclass", "background-color" => "blue")
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        style!(cm, mybutton, mystyle)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::AbstractComponentModifier, s::Servable,  style::Style)
    style!(cm, s.name, style.name)
end

"""
**Session Interface**
### style!(cm::AbstractComponentModifier, name::String, sname::String) -> _
------------------
Changes the style class of a Servable by name to the style p by name.
Note -- **styles must be already written to the Connection** prior.
#### example
```
function home(c::Connection)
    mystyle = Style("newclass", "background-color" => "blue")
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        style!(cm, mybutton, "newclass") #<- name of mystyle
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""


"""
**Session Interface**
### style!(cm::AbstractComponentModifier, s::Servable, p::Pair{String, String}) -> _
------------------
Styles the Servable s with the properties and values in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        style!(cm, mybutton, "background-color" => "lightblue", "color" => "white")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::AbstractComponentModifier, s::Servable, p::Pair{String, String} ...)
    p = [pair for pair in p]
    style!(cm, s, p)
end

"""
**Session Interface**
### style!(cm::AbstractComponentModifier, s::String, p::Pair{String, String}) -> _
------------------
Styles the Servable s by name with the properties and values in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        style!(cm, "mybutton", "background-color" => "lightblue", "color" => "white")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::AbstractComponentModifier, s::String, p::Pair{String, String} ...)
    p = [pair[1] => string(pair[2]) for pair in p]
    style!(cm, s, p)
end

"""
**Session Interface**
### style!(cm::AbstractComponentModifier, s::Servable, p::Pair) -> _
------------------
Styles the Servable s with the property and value in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        style!(cm, mybutton, "background-color" => "lightblue")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
style!(cm::AbstractComponentModifier, s::Servable, p::Pair) = style!(cm, s.name, p)

"""
**Session Interface**
### style!(cm::AbstractComponentModifier, name::String, p::Pair) -> _
------------------
Styles a Servable by name with the property and value in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        style!(cm, "mybutton", "background-color" => "lightblue")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""


"""
**Session Interface**
### style!(cm::AbstractComponentModifier, name::String, p::Vector{Pair{String, String}}) -> _
------------------
Styles a Servable by name with the properties and values in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        style!(cm, mybutton, ["background-color" => "lightblue"])
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::AbstractComponentModifier, s::Servable,
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
**Session Interface**
### free_redirects!(cm::AbstractComponentModifier) -> _
------------------
Removes the "are you sure you wish to leave" box that can be created with
confirm_redirects!
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", redirects = "free")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        if cm[mybutton]["redirects"] == "free"
            confirm_redirects!(cm)
            cm[mybutton] = "redirects" => "confirm"
        else
            free_redirects!(cm)
            cm[mybutton] = "redirects" => "free"
        end
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function free_redirects!(cm::AbstractComponentModifier)
    push!(cm.changes, """window.onbeforeunload = null;""")
end

"""
**Session Interface**
### confirm_redirects!(cm::AbstractComponentModifier) -> _
------------------
Adds an "are you sure you want to leave this page... unsaved changes" pop-up
 when trying to leave the page. Can be undone with `free_redirects!`
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", redirects = "free")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        if cm[mybutton]["redirects"] == "free"
            confirm_redirects!(cm)
            cm[mybutton] = "redirects" => "confirm"
        else
            free_redirects!(cm)
            cm[mybutton] = "redirects" => "free"
        end
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function confirm_redirects!(cm::AbstractComponentModifier)
    push!(cm.changes, """window.onbeforeunload = function() {
    return true;
};""")
end

"""
**Session Interface**
### scroll_to!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64}) -> _
------------------
Sets the page scroll to xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        scroll_to!(cm, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_to!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollTo($(xy[1]), $(xy[2]));""")
end

"""
**Session Interface**
### scroll_by!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64}) -> _
------------------
Scrolls the page by xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        scroll_by!(cm, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_by!(cm::AbstractComponentModifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollBy($(xy[1]), $(xy[2]));""")
end

"""
**Session Interface**
### scroll_to!(cm::AbstractComponentModifier, s::AbstractComponent, xy::Tuple{Int64, Int64}) -> _
------------------
Sets the Component's scroll to xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        scroll_to!(cm, mydiv, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
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
**Session Interface**
### scroll_to!(cm::AbstractComponentModifier, s::String, xy::Tuple{Int64, Int64}) -> _
------------------
Sets the Component's scroll to xy by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        scroll_to!(cm, "mydiv", (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_to!(cm::AbstractComponentModifier, s::String,
     xy::Tuple{Int64, Int64})
     push!(cm.changes,
     """document.getElementById('$s').scrollTo($(xy[1]), $(xy[2]));""")
end

"""
**Session Interface**
### scroll_by!(cm::AbstractComponentModifier, s::String, xy::Tuple{Int64, Int64}) -> _
------------------
Scrolls the Component `s` by xy by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        scroll_by!(cm, "mydiv", (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_by!(cm::AbstractComponentModifier, s::String,
    xy::Tuple{Int64, Int64})
    push!(cm.changes,
    """document.getElementById('$s').scrollBy($(xy[1]), $(xy[2]))""")
end

"""
**Session Interface** 0.3
### observe!(f::Function, c::Connection, cm::AbstractComponentModifier, name::String, time::Integer = 1000) -> _
------------------
Creates a new event to happen in `time`. This is useful if you want to have a delay before
some initial session call
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        scroll_by!(cm, "mydiv", (0, 15))
        observe!(c, cm, "myobs", 1000) do cm::ComponentModifier
            scroll_by!(cm, "mydiv", (0, -15)) # < scrolls  the div back up after 1 second.
        end
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
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
### next!(f::Function, name::String, cm::ComponentModifier, a::Animation)
------------------
This method can be used to chain animations (or transitions.) Using the `Animation`
dispatch for this will simply set the next animation on completion of the previous.
#### example
```

```
"""
function update!(cm::ComponentModifier, ppane::AbstractComponent, plot::Any)
    io::IOBuffer = IOBuffer();
    show(io, "text/html", plot)
    data::String = String(io.data)
    data = replace(data,
     """<?xml version=\"1.0\" encoding=\"utf-8\"?>\n""" => "")
    set_text!(cm, ppane.name, data)
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
function set_selection!(cm::ComponentModifier, comp::Component{<:Any}, r::UnitRange{Int64})
    push!(cm.changes, "document.getElementById('$name').setSelectionRange($(r[1]), $(maximum(r)))")
end

"""
**Session Interface** 0.3
### set_selection!(cm::ComponentModifier, comp::Component{<:Any}, r::UnitRange{Int64})
------------------
Focuses on `comp`.
#### example
```

```
"""
focus!(cm::ComponentModifier, comp::Component{<:Any}) = focus!(cm, comp.name)

"""
**Session Interface** 0.3
### focus!(cm::ComponentModifier, name::String, r::UnitRange{Int64})
------------------
Focuses on Component named `name`.
#### example
```

```
"""
function focus!(cm::ComponentModifier, name::String)
    push!(cm.changes, "document.getElementById('$name').focus();")
end

"""
**Session Interface** 0.3
### focus!(cm::ComponentModifier, name::String, r::UnitRange{Int64})
------------------
Focuses on Component named `name`.
#### example
```

```
"""
function blur!(cm::ComponentModifier, name::String)
    push!(cm.changes, "document.getElementById('$name').blur();")
end

blur!(cm::ComponentModifier, comp::Component{<:Any}) = blur!(cm, comp.name)