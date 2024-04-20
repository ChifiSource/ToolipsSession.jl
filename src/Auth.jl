abstract type AbstractClient end

mutable struct Client <: AbstractClient
    key::String
    ip::String
    n_requests::Int64
    data::Dict{String, Any}
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
    lastup::Dates.DateTime
    writekeys::Bool
    Auth{T}(; write::Bool = false) where {T <: AbstractClient} = begin
        blacklist::Vector{String} = Vector{String}()
        clients::Vector{T} = Vector{T}()
        new{T}(blacklist, clients, now(), write)::Auth{T}
    end
end

Auth(; write::Bool = false) = Auth{Client}(write = write)

on_start(ext::Auth, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    push!(data, :users => ext.clients)
end

function route!(c::AbstractConnection, e::Auth)
    # blacklist
    ip::String = get_ip(c)
    if ip in e.blacklist
        route_403(c, "You have been blacklisted from this webpage.")
        return(false)
    end
    if ~(ip in e.clients)
        key::String = gen_ref(10)
        newc::Client = Client(key, ip, 0, Dict{String, Any}())
        push!(e.clients, newc)
    end
    cl::Client = e.clients[get_ip(c)]
    args::Dict{Symbol, <:Any} = get_args(c)
    if :key in keys(args)
        if args[:key] == cl.key
            route!(c, c.routes)
        else
            route_403(c, "Auth key does not match. Packet intercepted?")
        end
        return(false)::Bool
    end
    
end

function route_403(c::AbstractConnection, message::String)
        if "403" in c.routes
            route!(c, c.routes["403"])
        else
            respond!(c, 403, message)
        end
end

authenticated(c::AbstractConnection, cm::ComponentModifier) = cm["private-key"]["text"] == c[:clients][get_ip(c)]