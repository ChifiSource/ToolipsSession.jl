"""
#### OliveHighlighters
- Created in March, 2025 by [chifi](https://github.com/orgs/ChifiSource)
- This software is MIT-licensed.

`OliveHighlighters` is a `ToolipsServables`-based highlighting system created 
primarily with the intention of serving the `Olive` parametric notebook 
editor. This package explicitly provides clean, in-line stylized output and 
declarative syntax in the hopes that this might make it easier for the future 
language and syntax specifications to be implemeneted within `Olive`.
Needless to say, this project turns out to also be useful in a variety of other 
contexts.

Usage revolves primarily around the `Highlighter` or `TextStyleModifier`. 
These are loaded with styles, and then sent through marking functions to 
create the highlighting system.
```example
using OliveHighlighters

tm = TextStyleModifier("function example(x::Any = 5) end")

OliveHighlighters.julia_block!(tm)

style!(tm, :default, "color" => "#333333")

display("text/html", string(tm))

# reloading, the styles will be saved -- we call `mark_julia!` instead of `julia_block!`.
set_text!(tm, "function sample end")

OliveHighlighters.mark_julia!(tm)

OliveHighlighters.mark_all(tm, "sample", :sample)

style!(tm, :sample, "color" => "red")

display("text/html", string(tm))
```
##### provides
- **Base**
- `TextModifier`
- `TextStyleModifier`
- `Highlighter`
- `classes`
- `remove!`
- `set_text!`
- `clear!`
- `style!(tm::TextStyleModifier, marks::Symbol, sty::Pair{String, String} ...)`
- `style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}}) = push!(tm.styles, marks => sty)`
- `string(tm::TextStyleModifier; args ...)`
- **marking functions**
- `mark_all!(tm::TextModifier, s::String, label::Symbol)`
- `mark_all!(tm::TextModifier, c::Char, label::Symbol)`
- `mark_between!(tm::TextModifier, s::String, label::Symbol)`
- `mark_between!(tm::TextModifier, s::String, s2::String, label::Symbol)`
- `mark_before!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0,
    includedims_r::Int64 = 0)`
- `mark_after!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_r::Int64 = 0,
    includedims_l::Int64 = 0)`
- `mark_inside!(f::Function, tm::TextModifier, label::Symbol)`
- `mark_for!(tm::TextModifier, ch::String, f::Int64, label::Symbol)`
- `mark_line_after!(tm::TextModifier, ch::String, label::Symbol) = mark_between!(tm, ch, "\n", label)`
- **included highlighters**
- `mark_julia!(tm::TextModifier)`
- `style_julia!(tm::TextStyleModifier)`
- `julia_block!(tm::TextStyleModifier)`
- `mark_markdown!(tm::OliveHighlighters.TextModifier)`
- `style_markdown!(tm::OliveHighlighters.TextStyleModifier)`
- `mark_toml!(tm::OliveHighlighters.TextModifier)`
- `style_toml!(tm::OliveHighlighters.TextStyleModifier)`
- **internal**
- `rep_str`
"""
module OliveHighlighters
using ToolipsServables
import ToolipsServables: Modifier, String, AbstractComponent, set_text!, push!, style!, string, set_text!, remove!

const repeat_offenders = ('\n', ' ', ',', '(', ')', ';', '\"', ']', '[')

rep_str(s::String) = replace(s, " "  => "&nbsp;",
"\n"  =>  "<br>", "\\" => "&bsol;", "&#61;" => "=")

"""
```julia
abstract TextModifier <: ToolipsServables.Modifier
```
TextModifiers are modifiers that change outgoing text into different forms,
whether this be in servables or web-formatted strings. These are unique in that
they can be provided to `itmd` (`0.1.3`+) in order to create interpolated tmd
blocks, or just handle these things on their own.
```julia
# consistencies
raw::String
marks::Dict{UnitRange{Int64}, Symbol}
```
- See also: `TextStyleModifier`, `mark_all!`, `julia_block!`
"""
abstract type TextModifier <: Modifier end

