using Toolips
import Toolips: StyleComponent, get, kill!, animate!, SpoofConnection
import Toolips: style!, Servable, Connection
import Base: setindex!, getindex, push!, append!

abstract type Modifier <: Servable end
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
function htmlcomponent(s::String, readonly::Vector{String} = Vector{String}())
    tagpos::Vector{UnitRange{Int64}} = [f[1]:e[1] for (f, e) in zip(findall("<", s), findall(">", s))]
    comps::Dict{String, Component} = Dict{String, Component}()
    for tag::UnitRange in tagpos
       if contains(s[tag], "/") || ~(contains(s[tag], " id="))
            continue
        end
        tagr::UnitRange = findnext(" ", s, tag[1])
        nametag::String = s[minimum(tag) + 1:maximum(tagr) - 1]
        if contains(s[tag], "id=")
            namestart::Int64 = findnext("id=", s, tag[1])[2] + 1
            nameranger::UnitRange = namestart + 1:(findnext(" ", s, namestart[1])[1] - 1)
            if length(readonly) > 0 && ~(replace(s[nameranger], "\"" => "") in readonly)
                continue
            end
        end
        tagtext::String = ""
        try
            textr::UnitRange = maximum(tag) + 1:minimum(findnext("</$nametag", s, tag[1])[1]) - 1
            tagtext = s[textr]
            tagtext = replace(tagtext, "<br>" => "\n")
            tagtext = replace(tagtext, "&nbsp" => " ")
            tagtext = replace(tagtext, "&ensp" => "  ")
            tagtext = replace(tagtext, "&emsp" => "    ")
        catch
            tagtext = ""
        end
        propvec::Vector{SubString} = split(s[maximum(tagr) + 1:maximum(tag) - 1], " ")
        properties::Dict{Any, Any} = Dict{Any, Any}()
        [begin
            ppair::Vector{SubString} = split(segment, "=")
            if length(ppair) > 1
                push!(properties, string(ppair[1]) => replace(string(ppair[2]), "\"" => ""))
            end
        end for segment in propvec]
        name::String = properties["id"]

        delete!(properties, "id")
        push!(properties, "text" => tagtext)
        push!(comps, name => Component(name, string(nametag), properties))
    end
    return(comps)::Dict{String, Component}
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
    on(c, mydiv, "click") do cm::Modifier
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
mutable struct ComponentModifier <: Modifier
    rootc::Dict{String, AbstractComponent}
    f::Function
    changes::Vector{String}
    function ComponentModifier(html::String)
        rootc::Dict{String, AbstractComponent} = htmlcomponent(html)
        changes::Vector{String} = Vector{String}()
        f(c::Connection) = begin
            write!(c, join(changes))
        end
        new(rootc, f, changes)::ComponentModifier
    end
    function ComponentModifier(html::String, readonly::Vector{String})
        rootc::Dict{String, AbstractComponent} = htmlcomponent(html, readonly)
        changes::Vector{String} = Vector{String}()
        f(c::Connection) = begin
            write!(c, join(changes))
        end
        new(rootc, f, changes)::ComponentModifier
    end
end

"""
**Session Interface**
### setindex!(cm::Modifier, p::Pair, s::Component) -> _
------------------
Sets the property from p[1] to p[2] on the served Component s.
#### example
```
on(c, mydiv, "click") do cm::Modifier
    if cm[mydiv]["align"] == "center"
        cm[mydiv] = "align" => "left"
    else
        cm[mydiv] = "align" => "center"
    end
end
```
"""
setindex!(cm::Modifier, p::Pair, s::AbstractComponent) = modify!(cm, s, p)

"""
**Session Interface**
### setindex!(cm::Modifier, p::Pair, s::String) -> _
------------------
Sets the property from p[1] to p[2] on the served with name s.
#### example
```
on(c, mydiv, "click") do cm::Modifier
    if cm["mydiv"]["align"] == "center"
        cm["mydiv"] = "align" => "left"
    else
        cm["mydiv"] = "align" => "center"
    end
end
```
"""
setindex!(cm::Modifier, p::Pair, s::String) = modify!(cm, s, p)

