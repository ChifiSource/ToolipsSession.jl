using Toolips
import Toolips: StyleComponent, get, kill!, animate!, SpoofConnection
import Toolips: style!, Servable, Connection, Modifier, string
import Base: setindex!, getindex, push!, append!, insert!

"""
### abstract type AbstractComponentModifier <: Servable
Modifiers are used to interpret and respond to incoming data. AbstractComponentModifiers
change Components that are already written to a Connection. These are in essence,
the callback function's mutable type for toolips. The prime example
for this is the **ComponentModifier**. This is used to bring Components into a
    readable form and then change different Component properties.
##### Consistencies
- **Servable** Is bound to `Toolips.write!` in one form or another, and works
in `Vector{Servable}`s.
"""
abstract type AbstractComponentModifier <: Modifier end

function html_properties(s::AbstractString)
    propvec::Vector{SubString} = split(s, " ")
    properties::Dict{Any, Any} = Dict{Any, Any}(begin
        ppair::Vector{SubString} = split(segment, "=")
        if length(ppair) < 2
            string(ppair[1]) => string(ppair[1])
        else
            string(ppair[1]) => replace(string(ppair[2]), "\"" => "")
        end
    end for segment in propvec)
    properties::Dict{Any, Any}
end
#==
"""
**Session Internals**
### htmlcomponent(f::Function, readonly::Vector{String};  )
) -> ::Dict{String, Toolips.Component}
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
function htmlcomponent(s::String; nonames::Bool = false)
    startpos = findfirst("<", s)
    if isnothing(startpos)
        return(Vector{Servable}())::Vector{Servable}
    end
    s = s[startpos[1]:length(s)]
    splits::Vector{SubString} = split(s, "><")
    servevec = Vector{Servable}()
    servevec = Vector{Servable}(filter(x -> ~(isnothing(x)), [begin
        element = string(element)
        tagnd = findfirst(" ", element)
        if ~(isnothing(tagnd)) && ~(contains(element[1:minimum(tagnd)], "/"))
            tagstart::Int64 = 1
            if contains(element[1:tagnd[1]], "<")
                tagstart = 2
            end
            tag::String = ""
            tag = replace(string(element[tagstart:minimum(tagnd) - 1]), "<" => "", ">" => "")
            txt_split = findfirst(">", element)
            fulltxt::String = ""
            name::String = ""
            try
                propstring::String = element[minimum(tagnd):length(element)]
            catch
                propstring = ""
            end
            if ~(isnothing(txt_split))
                propstring = element[minimum(tagnd):minimum(txt_split) - 1]
                txtend = findnext("</$tag", element, minimum(txt_split))
                if isnothing(txtend)
                    fulltxt = element[minimum(txt_split) + 1:length(element)]
                else
                    try
                        fulltxt = element[minimum(txt_split) + 1:txtend[1] - 1]
                    catch
                        
                    end
                end
            end
            properties::Dict{Any, Any} = html_properties(propstring)
            if "id" in keys(properties)
                name = properties["id"]
            end
            push!(properties, "text" => replace(fulltxt, "<br>" => "\n", "<div>" => "", 
            "&#36;" => "\$", "&#37;" => "%", "&#38;" => "&", "&nbsp;" => " ", "&#60;" => "<", "	&lt;" => "<", 
            "&#62;" => ">", "&gt;" => ">", "<br" => "\n"))
            if name == "" && ~(nonames)
                nothing
            else
                Component(name, tag, properties)::Component{<:Any}
            end
        else
            nothing
        end
    end for element in splits]))::Vector{Servable}
end
==#
function htmlcomponent(s::String; nonames::Bool = false)
    tagpos::Vector{UnitRange{Int64}} = filter!(r -> ~(contains(s[r], "</")) || length(r) < 1, [f[1]:e[1] for (f, e) in zip(findall("<", s), findall(">", s))])
    if ~(nonames)
        filter(r -> contains(s[r], " id="), tagpos)
    end
    Vector{Servable}([begin 
        ndopen = findnext(">", s, minimum(tag))
        offset = tag[1]
        tagr = findnext(" ", s, tag[1])
        if isnothing(tagr) || minimum(tagr) > maximum(ndopen)
            tagr = ndopen
        end
        nametag::String = s[minimum(tag) + 1:maximum(tagr) - 1]
        tagtext::String = ""
        textr::UnitRange = 0:0
        try
            textr = maximum(tag) + 1:minimum(findnext("</$nametag", s, tag[1])[1]) - 1
            tagtext = s[textr]
        catch
            tagtext = ""
        end
        properties::Dict{<:Any, <:Any} = html_properties(s[maximum(tagr) + 1:maximum(tag) - 1])
        name::String = ""
        if "id" in keys(properties)
            name = properties["id"]
            delete!(properties, "id")
        end
        push!(properties, "text" => replace(tagtext, "<br>" => "\n", "<div>" => "", 
        "&#36;" => "\$", "&#37;" => "%", "&#38;" => "&", "&nbsp;" => " ", "&#60;" => "<", "	&lt;" => "<", 
        "&#62;" => ">", "&gt;" => ">", "<br" => "\n", "&bsol;" => "\\", "&#63;" => "?"))
        Component(name, nametag, properties)
    end for tag in tagpos])::Vector{Servable}
end

function htmlcomponent(s::String, readonly::Vector{String})
    if readonly[1] == "none"
        return Vector{Servable}()
    end
    Vector{Servable}(filter!(x -> ~(isnothing(x)), [begin
        element_sect = findfirst(" id=\"$compname\"", s)
        if ~(isnothing(element_sect))
            starttag = findprev("<", s, element_sect[1])[1]
            ndtag = findnext(" ", s, element_sect[1])[1]
            argfinish = findnext(">", s, ndtag)[1] + 1
            tg = s[starttag + 1:ndtag - 1]
            finisher = findnext("</$tg", s, argfinish)
            fulltxt = s[argfinish:finisher[1] - 1]
            properties = html_properties(s[ndtag:argfinish - 2])
            name::String = ""
            if "id" in keys(properties)
                name = properties["id"]
                delete!(properties, "id")
            end
            push!(properties, "text" => replace(fulltxt, "<br>" => "\n", "<div>" => "", 
            "&#36;" => "\$", "&#37;" => "%", "&#38;" => "&", "&nbsp;" => " ", "&#60;" => "<", "	&lt;" => "<", 
            "&#62;" => ">", "&gt;" => ">", "<br" => "\n", "&bsol;" => "\\", "&#63;" => "?"))
            Component(compname, string(tg), properties)
        else
        end
    end for compname in readonly]))::Vector{Servable}
end


abstract type AbstractVar <: AbstractString end

string(av::AbstractVar) = funccl(av)
iterate(var::AbstractVar) = iterate(var.value)

mutable struct ComponentProperty <: AbstractVar 
    name::String
    value::Pair{String, String}
end

struct Var <: AbstractVar value::String end

function funccl(cp::ComponentProperty)
    "document.getElementById('$(cp.name)').$(cp.value[1]);"
end

iterate(comp::ComponentProperty) = iterate(comp.value[2])

funccl(v::Var) = "$(v.value)"

abstract type AbstractClientModifier <: AbstractComponentModifier end

"""
### ClientModifier <: AbstractComponentModifier
- changes::Vector{String}