"""
```julia
TextStyleModifier <: TextModifier
```
- raw**::String**
- taken**::Vector{Int64}**
- marks**::Dict{UnitRange{Int64}, Symbol}**
- styles**::Dict{Symbol, Vector{Pair{String, String}}}**

The `TextStyleModifier` is used to lex text and change its style. This `Modifier` is passed through a mutating function, for example 
`mark_all!`. `mark_all!` will mark all of the positions with the symbols we provide, then we use `ToolipsServables.style!(tm, ::Symbol, pairs ...)` to style 
those marks. These can be listed with `OliveHighlighters.classes` and removed with `ToolipsServables.remove!`. The `TextStyleModifier` is also aliased as 
`Highlighter`, and this type is exported whereas `TextStyleModifier` is not.

`OliveHighlighters` provides some pre-built highlighters:
- `mark_toml!`
- `toml_style!`
- `mark_markdown!`
- `markdown_style!`
- `style_julia!`
- `mark_julia!`
- `julia_block!` < combines highlight and mark for Julia.
The `TextStyleModifier`'s marks are cleared with `clear!`, but are also removed when the
text is set with `set_text!`. To get the final result, simply call 
`string` on the `TextStyleModifier`.
```julia
TextStyleModifier(::String = "")
```
example
```julia
using OliveHighlighters

tm = TextStyleModifier("function example(x::Any = 5) end")

OliveHighlighters.julia_block!(tm)

style!(tm, :default, "color" => "#333333")

display("text/html", string(tm))

# reloading
set_text!(tm, "function sample end")

OliveHighlighters.mark_julia!(tm)

OliveHighlighters.mark_all(tm, "sample", :sample)
style!(tm, :sample, "color" => "red")
display("text/html", string(tm))
```
- See also: `classes`, `set_text!`, `julia_block!`, `mark_between!`
"""
mutable struct TextStyleModifier <: TextModifier
    raw::String
    taken::Vector{Int64}
    marks::Dict{UnitRange{Int64}, Symbol}
    styles::Dict{Symbol, Vector{Pair{String, String}}}
    function TextStyleModifier(raw::String = "")
        marks = Dict{Symbol, UnitRange{Int64}}()
        styles = Dict{Symbol, Vector{Pair{String, String}}}()
        new(ToolipsServables.rep_in(raw), Vector{Int64}(), marks, styles)
    end
end

const Highlighter = TextStyleModifier

"""
```julia
classes(tm::TextStyleModifier) -> Base.Generator
```
Returns a `Tuple` generator for the classes currently styled in the `TextStyleModifier`. This 
    is equivalent of getting the keys of the `styles` field. `remove!` can also be used to remove classes. 
    (To allocate the generator simply provide it to a `Vector`)
```julia
using OliveHighlighters; TextStyleModifier, style_julia!
tm = TextStyleModifier("")
style_julia!(tm)

classes(tm)

# allocated:
my_classes = [classes(tm) ...]
```
- See also: `set_text!`, `TextStyleModifier`, `clear!`, `remove!(tm::TextStyleModifier, key::Symbol)`
"""
classes(tm::TextStyleModifier) = (key for key in keys(tm.styles))

"""
```julia
remove!(tm::TextStyleModifier, key::Symbol)
```
Removes a given style string from a `TextStyleModifier`
```julia
using OliveHighlighters; TextStyleModifier, style_julia!
tm = TextStyleModifier("")
style_julia!(tm)

# check classes:
classes(tm)

# remove class:
remove!(tm, :default)
```
- See also: `set_text!`, `TextStyleModifier`, `clear!`
"""
remove!(tm::TextStyleModifier, key::Symbol) = delete!(tm.styles, key)

"""
```julia
set_text!(tm::TextStyleModifier, s::String) -> ::String
```
Sets the text of a `TextStyleModifier`. This is an extra-convenient function, 
it calls `rep_in` -- an internal function used to replace client-side characters -- and 
sets the result as the text of `TextStyleModifier`, then it makes a call to `clear!` to clear the 
current marks. This allows for the same highlighters with the same styles to be used with new text.
```julia
using OliveHighlighters
my_tm = Highlighter("function example() end")

OliveHighlighters.julia_block!(my_tm)

that_code = string(my_tm)

OliveHighlighters.set_text!(my_tm, "arg::Int64 = 5")

# julia_block! includes highlights, because we used `set_text!` we can remark the same highlighter:
OliveHighlighters.mark_julia!(my_tm)

new_code = string(my_tm)
```
- See also: `clear!`, `Highlighter`, `classes`
"""
set_text!(tm::TextModifier, s::String) = begin 
    tm.raw = ToolipsServables.rep_in(s)
    clear!(tm)
    nothing::Nothing
end

