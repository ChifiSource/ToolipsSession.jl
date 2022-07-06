using Toolips
import Toolips: StyleComponent, get, kill!, animate!, SpoofConnection
import Toolips: style!, Servable, Connection
import Base: setindex!, getindex, push!, append!

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
    tagpos::Vector{UnitRange{Int64}} = [f[1]:e[1] for (f, e) in zip(findall("<", s), findall(">", s))]
    comps = Vector{Servable}()
    for tag::UnitRange in tagpos
       if contains(s[tag], "/") || ~(contains(s[tag], " id="))
            continue
        end
        tagr::UnitRange = findnext(" ", s, tag[1])
        nametag::String = s[minimum(tagr):maximum(tagr)]
        textr::UnitRange = maximum(tag) + 1:findnext("<", s, maximum(tag))[1] - 1
        tagtext::String = s[textr]
        props::String = replace(s[maximum(tagr):maximum(tag) - 1], " " => "")
        propvec::Vector{SubString} = split(props, "=")
        properties::Dict = Dict{Any, Any}([propvec[i - 1] => propvec[i] for i in range(2, length(propvec), step = 2)])
        name::String = string(properties["id"])
        println(name)
        if name == " "
            continue
        end
        properties["text"] = tagtext
        comp::Component = Component(nametag, name, properties)
        delete!(comp.properties, "id")
        push!(comps, comp)
    end
    return(comps)::Vector{Servable}
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
    rootc::Vector{Servable}
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

"""
**Session Interface**
### setindex!(cm::ComponentModifier, p::Pair, s::String) -> _
------------------
Sets the property from p[1] to p[2] on the served with name s.
#### example
```
on(c, mydiv, "click") do cm::ComponentModifier
    if cm["mydiv"]["align"] == "center"
        cm["mydiv"] = "align" => "left"
    else
        cm["mydiv"] = "align" => "center"
    end
end
```
"""
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
**Session Interface**
### animate!(cm::ComponentModifier, s::Servable, a::Animation; play::Bool) -> _
------------------
Updates the servable s's animation with the animation a.
#### example
```
s = divider("mydiv")
a = Animation("fade")
a[:from] = "opacity" => "0%"
a[:to] = "opacity" => "100%"
# where c is the Connection.
on(c, s, "click") do cm::ComponentModifier
    animate!(cm, s, a)
end
```
"""
animate!(cm::ComponentModifier, s::Servable, a::Animation;
     play::Bool = true) = animate!(cm, s.name, a; play = play)

"""
**Session Interface**
### animate!(cm::ComponentModifier, s::String, a::Animation; play::Bool) -> _
------------------
Updates the servable with name s's animation with the animation a.
#### example
```
s = divider("mydiv")
a = Animation("fade")
a[:from] = "opacity" => "0%"
a[:to] = "opacity" => "100%"
# where c is the Connection.
on(c, s, "click") do cm::ComponentModifier
    animate!(cm, s, a)
end
     ```
     """
function animate!(cm::ComponentModifier, s::String, a::Animation;
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
### pauseanim!(cm::ComponentModifier, s::Servable) -> _
------------------
Pauses the servable's animation.
#### example
```
on(c, s, "click") do cm::ComponentModifier
    pauseanim!(cm, s)
end
```
"""
pauseanim!(cm::ComponentModifier, s::Servable) = pauseanim!(cm, s.name)

"""
**Session Interface**
### playanim!(cm::ComponentModifier, s::Servable) -> _
------------------
Plays the servable's animation.
#### example
```
on(c, s, "click") do cm::ComponentModifier
    playanim!(cm, s)
end
```
"""
playanim!(cm::ComponentModifier, s::Servable) = playanim!(cm, s.name)