"""
**Session Interface**
### getindex(cm::Modifier, s::Component) -> ::Component
------------------
Gets the Component s from the ComponentModifier cm.
#### example
```
on(c, mydiv, "click") do cm::Modifier
    mydiv = cm[mydiv]
    mydivalignment = mydiv["align"]
end
```
"""
getindex(cc::Modifier, s::AbstractComponent) = cc.rootc[s.name]

"""
**Session Interface**
### getindex(cm::Modifier, s::String) -> ::Component
------------------
Gets the a Component by name from cm.
#### example
```
on(c, mydiv, "click") do cm::Modifier
    mydiv = cm["mydiv"]
    mydivalignment = mydiv["align"]
end
```
"""
getindex(cc::Modifier, s::String) = cc.rootc[s]

"""
**Session Interface**
### animate!(cm::Modifier, s::Servable, a::Animation; play::Bool) -> _
------------------
Updates the servable s's animation with the animation a.
#### example
```
s = divider("mydiv")
a = Animation("fade")
a[:from] = "opacity" => "0%"
a[:to] = "opacity" => "100%"
# where c is the Connection.
on(c, s, "click") do cm::Modifier
    animate!(cm, s, a)
end
```
"""
animate!(cm::Modifier, s::AbstractComponent, a::Animation;
     play::Bool = true) = animate!(cm, s.name, a; play = play)

"""
**Session Interface**
### animate!(cm::Modifier, s::String, a::Animation; play::Bool) -> _
------------------
Updates the servable with name s's animation with the animation a.
#### example
```
s = divider("mydiv")
a = Animation("fade")
a[:from] = "opacity" => "0%"
a[:to] = "opacity" => "100%"
# where c is the Connection.
on(c, s, "click") do cm::Modifier
    animate!(cm, s, a)
end
     ```
     """