"""
```julia
clear!(tm::TextStyleModifier) -> ::Nothing
```
`clear!` is used to remove the current set of `marks` from a `TextStyleModifier`. 
This will allow for new marks to be loaded with a fresh call to a marking function. This 
    function is automatically called by `set_text!`, so unless we want to clear the marks without 
    changing the text, that would be the more convenient function to call.
```julia
using OliveHighlighters
my_tm = Highlighter("function example() end")

OliveHighlighters.julia_block!(my_tm)

that_code = string(my_tm)

# avoiding `set_text!`
OliveHighlighters.clear!(my_tm)
my_tm.raw = "function sample()\\n x = 5 \\nend"

# julia_block! includes highlights, because we used `set_text!` we can remark the same highlighter:
OliveHighlighters.mark_julia!(my_tm)

new_code = string(my_tm)
```
- See also: `set_text!`, `style!`
"""
clear!(tm::TextStyleModifier) = begin
    tm.marks = Dict{UnitRange{Int64}, Symbol}()
    tm.taken = Vector{Int64}()
    nothing::Nothing
end

function push!(tm::TextStyleModifier, p::Pair{UnitRange{Int64}, Symbol})
    r = p[1]
    found = findfirst(mark -> mark in r, tm.taken)
    if isnothing(found)
        push!(tm.marks, p)
        vecp = Vector(p[1])
        tm.taken = vcat(tm.taken, vecp)
        return
    end
    nothing::Nothing
end

function push!(tm::TextStyleModifier, p::Pair{Int64, Symbol})
    if ~(p[1] in tm.taken)
        push!(tm.marks, p[1]:p[1] => p[2])
        push!(tm.taken, p[1])
    end
    nothing::Nothing
end

"""
```julia
style!(tm::TextStyleModifier, marks::Symbol, sty::Pair{String, String} ...) -> ::Nothing
style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}}) -> ::Nothing
```
These `style!` bindings belong to `OliveHighlighters`.These will set the style for a particular class on a `TextStyleModifier` to `sty`.
```julia
using OliveHighlighters

sample_str = "[key]"

hl = Highlighter(sample_str)

style!(hl, :key, "color" => "blue")

mark_between!(hl, "[", "]", :key)

string(hl)
```
- See also: `mark_all!`, `string(::TextStyleModifier)`, `clear!`, `set_text!`
"""
function style!(tm::TextStyleModifier, marks::Symbol, sty::Pair{String, String} ...)
    style!(tm, marks, [sty ...])
end

style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}}) = push!(tm.styles, marks => sty)


"""
```julia
mark_all!(tm::TextModifier, ...) -> ::Nothing
```
`mark_all!` marks every instance of a certain sequence in `tm.raw` with the style provided in `label`.
```julia
# mark all (`String`)
mark_all!(tm::TextModifier, s::String, label::Symbol) -> ::Nothing
# mark all (`Char`)
mark_all!(tm::TextModifier, c::Char, label::Symbol) -> ::Nothing
```
```julia
using OliveHighlighters

sample_str = "function example end mutable struct end"

hl = Highlighter(sample_str)

style!(hl, :end, "color" => "darkred")

mark_all!(hl, "end", :end)

string(hl)
```
- See also: `mark_between!`, `mark_before!`, `mark_after!`
"""
function mark_all!(tm::TextModifier, s::String, label::Symbol)
    for v in findall(s, tm.raw)
        valmax, n = maximum(v), length(tm.raw)
        if valmax == n && minimum(v) == 1
            push!(tm, v => label)
        elseif valmax == n
            if tm.raw[v[1] - 1] in repeat_offenders
                push!(tm, v => label)
            end
        elseif minimum(v) == 1
            if tm.raw[valmax + 1] in repeat_offenders
                push!(tm, v => label)
            end
        else
            if n < valmax
                continue
            end
            if tm.raw[v[1] - 1] in repeat_offenders && tm.raw[valmax + 1] in repeat_offenders
                push!(tm, v => label)
            end
        end
     end
    nothing::Nothing
end


function mark_all!(tm::TextModifier, c::Char, label::Symbol)
    for v in findall(c, tm.raw)
        push!(tm, v => label)
    end
    nothing::Nothing
end

