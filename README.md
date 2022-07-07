<div align = "center"><img src = "https://github.com/ChifiSource/image_dump/blob/main/toolips/toolipssession.png" href = "https://toolips.app"></img></div>

### Full-stack web-development for Julia with toolips
Toolips Session is a Server Extension for toolips that enables full-stack web-development capabilities. This extension is loaded by default whenever the `Toolips.new_webapp` from the base toolips package is used. Ideally, your project would be setup that way instead of by adding this directly; but of course, you can still add this directly.
- [Documentation](https://doc.toolips.app/toolips_session/)
- [Toolips](https://github.com/ChifiSource/Toolips.jl)
- [Extension Gallery]()
##### Step 1: add to your dev.jl
Add ToolipsSession to your dev.jl file. Note **if you use new_webapp** from Toolips, then you don't need to do any of this.
```julia
#==
dev.jl is an environment file. This file loads and starts servers, and
defines environmental variables, setting the scope a lexical step higher
with modularity.
==#
using Pkg; Pkg.activate(".")
using Toolips
using ToolipsSession
using Revise

IP = "127.0.0.1"
```
##### Step 2: Add Session() to your server extension vector, in your dev.jl file:
```julia
#==
Extension description
:logger -> Logs messages into both a file folder and the terminal.
:public -> Routes the files from the public directory.
:mod -> ToolipsModifier; allows us to make Servables reactive. See ?(on)
==#
extensions = [Logger(), Session()]
```
##### Step 3: Add ToolipsSession to your module, use on()
```julia
module ModifierTest
using Toolips
using ToolipsSession

function home(c::Connection)
    myp = p("helloworld2", text = "hello world!", align = "left")
    on(c, myp, "click") do cm::ComponentModifier
        if cm[myp]["align"] == "left"
            cm[myp] = "align" => "center"
        elseif cm[myp]["align"] == "center"
            cm[myp] = "align" => "right"
        else
            cm[myp] = "align" => "left"
        end
    end
```