function animate!(cm::Modifier, s::String, a::Animation;
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
### pauseanim!(cm::Modifier, s::Servable) -> _
------------------
Pauses the servable's animation.
#### example
```
on(c, s, "click") do cm::Modifier
    pauseanim!(cm, s)
end
```
"""
pauseanim!(cm::Modifier, s::AbstractComponent) = pauseanim!(cm, s.name)

"""
**Session Interface**
### playanim!(cm::Modifier, s::Servable) -> _
------------------
Plays the servable's animation.
#### example
```
on(c, s, "click") do cm::Modifier
    playanim!(cm, s)
end
```
"""
playanim!(cm::Modifier, s::AbstractComponent) = playanim!(cm, s.name)

"""
**Session Interface**
### pauseanim!(cm::Modifier, name::String) -> _
------------------
Pauses a servable's animation by name.
#### example
```
on(c, s, "click") do cm::Modifier
    pauseanim!(cm, s.name)
end
```
"""
function pauseanim!(cm::Modifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'paused';")
end

"""
**Session Interface**
### playanim!(cm::Modifier, name::String) -> _
------------------
Plays a servable's animation by name.
#### example
```
on(c, s, "click") do cm::Modifier
    playanim!(cm, s.name)
end
```
"""
function playanim!(cm::Modifier, name::String)
    push!(cm.changes,
    "document.getElementById('$name').style.animationPlayState = 'running';")
end

"""
**Session Interface**
### alert!(cm::Modifier, s::String) -> _
------------------
Sends an alert to the current session.
#### example
```
on(c, s, "click") do cm::Modifier
    alert!(cm, "oh no!")
end
```
"""
alert!(cm::Modifier, s::AbstractString) = push!(cm.changes,
        "alert('$s');")

"""
**Session Interface**
### redirect!(cm::Modifier, url::AbstractString, delay::Int64 = 0) -> _
------------------
Redirects the session to **url**. Can be given delay with **delay**.
#### example
```
url = "https://toolips.app"
on(c, s, "click") do cm::Modifier
    redirect!(cm, url, 3) # waits three seconds, then navigates to toolips.app
end
```
"""
function redirect!(cm::Modifier, url::AbstractString, delay::Int64 = 0)
    push!(cm.changes, """
    setTimeout(function () {
      window.location.href = "$url";
   }, $delay);
   """)
end

"""
**Session Interface**
### modify!(cm::Modifier, s::Servable, p::Pair ...) -> _
------------------
Modifies the key properties of p[1] to the value of p[2] on s. This can also be
done with setindex!
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    on(c, mybutton, "click") do cm::Modifier
        cm[mybutton] = "align" = "center"
    end
    write!(c, mybutton)
end
```
"""
function modify!(cm::Modifier, s::AbstractComponent, p::Pair ...)
    p = [pair for pair in p]
    modify!(cm, s, p)
end

"""
**Session Interface**
### modify!(cm::Modifier, s::Servable, p::Vector{Pair{String, String}}) -> _
------------------
Modifies the key properties of i[1] => i[2] for i in p on s.
"""
function modify!(cm::Modifier, s::AbstractComponent,
    p::Vector{Pair{String, String}})
    [modify!(cm, s, z) for z in p]
end

"""
**Session Interface**
### modify!(cm::Modifier, s::Servable, p::Pair) -> _
------------------
Modifies the key property p[1] to p[2] on s
"""
modify!(cm::Modifier, s::AbstractComponent, p::Pair) = modify!(cm, s.name, p)

"""
**Session Interface**
### modify!(cm::Modifier, s::Servable, p::Pair) -> _
------------------
Modifies the key property p[1] to p[2] on s
"""
function modify!(cm::Modifier, s::String, p::Pair)
    key, val = p[1], p[2]
    push!(cm.changes,
    "document.getElementById('$s').setAttribute('$key','$val');")
end


"""
**Session Interface**
### move!(cm::Modifier, p::Pair{Servable, Servable}) -> _
------------------
Moves the servable p[2] to be a child of p[1].
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        move!(cm, mybutton => mydiv)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
move!(cm::Modifier, p::Pair{Servable, Servable}) = move!(cm,
                                                        p[1].name => p[2].name)

"""
**Session Interface**
### move!(cm::Modifier, p::Pair{String, String}) -> _
------------------
Moves the servable p[2] to be a child of p[1] by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        move!(cm, "mybutton" => "mydiv")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function move!(cm::Modifier, p::Pair{String, String})
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
### remove!(cm::Modifier, s::Servable) -> _
------------------
Removes the servable s.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    on(c, mybutton, "click") do cm::Modifier
        remove!(cm, mybutton)
    end
    write!(c, mybutton)
end
```
"""
remove!(cm::Modifier, s::Servable) = remove!(cm, s.name)

"""
**Session Interface**
### remove!(cm::Modifier, s::String) -> _
------------------
Removes the servable s by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    on(c, mybutton, "click") do cm::Modifier
        remove!(cm, "mybutton")
    end
    write!(c, mybutton)
end
```
"""
function remove!(cm::Modifier, s::String)
    push!(cm.changes, "document.getElementById('$s').remove();")
end

"""
**Session Interface**
### set_text!(cm::Modifier, s::Servable, txt::String) -> _
------------------
Sets the inner HTML of a Servable.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change text")
    on(c, mybutton, "click") do cm::Modifier
        set_text!(cm, mybutton, "changed text")
    end
    write!(c, mybutton)
end
```
"""
set_text!(cm::Modifier, s::Servable, txt::String) = set_text!(cm,
                                                                    s.name, txt)

"""
**Session Interface**
### set_text!(cm::Modifier, s::String, txt::String) -> _
------------------
Sets the inner HTML of a Servable by name
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change text")
    on(c, "mybutton", "click") do cm::Modifier
        set_text!(cm, mybutton, "changed text")
    end
    write!(c, mybutton)
end
```
"""
function set_text!(c::Modifier, s::String, txt::String)
    push!(c.changes, "document.getElementById('$s').innerHTML = `$txt`;")
end

"""
**Session Interface**
### set_children!(cm::Modifier, s::Servable, v::Vector{Servable}) -> _
------------------
Sets the children of a given component.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        set_children!(cm, mydiv, [mybutton])
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function set_children!(cm::Modifier, s::Servable, v::Vector{Servable})
    set_children!(cm, s.name, v)
end

"""
**Session Interface**
### set_children!(cm::Modifier, s::String, v::Vector{Servable}) -> _
------------------
Sets the children of a given component by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    newptext = p("newp", text = "this text is added to our div")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        set_children!(cm, "mydiv", [newptext])
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function set_children!(cm::Modifier, s::String, v::Vector{Servable})
    spoofconn::SpoofConnection = SpoofConnection()
    write!(spoofconn, v)
    txt::String = spoofconn.http.text
    set_text!(cm, s, txt)
end

"""
**Session Interface**
### append!(cm::Modifier, s::Servable, child::Servable) -> _
------------------
Appends child to the servable s.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    newptext = p("newp", text = "this text is added to our div")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        append!(cm, mydiv, newptext)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function append!(cm::Modifier, s::Servable, child::Servable)
    append!(cm, s.name, child)
end

"""
**Session Interface**
### append!(cm::Modifier, name::String, child::Servable) -> _
------------------
Appends child to the servable s by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    newptext = p("newp", text = "this text is added to our div")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        append!(cm, "mydiv", newptext)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function append!(cm::Modifier, name::String, child::Servable)
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
### get_text(cm::Modifier, s::Component) -> ::String
------------------
Retrieves the text of a given Component.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        current_buttont = get_text(cm, mybutton)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
get_text(cm::Modifier, s::Component) = cm[s][:text]

"""
**Session Interface**
### get_text(cm::Modifier, s::String) -> ::String
------------------
Retrieves the text of a given Component by name
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        current_buttont = get_text(cm, "mybutton")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
get_text(cm::Modifier, s::String) = cm[s][:text]

"""
**Session Interface**
### style!(cm::Modifier, s::Servable, style::Style) -> _
------------------
Changes the style class of s to the style p. Note -- **styles must be already
written to the Connection** prior.
#### example
```
function home(c::Connection)
    mystyle = Style("newclass", "background-color" => "blue")
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, mybutton, mystyle)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::Modifier, s::Servable,  style::Style)
    style!(cm, s.name, style.name)