"""
```julia
mark_between!(tm::TextModifier, s::String, ...) -> ::Nothing
```
`mark_between!` marks between the provided `String` or `String`s.
```julia
# mark between duplicates of the same character:
mark_between!(tm::TextModifier, s::String, label::Symbol)
# mark between two different characters
mark_between!(tm::TextModifier, s::String, s2::String, label::Symbol)
```
```julia
using OliveHighlighters

sample_str = "[key]"

hl = Highlighter(sample_str)

style!(hl, :key, "color" => "blue")

mark_between!(hl, "[", "]", :key)

string(hl)
```
- See also: `TextStyleModifier`, `mark_all!`, `julia_block!`, `clear!`
"""
function mark_between!(tm::TextModifier, s::String, label::Symbol)
	positions::Vector{UnitRange{Int64}} = findall(s, tm.raw)
	for pos in positions
		nd = findnext(s, tm.raw, maximum(pos) + 1)
		if nd !== nothing
			push!(tm, minimum(pos):maximum(nd) => label)
		else
			push!(tm, minimum(pos):length(tm.raw) => label)
		end
	end
	nothing
end

function mark_between!(tm::TextModifier, s::String, s2::String, label::Symbol)
	positions::Vector{UnitRange{Int64}} = findall(s, tm.raw)
	for pos in positions
		nd = findnext(s2, tm.raw, maximum(pos) + 1)
		if nd !== nothing
			push!(tm, minimum(pos):maximum(nd) => label)
		else
			push!(tm, minimum(pos):length(tm.raw) => label)
		end
	end
	nothing
end


"""
```julia
mark_before!(tm::TextModifier, s::String, label::Symbol; until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0, 
includedims_r::Int64 = 0) -> ::Nothing
```
`mark_before` will mark the values before a label -- a good example of this is a `Function`, we would `mark_before` the parenthesis, 
`until` a space or new line. `includedims` will include that number of characters before and after what you want to include -- for example, 
for a multi-line string we would set this to 3 (if we wanted to use `mark_before!` for that.) In most cases, this argument won't be used.
```julia
mark_julia!(tm::TextModifier) = begin
    tm.raw = replace(tm.raw, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ")
    # comments
    mark_between!(tm, "#=", "=#", :comment)
    mark_line_after!(tm, "#", :comment)
    # strings + string interpolation
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
    # functions

    mark_before!(tm, "(", :funcn, until = UNTILS)
    ...
```
- See also: `TextStyleModifier`, `mark_between!`, `mark_all!`, `clear!`, `set_text!`
"""
function mark_before!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = repeat_offenders, includedims_l::Int64 = 0,
    includedims_r::Int64 = 0)
    
    chars = findall(s, tm.raw)

    for labelrange in chars
        start_idx = labelrange[1]

        # Find the previous space
        previous = findprev(isequal(' '), tm.raw, start_idx)
        previous = isnothing(previous) ? 1 : previous[1]  # Ensure it's an index

        # If we have "until" delimiters, find the closest one
        if !isempty(until)
            prev_positions = Int[]
            for d in until
                point = findprev(d, tm.raw, start_idx - 1)
                if !isnothing(point)
                    push!(prev_positions, point[1] + lastindex(d))
                else
                    push!(prev_positions, 1)
                end
            end
            previous = maximum(prev_positions)
        end

        # Define the marking range correctly
        pos = (previous - includedims_l):(maximum(labelrange) - 1 + includedims_r)
        if length(pos)  == 0
            continue
        end
        push!(tm, pos => label)
    end

    return nothing
end


"""
```julia
mark_after!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_r::Int64 = 0,
    includedims_l::Int64 = 0) -> ::Nothing
```
Marks after `s` for every occurance of `s` in tm.raw. For example, for type annotations we could mark after `::` until 
    space or `\\n`. `includedims` will include that number of characters before and after what you want to include -- for example, 
for a multi-line string we would set this to 3 (if we wanted to use `mark_before!` for that.) In most cases, this argument won't be used.
```julia
# this is the function used to mark types in the Julia highlighter, for example:
mark_julia!(tm::TextModifier) = begin
    tm.raw = replace(tm.raw, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ")
    # comments
    mark_between!(tm, "#=", "=#", :comment)
    mark_line_after!(tm, "#", :comment)
    # strings + string interpolation
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
    # functions

    mark_before!(tm, "(", :funcn, until = UNTILS)
    # type annotations
    mark_after!(tm, "::", :type, until = UNTILS)
 #   ....
```
- See also: `TextStyleModifier`, `mark_between!`, `mark_all!`, `clear!`, `set_text!`
"""
function mark_after!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0,
    includedims_r::Int64 = 0)
    chars = findall(s, tm.raw)
    for labelrange in chars
        ending = findnext(" ", tm.raw, labelrange[end])
        if isnothing(ending)
            ending = length(tm.raw)
        else
            ending = ending[1]
        end
        
        if length(until) > 0
            lens = [begin
                        point = findnext(d, tm.raw, maximum(labelrange) + 1)
                        if ~(isnothing(point))
                            maximum(point) - 1
                        else
                            length(tm.raw)
                        end
                    end for d in until]
            ending = minimum(lens)
        end
        pos = (minimum(labelrange) - includedims_l):(ending - includedims_r)
        push!(tm, pos => label)
    end
    
    nothing::Nothing
