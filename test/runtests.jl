using Test
using ToolipsSession

module SessionSampleServer
using Test
using ToolipsSession.Toolips
using ToolipsSession.Toolips.Components
using ToolipsSession

auth = Auth()
session = Session()

on(session, "event") do cm::ComponentModifier
    alert!(cm, "hello")
end

home_init = route("/") do c::AbstractConnection
    authenticate!(c)
    onran = false
    testcomp = body("testcomp")
    @testset "unauthenticated response" verbose = true begin
        try
            on("event", c, "click")
            on("event", c, testcomp, "click")
            onran = true
        catch
            
        end
        @testset "global bindings" begin
            @test onran == true
        end
        onran = false
        try
            on(c, "click") do cm::ComponentModifier
                alert!(cm, "hi")
            end
            on(c, testcomp, "click")
            onran = true
        catch
            
        end
        @testset ""
    end

end

text_auth = route("/") do c::ToolipsSession.AuthenticatedConnection
    write!(c, "authenticated")
end

export session, auth
end

@testset "Toolips Session 0.4" verbose = true begin
    @testset "Session base" begin

    end
    @testset "Auth base" begin

    end
    @testset "event request" begin

    end
    @testset "authenticated request" begin

    end
end