end

"""
**Session Interface**
### style!(cm::Modifier, name::String, sname::String) -> _
------------------
Changes the style class of a Servable by name to the style p by name.
Note -- **styles must be already written to the Connection** prior.
#### example
```
function home(c::Connection)
    mystyle = Style("newclass", "background-color" => "blue")
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, mybutton, "newclass") #<- name of mystyle
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cc::Modifier, name::String,  sname::String)
    push!(cc.changes, "document.getElementById('$name').className = '$sname';")
end

"""
**Session Interface**
### style!(cm::Modifier, s::Servable, p::Pair{String, String}) -> _
------------------
Styles the Servable s with the properties and values in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, mybutton, "background-color" => "lightblue", "color" => "white")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::Modifier, s::Servable, p::Pair{String, String} ...)
    p = [pair for pair in p]
    style!(cm, s, p)
end

"""
**Session Interface**
### style!(cm::Modifier, s::String, p::Pair{String, String}) -> _
------------------
Styles the Servable s by name with the properties and values in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, "mybutton", "background-color" => "lightblue", "color" => "white")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::Modifier, s::String, p::Pair{String, String} ...)
    p = [pair for pair in p]
    style!(cm, s, p)
end

"""
**Session Interface**
### style!(cm::Modifier, s::Servable, p::Pair) -> _
------------------
Styles the Servable s with the property and value in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, mybutton, "background-color" => "lightblue")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
style!(cm::Modifier, s::Servable, p::Pair) = style!(cm, s.name, p)

