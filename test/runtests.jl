using Test
using ToolipsSession

module SessionSampleServer
using Test
using ToolipsSession.Toolips
using ToolipsSession.Toolips.Components
using ToolipsSession

auth = ToolipsSession.Auth()
session = Session(timeout = 1)

on(session, "event") do cm::ComponentModifier
    alert!(cm, "hello")
end

# hideous lol
home_init = route("/") do c::AbstractConnection
    onran = false
    testcomp = body("testcomp")
    @testset "unauthenticated response" verbose = true begin
        try
            on("event", c, "click")
            on("event", testcomp, "click")
            onran = true
        catch e
            throw(e)
        end
        @testset "`on` global bindings" begin
            @test onran == true
        end
        onran = false
        try
            on(c, "click") do cm::ComponentModifier
                alert!(cm, "hi")
            end
            on(c, testcomp, "click", prevent_default = true) do cm::ComponentModifier

            end
            onran = true
        catch e
            throw(e)            
        end
        @testset "`on` response bindings" begin
            @test onran == true
        end
        try
            ToolipsSession.bind(c, "Enter") do cm::ComponentModifier
                alert!(cm, "hi")
            end
            ToolipsSession.bind(c, testcomp, "Enter", :ctrl) do cm::ComponentModifier
                alert!(cm, "hello")
            end
            onran = true
        catch e
            throw(e)            
        end
        @testset "`ToolipsServables.bind` response bindings" begin
            @test onran == true
        end
        on(c, "load") do cm::ComponentModifier
            onran = false
            try
                on(c, cm, "click") do cm::ComponentModifier
                    alert!(cm, "hi")
                end
                on(c, cm, testcomp, "click", prevent_default = true) do cm::ComponentModifier
    
                end
                onran = true
            catch e
                throw(e)
            end
            @testset "`on` callback bindings" begin
                @test onran == true
            end
            try
                ToolipsSession.bind(c, cm, "Enter") do cm::ComponentModifier
                    alert!(cm, "hi")
                end
                ToolipsSession.bind(c, cm, testcomp, "Enter", :ctrl) do cm::ComponentModifier
                    alert!(cm, "hello")
                end
                onran = true
            catch e
                throw(e)
            end
            @testset "`ToolipsServables.bind` callback bindings" begin
                @test onran == true
            end
        end
        write!(c, testcomp)
    end

end

text_auth = route("/") do c::ToolipsSession.AuthenticatedConnection
    write!(c, "authenticated")
end

authme = route("/authme") do c::AbstractConnection
    authorize!(c)
    write!(c, "user authorized")
end

mr = route(home_init, text_auth)
export session, auth, mr, authme
end

@testset "Toolips Session 0.4" verbose = true begin
    @testset "Session base" begin
        s = Session(["/", "/samplepage"], timeout = 1)
        @test length(s.active_routes) == 2
        on(s, "eve") do cm::ComponentModifier

        end
        @test length(keys(s.events)) == 1
    end
    @testset "Auth base" begin
        auth = ToolipsSession.Auth()
        @test typeof(auth) == ToolipsSession.Auth{ToolipsSession.Client}
    end
    ToolipsSession.Toolips.start!(SessionSampleServer, "127.0.0.1":8000)
    @testset "event request" begin
        resp = ""
        try
            resp = ToolipsSession.Toolips.get("http://127.0.0.1:8000/")
        catch
            resp = ToolipsSession.Toolips.get("http://127.0.0.1:8000/")
        end
        @test contains(resp, "GLOBAL")
        sess = SessionSampleServer.session
        f = findfirst(k -> k != "GLOBAL", sess.events)
        @test ~(isnothing(f))
        events = sess.events[f]
        @test length(events) > 1
        eventref = events[1].name
        @test contains(resp, eventref)
        @test contains(resp, "sendpage")
        p = ToolipsSession.Toolips.post("127.0.0.1":8000, "â•ƒCM$(eventref)â•ƒ<body id='hi'></body>")
        @test contains(p, ";")
    end
    get("http://127.0.0.1:8000/authme")
    @testset "authenticated request" begin
        req2 = ToolipsSession.Toolips.get("127.0.0.1":8000)
        @test contains(req2, "authenticated")
    end
    ToolipsSession.Toolips.kill!(SessionSampleServer)
end