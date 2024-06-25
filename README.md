<div align = "center"><img src = "https://github.com/ChifiSource/image_dump/blob/main/toolips/toolipssession.png" href = "https://toolips.app"></img></div>

###### full-stack for toolips !
`ToolipsSession` provides `Toolips` with the `Session` extension, which registers fullstack callbacks on a client-to-client basis. Alongside this, the module provides InputMaps (swipe and keyboard input), `rpc!` callbacks, Authentication via the `Auth` extension, and `next!` animation callbacks.
##### map
- [get started](#get-started)
  - [session](#session)
    - [creating callbacks](#creating-callbacks)
- [authentication](#authentication)
  - [clients](#clients)
  - [authenticating callbacks](#authenticating-callbacks)
- [modifier functions](#modifier-functions)
- [**read before** multi-threading](#multi-threading)
- [input](#input)
  - [bind](#bind)
  - [input maps](#input-maps)
- [rpc](#rpc)
- [changes overview](#changes-overview)
### get started
To get started with `ToolipsSession`, we will need a [Toolips](https://github.com/ChifiSource/Toolips.jl) project. Either generate a new `Toolips` app with `new_app`, or create a new `Module` in the REPL:
```julia
using Pkg
Pkg.add("Toolips")

using Toolips; Toolips.new_app("MyApp"); Pkg.add("ToolipsSession")
```
```julia
using Pkg
Pkg.add("Toolips"); Pkg.add("ToolipsSession")

module MyApp
using Toolips
using ToolipsSession

home = route("/") do c::Connection
  write!(c, "hello new app!")
end

export home, start!
end
```
##### session
`Session` a `Toolips` server extension (`<:Toolips.AbstractExtension`) which manages clients and their fullstack callbacks. In order to load a server extension into our server, we need to construct and export it.
```julia
module MyApp
using Toolips
using ToolipsSession

session = Session()

home = route("/") do c::Connection
  write!(c, "hello new app!")
end

export home, start!, session
end
```
The `Session` constructor takes two optional arguments, `active_routes` and `timeout`.
```julia
Session(active_routes::Vector{String} = ["/"]; timeout = 5)
```
`Session` will only provide interactivity to the route paths provided in `active_routes`. `timeout` represents the number of minutes after not recieving a callback that we will terminate a user's session. Once `Session` is loaded, we can immediately register callbacks on its active routes.
##### creating callbacks
Callbacks in base `Toolips` are created using the `on` function, which is provided a `Function` with an event name, and -- if binding to a `Component` -- a `Component`. These types of callbacks are provided a `ClientModifier`, which allows us to make client-side changes when these events are triggered.
```julia
mydiv = div("sample", text = "click me")
style!(mydiv, "padding" => 10px, "font-size" => 13pt, "background-color" => "darkred", "color" => "white")
on(mydiv, "click") do cl::ClientModifier
    alert!(cl, "you clicked the button")
end
```
Here, we use [modifier functions](#modifier-functions) to modify the changes we want to make on our client's page. Fullstack callbacks work very similarly, but require the `Connection` to be provided as an argument, and will pass a `ComponentModifier` to the `Function`. Here we will reuse `alert!` in the same exact context for a fullstack callback. Another important thing is to compose to a `body` `Component`, so that `ToolipsSession` is able to read all components.
```julia
module MyApp
using Toolips
using ToolipsSession

session = Session()

home = route("/") do c::Connection
  mydiv = div("sample", text = "click me")
  style!(mydiv, "padding" => 10px, "font-size" => 13pt, "background-color" => "darkred", "color" => "white")
  on(c, mydiv, "click") do cm::ComponentModifier
    alert!(cm, "you clicked the button")
  end
end

export home, start!, session
end
```
This type of callback actually calls the server, rather than making the changes on the client directly. This means that we are able to utilize Julia and utilize the data contained within our server, whereas with a `ClientModifier` our provided `Function` is ran when our page is initially served and all of our callbacks remain client-side as callable functions. This means that we are able to serve data straight from our `Function`, or the `Connection` to our user in a far more dynamic way.
```julia
home = route("/") do c::Connection
  mydiv = div("sample", text = "click me")
  style!(mydiv, "padding" => 10px, "font-size" => 13pt, "background-color" => "darkred", "color" => "white", "transition" => 2s)
  at = 0
  colors = ["blue", "orange", "green"]
  on(c, mydiv, "click") do cm::ComponentModifier
    at += 1
    style!(cm, mydiv, 'background-color" => colors[at])
    if at == length(at)
        at = 0
    end
  end
  mainbod = body("main")
  push!(mainbod, mydiv)
  write!(c, mainbod)
end
```
Callbacks can also take a `Connection` and a `ComponentModifier` as arguments, it is possible to take either.
```julia
home = route("/") do c::Connection
  if ~(:names in c.routes)
    push!(c.data, :names => Dict{String, String})
  end
  if ~(get_ip(c) in keys(c[:names])

  end
  mainbutton = button("myname", text = "click to show your name")
  nametxt = div("nametxt")
  mainbod = body("sample")
  on(c, mainbutton, "click") do cm::ComponentModifier

  end
end
```
Callbacks can also be registered by using [ToolipsSession.bind](#bind) to bind keys or keymaps to components and connections.
### modifier functions
### multi-threading
There is a major thing to be aware of when using `Toolips` multi-threading alongside `ToolipsSession`... First, a prerequisite; t is recommended to read [toolips' overview on multi-threading](https://github.com/ChifiSource/Toolips.jl#multi-threading) before trying to use multi-threading alongside this package. The main thing to be aware of is that closures will **not** *serialize over threads*. This means that each `Function` provided for a callback must be a defined `Function` inside of a `Module`, not a `Function` provided as an argument -- like in the case of using `do`.
### input

##### bind
##### keymap
##### swipe input
### rpc
### auth

## changes overview
:)
###### 0.4.1
The first `0.4` patch incoming... Changes are very slight
- updated permanent event `on` binding for `Components`
- added `scroll_to!` binding for scrolling to components.
- improvements to `on` interface.
###### 0.4.0
**alot** has now changed. Most of `ToolipsSession` is now part of `Toolips` itself. Now `ToolipsSession` uses `htmlcomponent` from `ToolipsServables`, rather than here. Parsing is also done on command, the `Session` extension itself is a lot smaller and requires a lot less data to function. This also follows the new `Toolips` `0.3` syntax, which is pretty sweet!
- Brought `Session` extension into `0.3` compatibility.
- Dramatically revised `on`, `bind!` -> `Toolips.bind`.
- Added `SwipeMap`.
- Moved most `AbstractComponentModifier` functions to `Toolips`.
- Revised `RPC` peer system
- `Auth` system now built into this module.
- `htmlcomponent` is now part of [ToolipsServables](https://github.com/ChifiSource/ToolipsServables.jl)
- added `in` binding for `ComponentModifier`
- added `prevent_default` binding for each function.
- Improved docs/testing.
- Improved memory usage.
- Added *"global"* event registration
- Added random `button_select!`.
- Deprecated `Session`-side `KeyFrames` (`Animation` from `Toolips` `0.2.x`) interface.

`Toolips` and `ToolipsSession` are both overhauled in these versions -- a lot of things were moved around, and a lot of significant improvements were made. This package remains similar exactly the same in high-level functionality; other than the move from `bind!` to `bind` and `rpc` these changes will not break existing software that uses `ToolipsSession` (aside from of course the differences in loading the module with `Toolips` `0.3`. I am really looking forward to getting this version out, and doing exciting things with it.
###### 0.3.6
- expanded on client modifier interface
- fixed unicode indexing errors
- rewrote `htmlcomponent` methods, created `html_properties`
###### new in 0.3.4
- fixed linker event reference losses
- added `ClientModifier` interface
- added `clear!` interface
- `KeyMap`/`InputMap`(s)
- added marking (for event removal)
- added `on` bindings
- refined `script!`/`script`
- added `call!` for RPC. (call! does on all peers (not current client), rpc! does for everyone, regular cm does local)
###### new in 0.3.1
- new `insert!` for `ComponentModiifer`
- fixes for `focus!`
- new `bind!` bindings
- some documentation updates
- `0.3.0` patches
###### new in 0.3.0
- new `bind` method replaces old keys, can now use event and hotkeys quite easily with this method.
- `KeyMap`s and `InputMap`s
- simplified `on`.
- multi-client remote procedure `ComponentModifier` sessions. (`rpc!`, `open_rpc!`, `join_rpc!`, `disconnect_rpc!`, `close_rpc!`, `is_host`, `is_client`, `is_dead`)
- new `script!` and `script` interface for creating client functions and observable functions in a consistent way.
- Additional abstraction to Modifiers. 
- Client Modifiers
- `Modifier` Abstract type moved to [toolips](https://github.com/ChifiSource/Toolips.jl)
- `next!` method to set next animations and changes.
- `observe!` has become `script`and `script!` in accordance with new syntax.
- `append_first!` allows us to append a child to the top of the children.
- `push!` `ComponentModifier` bindings to put scripts into documents.
- `update!` allows any Julia type to be written to the "text/html" MIME. Eventually, this function will include an auto-mime algorithm similar to the one seen in Olive.jl [here](https://github.com/ChifiSource/Olive.jl/blob/main/src/Core.jl) (towards the bottom of the file).