"""
**Session Interface**
### pauseanim!(cm::ComponentModifier, name::String) -> _
------------------
Pauses a servable's animation by name.
#### example
```
on(c, s, "click") do cm::ComponentModifier
    pauseanim!(cm, s.name)
end
```
"""
function pauseanim!(cm::ComponentModifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'paused';")
end

"""
**Session Interface**
### playanim!(cm::ComponentModifier, name::String) -> _
------------------
Plays a servable's animation by name.
#### example
```
on(c, s, "click") do cm::ComponentModifier
    playanim!(cm, s.name)
end
```
"""
function playanim!(cm::ComponentModifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'running';")
end

"""
**Session Interface**
### alert!(cm::ComponentModifier, s::String) -> _
------------------
Sends an alert to the current session.
#### example
```
on(c, s, "click") do cm::ComponentModifier
    alert!(cm, "oh no!")
end
```
"""
alert!(cm::ComponentModifier, s::AbstractString) = push!(cm.changes,
        "alert('$s');")

"""
**Session Interface**
### redirect!(cm::ComponentModifier, url::AbstractString, delay::Int64 = 0) -> _
------------------
Redirects the session to **url**. Can be given delay with **delay**.
#### example
```

```
"""
function redirect!(cm::ComponentModifier, url::AbstractString, delay::Int64 = 0)
    push!(cm.changes, """
    setTimeout(function () {
      window.location.href = "$url";
   }, $delay);
   """)
end

"""
**Session Interface**
### modify!(cm::ComponentModifier, s::Servable, p::Pair ...) -> _
------------------
Modifies the key properties of p[1] to the value of p[2] on s.
#### example
```

```
"""
function modify!(cm::ComponentModifier, s::Servable, p::Pair ...)
    p = [pair for pair in p]
    modify!(cm, s, p)
end

"""
**Session Interface**
### modify!(cm::ComponentModifier, s::Servable, p::Vector{Pair{String, String}}) -> _
------------------
Modifies the key properties of i[1] => i[2] for i in p on s.
#### example
```

```
"""
function modify!(cm::ComponentModifier, s::Servable,
    p::Vector{Pair{String, String}})
    [modify!(cm, s, z) for z in p]
end

"""
**Session Interface**
### modify!(cm::ComponentModifier, s::Servable, p::Pair) -> _
------------------
Modifies the key property p[1] to p[2] on s
#### example
```

```
"""
modify!(cm::ComponentModifier, s::Servable, p::Pair) = modify!(cm, s.name, p)

"""
**Session Interface**
### modify!(cm::ComponentModifier, s::Servable, p::Pair) -> _
------------------
Modifies the key property p[1] to p[2] on s
#### example
```

```
"""
function modify!(cm::ComponentModifier, s::String, p::Pair)
    key, val = p[1], p[2]
    push!(cm.changes,
    "document.getElementById('$s').setAttribute('$key','$val');")
end


"""
**Session Interface**
### move!(cm::ComponentModifier, p::Pair{Servable, Servable}) -> _
------------------
Moves the servable p[2] to be a child of p[1]
#### example
```

```
"""
move!(cm::ComponentModifier, p::Pair{Servable, Servable}) = move!(cm,
                                                        p[1].name => p[2].name)

"""
**Session Interface**
### move!(cm::ComponentModifier, p::Pair{String, String}) -> _
------------------
Moves the servable p[2] to be a child of p[1] by name.
#### example
```

```
"""
function move!(cm::ComponentModifier, p::Pair{String, String})
    firstname = p[1]
    secondname = p[2]
    push!(cm.changes, "
    document.getElementById('$firstname').appendChild(
    document.getElementById('$secondname')
  );
  ")
end

"""
**Session Interface**
### remove!(cm::ComponentModifier, s::Servable) -> _
------------------
Removes the servable s.
#### example
```

```
"""
remove!(cm::ComponentModifier, s::Servable) = remove!(cm, s.name)

"""
**Session Interface**
### remove!(cm::ComponentModifier, s::String) -> _
------------------
Removes the servable s by name.
#### example
```

```
"""
function remove!(cm::ComponentModifier, s::String)
    push!(cm.changes, "document.getElementById('$s').remove();")
end

"""
**Session Interface**
### set_text!(cm::ComponentModifier, s::Servable, txt::String) -> _
------------------
Sets the inner HTML of a Servable.
#### example
```

```
"""
set_text!(cm::ComponentModifier, s::Servable, txt::String) = set_text!(cm,
                                                                    s.name, txt)

"""
**Session Interface**
### set_text!(cm::ComponentModifier, s::String, txt::String) -> _
------------------
Sets the inner HTML of a Servable by name
#### example
```

```
"""
function set_text!(c::ComponentModifier, s::String, txt::String)
    push!(c.changes, "document.getElementById('$s').innerHTML = `$txt`;")
end

"""
**Session Interface**
### set_children!(cm::ComponentModifier, s::Servable, v::Vector{Servable}) -> _
------------------
Sets the children of a given component.
#### example
```

```
"""
function set_children!(cm::ComponentModifier, s::Servable, v::Vector{Servable})
    set_children!(cm, s.name, v)
end

"""
**Session Interface**
### set_children!(cm::ComponentModifier, s::String, v::Vector{Servable}) -> _
------------------
Sets the children of a given component by name.
#### example
```

```
"""
function set_children!(cm::ComponentModifier, s::String, v::Vector{Servable})
    spoofconn::SpoofConnection = SpoofConnection()
    write!(spoofconn, v)
    txt::String = spoofconn.http.text
    set_text!(cm, s, txt)
end

"""
**Session Interface**
### append!(cm::ComponentModifier, s::Servable, child::Servable) -> _
------------------
Appends child to the servable s.
#### example
```

```
"""
function append!(cm::ComponentModifier, s::Servable, child::Servable)
    append!(cm, s.name, child)
end

"""
**Session Interface**
### append!(cm::ComponentModifier, name::String, child::Servable) -> _
------------------
Appends child to the servable s by name.
#### example
```

```
"""
function append!(cm::ComponentModifier, name::String, child::Servable)
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
**Session Interface**
### get_text(cm::ComponentModifier, s::Component) -> ::String
------------------
Retrieves the text of a given Component.
#### example
```

```
"""
get_text(cm::ComponentModifier, s::Component) = cm[s][:text]

"""
**Session Interface**
### get_text(cm::ComponentModifier, s::String) -> ::String
------------------
Retrieves the text of a given Component by name
#### example
```

```
"""
get_text(cm::ComponentModifier, s::String) = cm[s][:text]

"""
**Session Interface**
### style!(cm::ComponentModifier, s::Servable, style::Style) -> _
------------------
Changes the style class of s to the style p. Note -- **styles must be already
written to the Connection** prior.
#### example
```

```
"""
function style!(cm::ComponentModifier, s::Servable,  style::Style)
    style!(cm, s.name, style.name)
end

"""
**Session Interface**
### style!(cm::ComponentModifier, name::String, sname::String) -> _
------------------
Changes the style class of a Servable by name to the style p by name.
Note -- **styles must be already written to the Connection** prior.
#### example
```

```
"""
function style!(cc::ComponentModifier, name::String,  sname::String)
    push!(cc.changes, "document.getElementById('$name').className = '$sname';")
end

"""
**Session Interface**
### style!(cm::ComponentModifier, s::Servable, p::Pair{String, String}) -> _
------------------
Styles the Servable s with the properties and values in p.
#### example
```

```
"""
function style!(cm::ComponentModifier, s::Servable, p::Pair{String, String} ...)
    p = [pair for pair in p]
    style!(cm, s, p)
end

"""
**Session Interface**
### style!(cm::ComponentModifier, s::Servable, p::Pair) -> _
------------------
Styles the Servable s with the properties and values in p.
#### example
```

```
"""
style!(cm::ComponentModifier, s::Servable, p::Pair) = style!(cm, s.name, p)

"""
**Session Interface**
### style!(cm::ComponentModifier, name::String, p::Pair) -> _
------------------
Styles a Servable by name with the properties and values in p.
#### example
```

```
"""
function style!(cm::ComponentModifier, name::String, p::Pair)
    key, value = p[1], p[2]
    push!(cm.changes,
        "document.getElementById('$name').style['$key'] = `$value`;")
end

"""
**Session Interface**
### style!(cm::ComponentModifier, name::String, p::Vector{Pair{String, String}}) -> _
------------------
Styles a Servable by name with the properties and values in p.
#### example
```

```
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
**Session Interface**
### free_redirects!(cm::ComponentModifier) -> _
------------------
Removes the "are you sure you wish to leave" box that can be created with
confirm_redirects!
#### example
```

```
"""
function free_redirects!(cm::ComponentModifier)
    push!(cm.changes, """window.onbeforeunload = null;""")
end

"""
**Session Interface**
### free_redirects!(cm::ComponentModifier) -> _
------------------
Adds an "are you sure you want to leave this page... unsaved changes" pop-up
 when trying to leave the page. Can be undone with free_redirects!
#### example
```

```
"""
function confirm_redirects!(cm::ComponentModifier)
    push!(cm.changes, """window.onbeforeunload = function() {
    return true;
};""")
end
