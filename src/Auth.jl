abstract type AbstractClient end

mutable struct Client <: AbstractClient
    key::String
    ip::String
    n_requests::Int64
    data::Dict{String, Any}
    lastup::Dates.DateTime
end

in(ip::String, v::Vector{<:AbstractClient}) = begin
    found = findfirst(c::AbstractClient -> c.ip == ip, v)
    if ~(isnothing(found))
        return(true)::Bool
    end
    false::Bool
end

mutable struct Auth{T <: AbstractClient} <: Toolips.AbstractExtension
    blacklist::Vector{String}
    clients::Vector{T}
    writekeys::Bool
    Auth{T}(; write::Bool = false) where {T <: AbstractClient} = begin
        blacklist::Vector{String} = Vector{String}()
        clients::Vector{T} = Vector{T}()
        new{T}(blacklist, clients, write)::Auth{T}
    end
end

Auth(f::Function; write::Bool = false) = Auth{Client}(write = write)

on_start(ext::Auth, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    push!(data, :clients => ext.clients, :authgc => 0)
end

function gc_routine(auth::Auth)
    this_time::Dates.DateTime = now()
    today = day(this_time)
    found = findall(d -> day(d) != today, auth.clients)
    [deleteat!(auth.clients, pos) for pos in ]
end

function route!(c::AbstractConnection, e::Auth)
    # blacklist
    ip::String = get_ip(c)
    if ip in e.blacklist
        route_403(c, "You have been blacklisted from this webpage.")
        return(false)
    end
    # make new clients
    if ~(ip in e.clients)
        key::String = gen_ref(10)
        newc::Client = Client(key, ip, 0, Dict{String, Any}(), now())
        push!(e.clients, newc)
    end
    # request check
    cl::Client = e.clients[get_ip(c)]
    cl.lastup = now()
    cl.n_requests += 1
    gc_routine(auth)
    args::Dict{Symbol, <:Any} = get_args(c)
    if :key in keys(args)
        if args[:key] == cl.key
            route!(c, c.routes)
        else
            route_403(c, "Auth key does not match. Packet intercepted?")
        end
        return(false)::Bool
    end
    if e.writekeys && get_method(c) != "POST"
        k = div("private-key", text = cl.key)
        write!(c, k)
    end
end

function route_403(c::AbstractConnection, message::String)
    if "403" in c.routes
        route!(c, c.routes["403"])
    else
        respond!(c, 403, message)
    end
end

authenticated(c::AbstractConnection, cm::ComponentModifier) = begin
    key::String = c[:clients][get_ip(c)].key
    args = get_args(c)
    cm["private-key"]["text"] == key || (:key in keys(args) && args[:key] == key)
end
