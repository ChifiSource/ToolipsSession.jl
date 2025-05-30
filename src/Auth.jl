function route_403(c::AbstractConnection, message::String)
    if "403" in c.routes
        route!(c, c.routes["403"])
    else
        respond!(c, 403, message)
    end
end

"""
```julia
abstract type AbstractClient
```
An `AbstractClient` is used by the `Auth` extension in order to keep track 
of different clients. `ToolipsSession` provides the `Client` type to facilitate this role 
by default.

- See also: `Auth`, `Client`, `authorize!`
"""
abstract type AbstractClient end

"""
```julia
mutable struct Client <: AbstractClient
```
- `key`**::String**
- `ip`**::String**
- `n_requests`**::Int64**
- `data`**::Dict{String, Any}**
- `lastup`**::Dates.DateTime**

A `Client` is the quintessential `AbstractClient` used by `Auth` to keep track 
of incoming users. This is constructed whenever we use `authorize!` to authorize an 
incoming `Connection`, and will be passed in the `Client` field of our `AuthenticatedConnection`
- See also: `Auth`, `AbstractClient`, `redirect!`, `authorize!`
```julia
Client(key::String, ip::String, n_requests::Int64, data::Dict{String, Any}, lastup::Dates.DateTime)
```
```example

```
"""
mutable struct Client <: AbstractClient
    key::String
    ip::String
    n_requests::Int64
    data::Dict{String, Any}
    lastup::Dates.DateTime
end

"""
```julia
mutable struct AuthenticatedConnection{T <: AbstractClient} <: AbstractIOConnection
```
- `stream`**::Stream**
- `client`**::T**
- `args**::Dict{Symbol, String}**`
- `ip`**String**
- `post`**::String**
- `route`**String**
- `method`**String**
- `data`**Dict{Symbol, Any}**
- `routes`**::Vector{<:AbstractRoute}**`
- `system`**::String**
- `host`**::String**

The `AuthenticatedConnection` is passed when an authenticated client connects to a 
route with an `AuthenticatedConnection` multi-route. This special `Connection` 
features the `AuthenticatedConnection.client` field, which yields more information on 
the current client, as well as indexable data for individual clients. Typically, the 
authentication process will start by serving on a route with a `Connection`/`AbstractConnection`/`IOConnection` 
and using `authenticate!` to reload and serve a client through the `AuthenticatedConnection`.
- `authorize!(c::AbstractConnection)`
- See also: `Client`, `Auth`, `auth_redirect!`
```julia
AuthenticatedConnection{T}(c::AbstractConnection) where {T <: AbstractClient}
```
```example

```
"""
mutable struct AuthenticatedConnection{T <: AbstractClient} <: Toolips.AbstractIOConnection
    stream::String
    client::T
    args::Dict{Symbol, String}
    ip::String
    post::String
    route::String
    method::String
    data::Dict{Symbol, Any}
    routes::Vector{<:AbstractRoute}
    system::String
    host::String
    function AuthenticatedConnection{T}(c::AbstractConnection) where {T <: AbstractClient}
        new("", c.data[:clients][get_ip(c)], 
        get_args(c), get_ip(c), get_post(c), get_route(c), get_method(c), 
        c.data, c.routes, get_client_system(c)[1], get_host(c))
    end
end

in(ip::String, v::Vector{<:AbstractClient}) = begin
    found = findfirst(c::AbstractClient -> c.ip == ip, v)
    if ~(isnothing(found))
        return(true)::Bool
    end
    false::Bool
end

getindex(v::Vector{<:AbstractClient}, ip::String) = begin
    found = findfirst(c::AbstractClient -> c.ip == ip, v)
    if ~(isnothing(found))
        return(v[found])::AbstractClient
    end
    throw(KeyError(ip))
end

convert(c::AbstractConnection, routes::Routes, T::Type{AuthenticatedConnection}) = begin
    get_ip(c) in c[:clients]
end

convert!(c::AbstractConnection, routes::Routes, into::Type{AuthenticatedConnection}) = begin
    AuthenticatedConnection{Client}(c)::AuthenticatedConnection
end