The `ClientModifier` makes changes specifically client-side. This means that
attributes cannot be used. In the future this will be slightly adjusted to
include client-side variables. The biggest thing is that Julia cannot be used
in them, though Julia can be placed to use this. Importantly, do not call this
directly, similarly to the `ComponentModifier`, it is meant to be used with
`on`.
##### example
```
route("/") do c::Connection
    mydiv = divider("mydiv", align = "center")
    c, mydiv)
end
```
------------------
##### constructors
- ComponentModifier(html::String)
"""
mutable struct ClientModifier <: AbstractClientModifier
    name::String
    changes::Vector{String}
    event::Var
    ClientModifier(name::String = gen_ref()) = begin
        new(name, Vector{String}(), Var("event"))::ClientModifier
    end
end

function funccl(cm::ClientModifier = ClientModifier(), name::String = cm.name)
    """function $(name)(event){$(join(cm.changes))}"""
end

function getindex(cl::ClientModifier, s::String, prop::String)
    ComponentProperty(s, prop => "")
end

function getindex(cl::ClientModifier, s::String)
    id = gen_ref(4)
    push!(cl.changes, "$id = document.getElementbyId('$s');")
    Var(id)::Var
end

getindex(cl::ClientModifier, s::Component{<:Any}, prop::String) = getindex(cl, s.name, prop)

function getindex(cm::AbstractComponentModifier, s::String, prop::String)
    cm[s]
end

setindex!(cm::AbstractComponentModifier, a::Any, cp::AbstractVar) = begin
    push!(cm.changes, "$(funccl(cp)) = $a;")
end

function store!(cl::ClientModifier, s::String, a::Any)
    push!(cl.changes, "$s = $a;")
    Var(s)
end

function check(f::Function, cl::ClientModifier, var1::AbstractVar,
    operator::Function, var2::AbstractVar)
    newcl = ClientModifier()
    f(newcl)
    push!(cl.changes, "if ($var1 $operator $var2) {$(join(newcl.changes))}")
end

write!(c::AbstractConnection, cm::ClientModifier) = write!(c, funccl(cm))

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

write!(c::Connection, ac::AbstractComponentModifier) = write!(c, join(ac.changes))

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
setindex!(cm::AbstractComponentModifier, p::Pair, s::AbstractComponent) = modify!(cm, s, p)

"""
**Session Interface**
### setindex!(cm::AbstractComponentModifier, p::Pair, s::String) -> _
------------------
Sets the property from p[1] to p[2] on the served with name s.
#### example
```
on(c, mydiv, "click") do cm::AbstractComponentModifier
    if cm["mydiv"]["align"] == "center"
        cm["mydiv"] = "align" => "left"
    else
        cm["mydiv"] = "align" => "center"
    end
end
```
"""
setindex!(cm::AbstractComponentModifier, p::Pair, s::String) = modify!(cm, s, p)

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

"""
**Session Interface**
### alert!(cm::AbstractComponentModifier, s::String) -> _
------------------
Sends an alert to the current session.
#### example
```
on(c, s, "click") do cm::AbstractComponentModifier
    alert!(cm, "oh no!")
end
```
"""
alert!(cm::AbstractComponentModifier, s::AbstractString) = push!(cm.changes,
        "alert('$s');")

"""
**Session Interface**
### redirect!(cm::AbstractComponentModifier, url::AbstractString, delay::Int64 = 0) -> _
------------------
Redirects the session to **url**. Can be given delay with **delay**.
#### example
```
url = "https://toolips.app"
on(c, s, "click") do cm::AbstractComponentModifier
    redirect!(cm, url, 3) # waits three seconds, then navigates to toolips.app
end
```
"""
function redirect!(cm::AbstractComponentModifier, url::AbstractString, delay::Int64 = 0)
    push!(cm.changes, """
    setTimeout(function () {
      window.location.href = "$url";
   }, $delay);
   """)
end

"""
**Session Interface**
### modify!(cm::AbstractComponentModifier, s::Servable, p::Pair ...) -> _
------------------
Modifies the key properties of p[1] to the value of p[2] on s. This can also be
done with setindex!
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        cm[mybutton] = "align" = "center"
    end
    write!(c, mybutton)
