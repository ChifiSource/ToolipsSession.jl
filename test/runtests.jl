using Test
using ToolipsSession

module SessionSampleServer
using Test
using ToolipsSession.Toolips
using ToolipsSession.Toolips.Components
using ToolipsSession

auth = Auth()
session = Session()
route("/") do c::AbstractConnection

end

export session, auth
end

@testset "Toolips Session 0.4" verbose = true begin
    @testset "Session base" begin

    end
    @testset "Auth base" begin

    end
    @testset ""
end