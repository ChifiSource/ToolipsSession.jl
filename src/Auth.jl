function route_403(c::AbstractConnection, message::String)
    if "403" in c.routes
        route!(c, c.routes["403"])
    else
        respond!(c, 403, message)
    end
end

abstract type AbstractClient end

mutable struct Client <: AbstractClient
    key::String
    ip::String
    n_requests::Int64
    data::Dict{String, Any}
    lastup::Dates.DateTime
end

mutable struct AuthenticatedConnection <: Toolips.AbstractIOConnection
    stream::String
    client::Client
    args::Dict{Symbol, String}
    ip::String
    post::String
    route::String
    method::String
    data::Dict{Symbol, Any}
    routes::Vector{<:AbstractRoute}
    system::String
    host::String
    function AuthenticatedConnection(c::AbstractConnection)
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
    AuthenticatedConnection(c)::AuthenticatedConnection
end

mutable struct Auth{T <: AbstractClient} <: Toolips.AbstractExtension
    blacklist::Vector{String}
    clients::Vector{T}
    writekeys::Bool
    max_requests::Int64
    Auth{T}(; write::Bool = false, max_requests::Int64 = 1200) where {T <: AbstractClient} = begin
        blacklist::Vector{String} = Vector{String}()
        clients::Vector{T} = Vector{T}()
        new{T}(blacklist, clients, write, max_requests)::Auth{T}
    end
end

Auth(; args ...) = Auth{Client}(; args ...)

on_start(ext::Auth, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    push!(data, :clients => ext.clients, :authgc => 0)
end

function gc_routine(auth::Auth)
    this_time::Dates.DateTime = now()
    today = day(this_time)
    found = findall(d -> day(d) != today, auth.clients)
    [deleteat!(auth.clients, pos) for pos in found]
    [client.n_requests = 0 for client in auth.clients]
end

function route!(c::AbstractConnection, e::Auth)
    # blacklist
    ip::String = get_ip(c)
    if ip in e.blacklist
        route_403(c, "You have been blacklisted from this webpage.")
        return(false)
    end
    # request check
    cl::Client = e.clients[get_ip(c)]
    cl.lastup = now()
    cl.n_requests += 1
    if sum((client.n_requests)) > 10000
        gc_routine(auth)
    end
    if cl.n_requests > e.max_requests
        push!(e.blacklist, ip)
    end
    args::Dict{Symbol, <:Any} = get_args(c)
    if e.writekeys && get_method(c) != "POST"
        k = div("private-key", text = cl.key)
        write!(c, k)
    end
end

function redirect!(c::AbstractConnection, cm::AbstractComponentModifier, to::String = get_host(c); delay::Int64 = 0)
    new_ref::String = gen_ref(10)
    c[:clients][get_ip(c)].key = new_ref
    redirect!(cm, "$to?key=$new_ref", delay)
end

auth_pass!(c::AbstractConnection, url::String) = begin
    new_ref::String = gen_ref(10)
    c[:clients][get_ip(c)].key = new_ref
    HTTP.get("http://$(string(ip4))?key=$new_ref", response_stream = c.stream, status_exception = false)
end

authenticated(c::AbstractConnection, cm::AbstractComponentModifier) = begin
    cm["private-key"]["text"] == c.client.key
end

authorize!(c::AbstractConnection) = begin
    key::String = gen_ref(10)
    newc::Client = Client(key, get_ip(c), 0, Dict{String, Any}(), now())
    push!(c[:clients], newc)
end
    