"""
**Session Interface**
### style!(cm::Modifier, name::String, p::Pair) -> _
------------------
Styles a Servable by name with the property and value in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, "mybutton", "background-color" => "lightblue")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::Modifier, name::String, p::Pair)
    key, value = p[1], p[2]
    push!(cm.changes,
        "document.getElementById('$name').style['$key'] = `$value`;")
end

"""
**Session Interface**
### style!(cm::Modifier, name::String, p::Vector{Pair{String, String}}) -> _
------------------
Styles a Servable by name with the properties and values in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, mybutton, ["background-color" => "lightblue"])
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::Modifier, s::Servable,
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
### style!(cm::Modifier, name::String, p::Vector{Pair{String, String}}) -> _
------------------
Styles a Servable by name with the properties and values in p.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        style!(cm, "mybutton", "background-color" => "lightblue")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function style!(cm::Modifier, name::String,
    p::Vector{Pair{String, String}})
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
### free_redirects!(cm::Modifier) -> _
------------------
Removes the "are you sure you wish to leave" box that can be created with
confirm_redirects!
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", redirects = "free")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
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
function free_redirects!(cm::Modifier)
    push!(cm.changes, """window.onbeforeunload = null;""")
end

"""
**Session Interface**
### confirm_redirects!(cm::Modifier) -> _
------------------
Adds an "are you sure you want to leave this page... unsaved changes" pop-up
 when trying to leave the page. Can be undone with `free_redirects!`
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", redirects = "free")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
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
function confirm_redirects!(cm::Modifier)
    push!(cm.changes, """window.onbeforeunload = function() {
    return true;
};""")
end

"""
**Session Interface**
### scroll_to!(cm::Modifier, xy::Tuple{Int64, Int64}) -> _
------------------
Sets the page scroll to xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        scroll_to!(cm, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_to!(cm::Modifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollTo($(xy[1]), $(xy[2]));""")
end

"""
**Session Interface**
### scroll_by!(cm::Modifier, xy::Tuple{Int64, Int64}) -> _
------------------
Scrolls the page by xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        scroll_by!(cm, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_by!(cm::Modifier, xy::Tuple{Int64, Int64})
    push!(cm.changes, """window.scrollBy($(xy[1]), $(xy[2]));""")
end

"""
**Session Interface**
### scroll_to!(cm::Modifier, s::AbstractComponent, xy::Tuple{Int64, Int64}) -> _
------------------
Sets the Component's scroll to xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        scroll_to!(cm, mydiv, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_to!(cm::Modifier, s::AbstractComponent,
     xy::Tuple{Int64, Int64})
     scroll_to!(cm, s, xy)
end

"""
**Session Interface**
### scroll_by!(cm::Modifier, s::AbstractComponent, xy::Tuple{Int64, Int64}) -> _
------------------
Scrolls the Component `s` by xy.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        scroll_by!(cm, mydiv, (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_by!(cm::Modifier, s::AbstractComponent,
    xy::Tuple{Int64, Int64})
    scroll_by!(cm, s, xy)
end

"""
**Session Interface**
### scroll_to!(cm::Modifier, s::String, xy::Tuple{Int64, Int64}) -> _
------------------
Sets the Component's scroll to xy by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        scroll_to!(cm, "mydiv", (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_to!(cm::Modifier, s::String,
     xy::Tuple{Int64, Int64})
     push!(cm.changes,
     """document.getElementById('$s').scrollTo($(xy[1]), $(xy[2]));""")
end

"""
**Session Interface**
### scroll_by!(cm::Modifier, s::String, xy::Tuple{Int64, Int64}) -> _
------------------
Scrolls the Component `s` by xy by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
        scroll_by!(cm, "mydiv", (0, 15))
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function scroll_by!(cm::Modifier, s::String,
    xy::Tuple{Int64, Int64})
    push!(cm.changes,
    """document.getElementById('$s').scrollBy($(xy[1]), $(xy[2]))""")
end

"""
**Session Interface**
### observe!(f::Function, c::Connection, cm::Modifier, name::String, time::Integer = 1000) -> _
------------------
Creates a new event to happen in `time`. This is useful if you want to have a delay before
some initial session call
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "button")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::Modifier
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
function observe!(f::Function, c::Connection, cm::Modifier, name::String, time::Integer = 1000)
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][getip(c)], name => f)
    else
        c[:Session][getip(c)] = Dict(name => f)
    end
    push!(cm.changes, "new Promise(resolve => setTimeout(sendpage('$name'), $time));")
end