"""
```julia
mutable struct Auth{T <: AbstractClient} <: Toolips.AbstractExtension
```
- `blacklist`**::Vector{String}**
- `clients`**::Vector{T}**
- `max-requests`**::Int64**

`Auth` is a `Toolips` extension that automatically handles authentication using a 
high-level client API. This is useful for a myriad of different contexts.
- Confirming API keys with clients and serving only to authenticated users.
- Serving to a myriad of different users, and having user data for each one.
- Or serving user sessions with memory of who incoming clients are.

This is a server extension which also utilizes a `Connection` extension via 
multi-route. To load this extension, first export `Auth` in your server and then 
create a multi-route.

```julia
module AuthServer
using Toolips
using Toolips.Components
using ToolipsSession

session = Session()
auth = Auth()

main_land = route("/") do c::AbstractConnection
    mainbody = body("main", children = [h2(text = "you are not authenticated")])
    authbutton = button("auth-button", text = "press to authenticate")
    on(c, authbutton, "click") do cm::ComponentModifier
        authorize!(c)
        # by default redirects to `/`.
        auth_redirect!(c, cm)
    end
    push!(mainbody, authbutton)
    write!(c, mainbody)
end

main_auth = route("/") do c::AuthenticatedConnection
    write!(c, "you have been authenticated")
end

main = route(main_land, main_auth)

export main, session, auth
end
```
Using `Auth` revolves around three functions and their methods:
```julia
authorize!(c::AbstractConnection, data::Pair{String, <:Any} ...)
auth_redirect!(c::AbstractConnection, to::String = get_host(c))
auth_redirect!(c::Abstractonnection cm::AbstractComponentModifier, to::String = get_host(c); delay::Int64 = 0)
auth_pass!(c::AbstractConnection, url::String)
```
`authorize!` is used to `authorize!` a `Connection`. For example, we might have a login 
screen that finishes with a call to `authorize!`. The `data` argument takes any data we want to initalize 
with for the client.
```julia
module AuthServer
using Toolips
using Toolips.Components
using ToolipsSession

session = Session()
auth = Auth()
# "name" page example.
main_land = route("/") do c::AbstractConnection
    mainbody = body("main", children = [h2(text = "enter your name")])
    namebox = textdiv("namebox")
    style!(namebox, "display" => "inline-block")
    authbutton = button("auth-button", text = "enter namee")
    on(c, authbutton, "click") do cm::ComponentModifier
        authorize!(c, "name" => cm[namebox]["text"])
        # by default redirects to `/`.
        auth_redirect!(c, cm)
    end
    push!(mainbody, namebox, authbutton)
    write!(c, mainbody)
end

main_auth = route("/") do c::AuthenticatedConnection
    write!(c, "your name is " * c.client["name"])
end

main = route(main_land, main_auth)

export main, session, auth
end
```
- See also: 
```julia
Auth(; max_requests::Int64 = 1200)
```
"""
mutable struct Auth{T <: AbstractClient} <: Toolips.AbstractExtension
    blacklist::Vector{String}
    clients::Vector{T}
    max_requests::Int64
    Auth{T}(; max_requests::Int64 = 1200) where {T <: AbstractClient} = begin
        @warn "`Auth` will be deprecated in favor of `Session`-bourne authentication in `ToolipsSession` `0.5`. It is best *not* to build your app around this."
        blacklist::Vector{String} = Vector{String}()
        clients::Vector{T} = Vector{T}()
        new{T}(blacklist, clients, max_requests)::Auth{T}
    end
end

Auth(; args ...) = Auth{Client}(; args ...)

on_start(ext::Auth, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    push!(data, :clients => ext.clients)
end

function gc_routine(auth::Auth)
    this_time::Dates.DateTime = now()
    today = day(this_time)
    found = findall(d -> day(d) != today, auth.clients)
    [deleteat!(auth.clients, pos) for pos in found]
    [client.n_requests = 0 for client in auth.clients]
    nothing::Nothing
end

function route!(c::AbstractConnection, e::Auth)
    # blacklist
    ip::String = get_ip(c)
    if ip in e.blacklist
        route_403(c, "You have been blacklisted from this webpage.")
        return(false)
    end
    args::Dict{Symbol, <:Any} = get_args(c)
    if :key in keys(args)
        cl = findfirst(client -> client.key == args[:key], e.clients)
        if ~(isnothing(cl))
            cl.ip = get_ip(c)
            return
        else
            route_403(c, "Invalid `key` provided")
        end
    end
    # request check
    if get_ip(c) in e.clients
        cl::AbstractClient = e.clients[get_ip(c)]
        cl.lastup = now()
        cl.n_requests += 1
        if sum((cl.n_requests)) > 10000
            gc_routine(auth)
        end
        if cl.n_requests > e.max_requests
            push!(e.blacklist, ip)
            clpos = findfirst(cli -> cli.ip == ip, e.clients)
            deleteat!(e.clients, clois)
        end
    end
end

"""
```julia
auth_redirect!(c::AbstractConnection, ...) -> ::Nothing
```
Redirects an incoming `Connection` with an authentication key inside of the arguments.
```julia
auth_redirect!(c::AbstractConnection, to::String = get_host(c))
auth_redirect!(c::Abstractonnection cm::AbstractComponentModifier, to::String = get_host(c))
```
```example

```
"""
function auth_redirect!(c::Toolips.AbstractConnection, to::String = get_host(c))
    new_ref::String = gen_ref(10)
    c[:clients][get_ip(c)].key = new_ref
    inner::String = "$to?key=$new_ref"
    newscr = script("authdir", text = "window.location.href = '$inner';")
    write!(c, newscr)
end

function auth_redirect!(c::Toolips.AbstractConnection, cm::AbstractComponentModifier, to::String = get_host(c))
    new_ref::String = gen_ref(10)
    c[:clients][get_ip(c)].key = new_ref
    redirect!(cm, "$to?key=$new_ref", delay)
end


"""
```julia
auth_pass!(c::AbstractConnection, url::String) -> ::Nothing
```
Performs an authenticated pass-through to the `url` on the `Connection`. Sends to `url` 
with an authentication key for this server. (This type of concept is useful is servers share the same `Auth.clients` or `Auth` extension.)
```example

```
"""
auth_pass!(c::Toolips.AbstractConnection, url::String) = begin
    new_ref::String = gen_ref(10)
    c[:clients][get_ip(c)].key = new_ref
    inner = "window.location.replace('$to?key=$new_ref');"
    newscr = script("authdir", text = "window.location.replace('$inner');")
    write!(c, newscr)
end

"""
```julia
authorize!(c::AbstractConnection, data::Pair{String, <:Any} ...)
```
Authorizes a client, making their next load of the page be to the `AuthenticatedConnection`. 
`data` can optionally be provided to initialize the client with data.
```example

```
"""
authorize!(c::Toolips.AbstractConnection, data::Pair{String, <:Any} ...) = begin
    key::String = gen_ref(10)
    data = Dict{String, Any}(p[1] => p[2] for p in data)
    newc::Client = Client(key, get_ip(c), 0, data, now())
    push!(c[:clients], newc)
end