end
```
"""
function modify!(cm::AbstractComponentModifier, s::AbstractComponent, p::Pair ...)
    p = [pair for pair in p]
    modify!(cm, s, p)
end

"""
**Session Interface**
### modify!(cm::AbstractComponentModifier, s::Servable, p::Vector{Pair{String, String}}) -> _
------------------
Modifies the key properties of i[1] => i[2] for i in p on s.
"""
function modify!(cm::AbstractComponentModifier, s::AbstractComponent,
    p::Vector{Pair{String, String}})
    [modify!(cm, s, z) for z in p]
end

"""
**Session Interface**
### modify!(cm::AbstractComponentModifier, s::Servable, p::Pair) -> _
------------------
Modifies the key property p[1] to p[2] on s
"""
modify!(cm::AbstractComponentModifier, s::AbstractComponent, p::Pair) = modify!(cm, s.name, p)

"""
**Session Interface**
### modify!(cm::AbstractComponentModifier, s::Servable, p::Pair) -> _
------------------
Modifies the key property p[1] to p[2] on s
"""
function modify!(cm::AbstractComponentModifier, s::String, p::Pair)
    key, val = p[1], p[2]
    push!(cm.changes,
    "document.getElementById('$s').setAttribute('$key','$val');")
end


"""
**Session Interface**
### move!(cm::AbstractComponentModifier, p::Pair{Servable, Servable}) -> _
------------------
Moves the servable p[2] to be a child of p[1].
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        move!(cm, mybutton => mydiv)
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
move!(cm::AbstractComponentModifier, p::Pair{Servable, Servable}) = move!(cm,
                                                        p[1].name => p[2].name)

"""
**Session Interface**
### move!(cm::AbstractComponentModifier, p::Pair{String, String}) -> _
------------------
Moves the servable p[2] to be a child of p[1] by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        move!(cm, "mybutton" => "mydiv")
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function move!(cm::AbstractComponentModifier, p::Pair{String, String})
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
### remove!(cm::AbstractComponentModifier, s::Servable) -> _
------------------
Removes the servable s.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        remove!(cm, mybutton)
    end
    write!(c, mybutton)
end
```
"""
remove!(cm::AbstractComponentModifier, s::Servable) = remove!(cm, s.name)

"""
**Session Interface**
### remove!(cm::AbstractComponentModifier, s::String) -> _
------------------
Removes the servable s by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        remove!(cm, "mybutton")
    end
    write!(c, mybutton)