end

"""
```julia
mark_inside!(f::Function, tm::TextModifier, label::Symbol) -> ::Nothing
```
For every occurance of `label`, we will open `f` and pass a new `TextStyleModifier` through it. 
This will highlight the inside of the label. In the Julia example, this is used to highlight 
the inside of string interpolators.
The new `TextStyleModifier` will be passed the styles from the provided `TextStyleModifier`.
```julia
# julia string interpolation highlighting:
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
```
- See also: mark_after!, clear!, `mark_for!`, `string(::TextStyleModifier)`, `julia_block!`
"""
function mark_inside!(f::Function, tm::TextModifier, label::Symbol)
    only_these_marks = filter(mark -> mark[2] == label, tm.marks)
    for key in keys(only_these_marks)
        # Create a new TextModifier for the subrange and apply the function
        new_tm = TextStyleModifier(tm.raw[key])
        new_tm.styles = tm.styles
        f(new_tm)
        base_pos = minimum(key)
        lendiff = base_pos - 1
        new_marks = Dict(
            (minimum(range) + lendiff):(maximum(range) + lendiff) => lbl
            for (range, lbl) in new_tm.marks
        )
        sortedmarks = sort(collect(new_marks), by=x -> x[1])
        final_marks = Vector{Pair{UnitRange{Int64}, Symbol}}()
        at_mark = 1
        n = length(sortedmarks)
        kmax = maximum(key)
        # Process the marks and avoid duplicates
        while true
            if at_mark > n || n == 0
                # Push remaining range up to kmax, if any
                if base_pos <= kmax
                    push!(final_marks, base_pos:kmax => label)
                end
                break
            end
            this_mark = sortedmarks[at_mark]
            new_min = minimum(this_mark[1])
            # Add range from base_pos to the start of this_mark, if non-empty
            if base_pos < new_min
                push!(final_marks, base_pos:(new_min - 1) => label)
            end

            # Add the current mark and update base_pos to its end
            push!(final_marks, this_mark[1] => this_mark[2])
            base_pos = maximum(this_mark[1]) + 1

            at_mark += 1
        end
        delete!(tm.marks, key)
        push!(tm.marks, final_marks...)
    end
    nothing::Nothing
end

"""
```julia
mark_for!(tm::TextModifier, ch::String, f::Int64, label::Symbol) -> ::Nothing
```
Marks beyond the characters `ch` for `f` bytes as `label`.
```julia
using OliveHighlighters

tm = Highlighter("sample \\n")

mark_for!(tm, "\\", 1, :exit)
style!(tm, :exit, "color" => "lightblue")

string(tm)
```
- See also: `mark_line_after!`, `mark_julia!`, `string(::TextStyleModifier)`
"""
function mark_for!(tm::TextModifier, ch::String, f::Int64, label::Symbol)
    if length(tm.raw) == 1
        return
    end
    chars = findall(ch, tm.raw)
    for pos in chars
        if ~(length(findall(i -> length(findall(n -> n in i, pos)) > 0,
            collect(keys(tm.marks)))) > 0)
            push!(tm.marks, minimum(pos):maximum(pos) + f => label)
        end
    end
    nothing::Nothing
end

"""
```julia
mark_line_after!(tm::TextModifier, ch::String, label::Symbol) -> ::Nothing
```
Marks the line after a certain `String` with the `Symbol` `label` in `tm.marks`.
```julia
using OliveHighlighters

julia_code = "julia"
tm = Highlighter(julia_code)

mark_line_after!(tm, "#", :comment)

style!(tm, :comment, "color" => "gray", "font-weight" => "bold")
string(tm)
```
- See also: `mark_line_after!`, `mark_for!`
"""
mark_line_after!(tm::TextModifier, ch::String, label::Symbol) = mark_between!(tm, ch, "\n", label)

