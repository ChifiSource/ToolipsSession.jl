mutable struct Auth{T <: Any} <: Toolips.AbstractExtension
    blacklist::Vector{String}
    keys::Dict{String, T}
    client_count::Int64
    data::Dict{T, Dict{String, <:Any}}
    Auth{T}(config_path::String) where {T <: Any} = begin
        cfg::String = read(config_path, String)
    end
    Auth{T}(blacklist::Vector{String}) where {T <: Any} = begin

    end
end

Auth(config_path::String; args ...) = Auth{Toolips.IP4}(config_path::String; args ...)

on_start(ext::Auth{Toolips.IP4}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute}) = begin
    push!(data, :users => ext.data, :banned => ext.blacklist, :clients => ext.client_count)
end

function route!(c::AbstractConnection, e::Auth{Toolips.IP4})
    # blacklist
    ip::String = get_ip(c)
    if ip in e.blacklist
        if "403" in c.routes
            route!(c, c.routes["403"])
        else
            respond!(c, 403, "You have been blacklisted from this webpage.")
        end
        return(false)
    end
    e.client_count += 1
    if ~(get_ip(c)) in keys(e.keys)
        
    end
end