end
```
"""
function remove!(cm::AbstractComponentModifier, s::String)
    push!(cm.changes, "document.getElementById('$s').remove();")
end

"""
**Session Interface**
### set_text!(cm::AbstractComponentModifier, s::Servable, txt::String) -> _
------------------
Sets the inner HTML of a Servable.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change text")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        set_text!(cm, mybutton, "changed text")
    end
    write!(c, mybutton)
end
```
"""
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
function set_text!(c::Modifier, s::String, txt::String)
    txt = replace(txt, "`" => "\\`")
    txt = replace(txt, "\"" => "\\\"")
    txt = replace(txt, "''" => "\\'")
    push!(c.changes, "document.getElementById('$s').innerHTML = `$txt`;")
end

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
function set_children!(cm::AbstractComponentModifier, s::Servable, v::Vector{Servable})
    set_children!(cm, s.name, v)
end

"""
**Session Interface**
### set_children!(cm::AbstractComponentModifier, s::String, v::Vector{Servable}) -> _
------------------
Sets the children of a given component by name.
#### example
```
function home(c::Connection)
    mybutton = button("mybutton", text = "click to change alignment", align = "left")
    newptext = p("newp", text = "this text is added to our div")
    mydiv = div("mydiv")
    on(c, mybutton, "click") do cm::AbstractComponentModifier
        set_children!(cm, "mydiv", [newptext])
    end
    write!(c, mybutton)
    write!(c, mydiv)
end
```
"""
function set_children!(cm::AbstractComponentModifier, s::String, v::Vector{Servable})
    spoofconn::SpoofConnection = SpoofConnection()
    write!(spoofconn, v)
    txt::String = spoofconn.http.text
    set_text!(cm, s, txt)
end

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
function append!(cm::AbstractComponentModifier, name::String, child::Servable)
    spoofconn = Toolips.SpoofConnection()
    write!(spoofconn, child)
    txt = replace(spoofconn.http.text, "`" => "\\`", "\"" => "\\\"", "'" => "\\'")
    push!(cm.changes, "document.getElementById('$name').appendChild(document.createRange().createContextualFragment(`$txt`));")
end

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
function insert!(cm::AbstractComponentModifier, name::String, i::Int64, child::Servable)
    spoofconn = Toolips.SpoofConnection()
    write!(spoofconn, child)
    txt = replace(spoofconn.http.text, "`" => "\\`", "\"" => "\\\"", "'" => "\\'")
    push!(cm.changes, "document.getElementById('$name').insertBefore(document.createRange().createContextualFragment(`$txt`), document.getElementById('$name').children[$(i - 1)]);")
end

function sleep!(cm::ComponentModifier, time::Int64)
    push!(cm.changes, "await new Promise(r => setTimeout(r, $time));")
end

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
function style!(cc::Modifier, name::String,  sname::String)
    push!(cc.changes, "document.getElementById('$name').className = '$sname';")
end

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
function style!(cm::AbstractComponentModifier, name::String, p::Pair)
    key, value = p[1], p[2]
    push!(cm.changes,
        "document.getElementById('$name').style['$key'] = `$value`;")
end

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
### style!(cm::AbstractComponentModifier, name::String, p::Vector{Pair{String, String}}) -> _
------------------
Styles a Servable by name with the properties and values in p.
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
function style!(cm::AbstractComponentModifier, name::String,
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
function next!(f::Function, c::AbstractConnection, comp::Component{<:Any},
    cm::ComponentModifier, readonly::Vector{String} = Vector{String}())
    ip::String = getip(c)
    name = gen_ref()
    cm[comp.name] = "ontransitionend" => "sendpage(\"$(name)\");"
    if getip(c) in keys(c[:Session].iptable)
        push!(c[:Session][ip], name => f)
    else
        c[:Session].events[ip] = Dict(name => f)
    end
    if length(readonly) > 0
        c[:Session].readonly["$(ip)$(name)"] = readonly
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
