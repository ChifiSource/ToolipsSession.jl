<div align = "center"><img src = "https://github.com/ChifiSource/image_dump/blob/main/toolips/toolipssession.png" href = "https://toolips.app"></img></div>

###### full-stack for toolips !
`ToolipsSession` provides `Toolips` with the `Session` extension, which registers fullstack callbacks on a client-to-client basis. Alongside this, the module provides InputMaps (swipe and keyboard input), `rpc!` callbacks, Authentication via the `Auth` extension, and `next!` animation callbacks.
##### map
- [get started](#get-started)
  - [session](#session)
  - [creating callbacks](#creating-callbacks)
- [modifier functions](#modifier-functions)
- [**read before** multi-threading](#multi-threading)
- [input](#input)
  - [bind](#bind)
  - [keymap](#keymap)
  - [swipe input](#swipe-input)
- [rpc](#rpc)
- [auth](#auth)
### get started
To get started with `ToolipsSession`, we will need a [Toolips](https://github.com/ChifiSource/Toolips.jl) project. Either generate a new `Toolips` app with `new_app`, or create a new `Module` in the REPL:
```julia
module ToolipsApp
using Toolips

home = route("/") do c::Connection

end

export 
```
##### session

##### creating callbacks

### modifier functions
### multi-threading
### input

##### bind
##### keymap
##### swipe input
### rpc
### auth

###### 0.4.0
**alot** has now changed. Most of `ToolipsSession` is now part of `Toolips` itself. Now `ToolipsSession` uses `htmlcomponent` from `ToolipsServables`, rather than here. Parsing is also done on command, the `Session` extension itself is a lot smaller and requires a lot less data to function. This also follows the new `Toolips` `0.3` syntax, which is pretty sweet!
- Brought `Session` extension into `0.3` compatibility.
- Dramatically revised `on`, `bind!` -> `Toolips.bind`.
- Added `SwipeMap`.
- Moved most `AbstractComponentModifier` functions to `Toolips`.
- Revised `RPC` peer system
- `Auth` now built into this module.
- 
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