OPS::Vector{SubString} = split("""<: = == < > => -> || -= += + / * - ~ <= >= &&""", " ")
UNTILS::Vector{String} = [" ", ",", ")", "\n", "<br>", "&nbsp;", ";", "(", "{", "}"]

"""
```julia
mark_julia!(tm::TextModifier) -> ::Nothing
```
Performs the marking portion of highlighting for Julia code.
```julia
using OliveHighlighters

lighter = Highlighter("function example(x::Any)\\nend")

# calls `mark_julia!` and `style_julia!`
OliveHighlighters.julia_block!(lighter)

# clears marks from `mark_julia` using `clear!` and updates `lighter.raw`
set_text!(lighter, "struct Example\\nfield::Any\\nend")

OliveHighlighters.mark_julia!(lighter)
```
- See also: `mark_line_after!`, `style_julia!`, `mark_between!`, `TextStyleModifier`
"""
mark_julia!(tm::TextModifier) = begin
    tm.raw = replace(tm.raw, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ")
    # comments
    mark_between!(tm, "#=", "=#", :comment)
    
    # strings + string interpolation
    mark_between!(tm, "\"\"\"", :string)
    mark_line_after!(tm, "#", :comment)
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
    mark_between!(tm, "'", :char)
    # functions
    mark_after!(tm, "::", :type, until = UNTILS)
    mark_before!(tm, "(", :funcn, until = UNTILS)
    mark_between!(tm, "{", "}", :params)
    mark_before!(tm, "{", :type, until = UNTILS)
    # type annotations
    # macros
    mark_after!(tm, "@", :macro, until = UNTILS)
    
    # keywords
    mark_all!(tm, "function", :func)
    mark_all!(tm, "import", :import)
    mark_all!(tm, "using", :using)
    mark_all!(tm, "end", :end)
    mark_all!(tm, "struct", :struct)
    mark_all!(tm, "const", :using)
    mark_all!(tm, "global", :global)
    mark_all!(tm, "abstract", :abstract)
    mark_all!(tm, "mutable", :mutable)
    mark_all!(tm, "if", :if)
    mark_all!(tm, "else", :if)
    mark_all!(tm, "elseif", :if)
    mark_all!(tm, "in", :in)
    mark_all!(tm, "export ", :using)
    mark_all!(tm, "try ", :if)
    mark_all!(tm, "catch ", :if)
    mark_all!(tm, "elseif", :if)
    mark_all!(tm, "for", :for)
    mark_all!(tm, "while", :for)
    mark_all!(tm, "quote", :for)
    mark_all!(tm, "begin", :begin)
    mark_all!(tm, "module", :module)
    # math
    for dig in digits(1234567890)
        mark_all!(tm, Char('0' + dig), :number)
    end
    mark_all!(tm, "true", :number)
    mark_all!(tm, "false", :number)
    for op in OPS
        mark_all!(tm, string(op), :op)
    end
    mark_between!(tm, "#=", "=#", :comment)
    nothing::Nothing
end

"""
```julia
style_julia!(tm::TextStyleModifier) -> ::Nothing
```
Performs the styling for a Julia highlighter. Note this function only needs to be called once on 
    a given highlighter; after styled, we can use `set_text!`
```julia
using OliveHighlighters

lighter = Highlighter("function example(x::Any)\\nend")

# mark and style separately, these are also combined into `julia_block!`

OliveHighlighters.mark_julia!(lighter)
OliveHighlighters.style_julia!(lighter)

my_result::String = string(lighter)
```
- See also: `mark_line_after!`, `style_julia!`, `mark_between!`, `TextStyleModifier`
"""
style_julia!(tm::TextStyleModifier) = begin
    style!(tm, :default, ["color" => "#3D3D3D"])
    style!(tm, :func, ["color" => "#944d94"])
    style!(tm, :funcn, ["color" => "#2d65a8"])
    style!(tm, :using, ["color" => "#006C67"])
    style!(tm, :import, ["color" => "#fc038c"])
    style!(tm, :end, ["color" => "#b81870"])
    style!(tm, :mutable, ["color" => "#a82d38"])
    style!(tm, :struct, ["color" => "#944d94"])
    style!(tm, :begin, ["color" => "#a82d38"])
    style!(tm, :module, ["color" => "#b81870"])
    style!(tm, :string, ["color" => "#4e944d"])
    style!(tm, :if, ["color" => "#944d94"])
    style!(tm, :for, ["color" => "#944d94"])
    style!(tm, :in, ["color" => "#006C67"])
    style!(tm, :abstract, ["color" => "#a82d38"])
    style!(tm, :number, ["color" => "#8b0000"])
    style!(tm, :char, ["color" => "#8b0000"])
    style!(tm, :type, ["color" => "#D67229"])
    style!(tm, :exit, ["color" => "#cc0099"])
    style!(tm, :op, ["color" => "#0C023E"])
    style!(tm, :macro, ["color" => "#43B3AE"])
    style!(tm, :params, ["color" => "#00008B"])
    style!(tm, :comment, ["color" => "#808080"])
    style!(tm, :interp, ["color" => "#420000"])
    style!(tm, :global, ["color" => "#ff0066"])
    nothing::Nothing
end

"""
```julia
julia_block!(tm::TextStyleModifier) -> ::Nothing
```
Calls both `style_julia!` and `mark_julia!` in order to turn a loaded `TextStyleModifier` 
straight into highlighted Julia.
```julia
using OliveHighlighters

lighter = Highlighter("function example(x::Any)\\nend")

# calls `mark_julia!` and `style_julia!`
OliveHighlighters.julia_block!(lighter)

# clears marks from `mark_julia` using `clear!` and updates `lighter.raw`
set_text!(lighter, "struct Example\\nfield::Any\\nend")

OliveHighlighters.mark_julia!(lighter)
```
- See also: `mark_line_after!`, `style_julia!`, `mark_julia!`, `Highlighter`, `mark_julia`, `set_text!`
"""
function julia_block!(tm::TextStyleModifier)
    mark_julia!(tm)
    style_julia!(tm)
end

"""
```julia
mark_markdown!(tm::OliveHighlighters.TextModifier) -> ::Nothing
```
Marks markdown highlights to `tm.marks`. `mark_julia!`, but for markdown.
```julia
using OliveHighlighters

md_hl = Highlighter()

OliveHighlighters.style_markdown!(md_hl)

set_text!(md_hl, "[key] = false")

OliveHighlighters.mark_markdown!(md_hl)

result::String = string(md_hl)
```
- See also: `mark_line_after!`, `style_markdown!`, `mark_julia!`, `TextStyleModifier`
"""
function mark_markdown!(tm::OliveHighlighters.TextModifier)
    OliveHighlighters.mark_after!(tm, "# ", until = ["\n"], :heading)
    OliveHighlighters.mark_between!(tm, "[", "]", :keys)
    OliveHighlighters.mark_between!(tm, "(", ")", :link)
    OliveHighlighters.mark_between!(tm, "**", :bold)
    OliveHighlighters.mark_between!(tm, "*", :italic)
    OliveHighlighters.mark_between!(tm, "``", :code)
    nothing::Nothing
end

"""
```julia
style_markdown!(tm::OliveHighlighters.TextModifier) -> ::Nothing
```
Adds markdown marking styles to `tm`.
```julia
using OliveHighlighters

md_hl = Highlighter()

OliveHighlighters.style_markdown!(md_hl)

set_text!(md_hl, "[key] = false")

OliveHighlighters.mark_markdown!(md_hl)

result::String = string(md_hl)
```
- See also: `mark_line_after!`, `mark_markdown!`, `mark_julia!`, `TextStyleModifier`
"""
function style_markdown!(tm::OliveHighlighters.TextStyleModifier)
    style!(tm, :link, ["color" => "#D67229"])
    style!(tm, :heading, ["color" => "#1f0c2e"])
    style!(tm, :bold, ["color" => "#0f1e73"])
    style!(tm, :italic, ["color" => "#8b0000"])
    style!(tm, :keys, ["color" => "#ffc000"])
    style!(tm, :code, ["color" => "#8b0000"])
    style!(tm, :default, ["color" => "#1c0906"])
    style!(tm, :link, ["color" => "#8b0000"])
end

"""
```julia
mark_toml!(tm::OliveHighlighters.TextModifier) -> ::Nothing
```
Marks all of the characters to highlight inside of raw TOML loaded into `tm.raw`.
```julia
using OliveHighlighters

toml_hl = Highlighter()

OliveHighlighters.style_toml!(toml_hl)

set_text!(toml_hl, "[key] = false")

OliveHighlighters.mark_toml!(toml_hl)

result::String = string(toml_hl)
```
- See also: `TextStyleModifier`, `style_toml!`, `clear!`, `set_text!`
"""
function mark_toml!(tm::OliveHighlighters.TextModifier)
    OliveHighlighters.mark_between!(tm, "[", "]", :keys)
    OliveHighlighters.mark_between!(tm, "\"", :string)
    OliveHighlighters.mark_all!(tm, "=", :equals)
    for dig in digits(1234567890)
        OliveHighlighters.mark_all!(tm, string(dig), :number)
    end
end

"""
```julia
style_toml!(tm::OliveHighlighters.TextStyleModifier) -> ::Nothing
```
Styles the default styles for a `TOML` highlighter.
```julia
using OliveHighlighters

toml_hl = Highlighter()

OliveHighlighters.style_toml!(toml_hl)

set_text!(toml_hl, "[key] = false")

OliveHighlighters.mark_toml!(toml_hl)

result::String = string(toml_hl)
```
- See also: `TextStyleModifier`, `style_toml!`, `clear!`, `set_text!`
"""
function style_toml!(tm::OliveHighlighters.TextStyleModifier)
    style!(tm, :keys, ["color" => "#D67229"])
    style!(tm, :equals, ["color" => "#1f0c2e"])
    style!(tm, :string, ["color" => "#4e944d"])
    style!(tm, :default, ["color" => "#2d65a8"])
    style!(tm, :number, ["color" => "#8b0000"])
end

"""
```julia
# (this binding is from `OliveHighlighters`)
Base.string(tm::TextStyleModifier; args ...) -> ::String
```
This binding turns a `TextStyleModifier`'s text into a highlighted HTML 
result with inline styles. Make sure to *mark* **and** *style* the 
`TextStyleModifier` **before** sending it through this function. 
`args` allows us to provide key-word arguments to the current elements, 
for example we could use this to set the `class`.
```julia
using OliveHighlighters

tm = TextStyleModifier("function example(x::Any = 5) end")

OliveHighlighters.julia_block!(tm)

style!(tm, :default, "color" => "#333333")

display("text/html", string(tm))

# reloading
set_text!(tm, "function sample end")

OliveHighlighters.mark_julia!(tm)

OliveHighlighters.mark_all(tm, "sample", :sample)
style!(tm, :sample, "color" => "red")
display("text/html", string(tm))
```
- See also: `TextStyleModifier`, `style_toml!`, `clear!`, `set_text!`
"""
function string(tm::TextStyleModifier; args ...)
    filter!(mark -> ~(length(mark[1]) < 1), tm.marks)
    sortedmarks = sort(collect(tm.marks), by=x->x[1])
    n::Int64 = length(sortedmarks)
    if n == 0
        txt = a("-", text = rep_str(tm.raw); args ...)
        style!(txt, tm.styles[:default] ...)
        return(string(txt))::String
    end
    at_mark::Int64 = 1
    output::String = ""
    mark_start::Int64 = minimum(sortedmarks[1][1])
    if mark_start > 1
        txt = span("-", text = rep_str(tm.raw[1: mark_start - 1]);  args ...)
        style!(txt, tm.styles[:default] ...)
        output = string(txt)
    end
    while true
        mark = sortedmarks[at_mark][1]
        if at_mark != 1
            last_mark = sortedmarks[at_mark - 1][1]
            lastmax = maximum(last_mark)
            if minimum(mark) - lastmax > 0
                txt = span("-", text = rep_str(tm.raw[lastmax + 1:minimum(mark) - 1]); args ...)
                style!(txt, tm.styles[:default] ...)
                output = output * string(txt)
            end
        end
        styname = sortedmarks[at_mark][2]
        try
            txt = span("-", text = rep_str(tm.raw[mark]); args ...)
        catch e
            @warn "error with text: " * tm.raw
            @warn "positions: $mark"
            @warn "mark: $styname"
            throw(e)
        end
        if styname in keys(tm.styles)
            style!(txt, tm.styles[styname] ...)
        else
            style!(txt, tm.styles[:default] ...)
        end
        output = output * string(txt)
        if at_mark == n
            if maximum(mark) != length(tm.raw)
                txt = span("-", text = rep_str(tm.raw[maximum(mark) + 1:length(tm.raw)]); args ...)
                style!(txt, tm.styles[:default] ...)
                output = output * string(txt)
            end
            break
        end
        at_mark += 1
    end
    output::String
end

export Highlighter, clear!, set_text!, classes, style!, remove!
end # module OliveHighlighters
