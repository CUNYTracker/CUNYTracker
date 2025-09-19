# create listing by topic
# call with julia by_topic.jl
module TrackerByTopic
using Markdown, DataFrames
f = "/tmp/ct.qmd"

function _mo_no(f)
    mos = Dict("jan"=>1, "feb" => 2, "mar" => 3, "apr"=>4,
               "may"=>5, "jun"=>6, "jul"=>7, "aug"=>8,
               "sep"=>9, "oct"=>10, "nov"=>11, "dec"=>12)
    isa(f, AbstractString) && return mos[f]
    if isa(f, Number)
        for (k,v) ∈ pairs(mos)
            v == f && return k
        end
    end
    return nothing
end

function get_date(f)

    f = replace(f, ".qmd"=>"")
    mo, dy... = split(f, "-") # naming convention mon-day-year
    dy = string.(dy)

    month = _mo_no(mo)
    if length(dy) == 1
        day = parse(Int, dy[1])
        year = 2025
    else
        day = parse(Int, dy[1])
        year = parse(Int, dy[2])
    end
    (; year, month, day)
end

function show_content(year, month, day, h1, h2, h3, item, urlio)
    url = String(take!(urlio))
    (;year, month, day, h1, h2, h3, item, url), IOBuffer()
end

function _content(i)
    i.content
end

function _content(i::Markdown.List)
    return [""]
#    return _content(i.items[1][1])
end


# parse and add to d (d = DataFrame())
function parse_file!(d, f)
    year, month, day = get_date(f)
    h1 = h2 = h3 = nothing
    item = nothing
    urlio = IOBuffer()

    o = open(f, "r") do io
        Markdown.parse(io)
    end

    for i in o.content
        if isa(i, Markdown.Header)
            ## print out current
            rec, urlio = show_content(year, month, day, h1, h2, h3, item, urlio)
            push!(d, rec; promote=true)
            item = nothing

            txt = strip(join(i.text, " "))
            if isa(i, Markdown.Header{1})
                h1 = txt
                h2 = h3 = nothing
            elseif isa(i, Markdown.Header{2})
                h2 = txt
                h3 = nothing
            elseif isa(i, Markdown.Header{3})
                h3 = txt
            end
            ## when do we write out a row? after items
        elseif isa(i, Markdown.List)
            rec, urlio = show_content(year, month, day, h1, h2, h3, item, urlio)
            push!(d, rec; promote=true)
            item = nothing
            if !isempty(i.items[1])
                item = strip(join(_content(i.items[1][1]), " "))
            end
        elseif isa(i, Markdown.Paragraph)
            for ii in i.content
                if isa(ii, Markdown.Link)
                    txt, url = ii.text, ii.url
                    txt = strip(join(txt, " "))
                    # adjust txt
                    i = findfirst('?', txt)
                    if !isnothing(i)
                        txt = txt[1:i-1]
                    end
                    println(urlio, "[$txt]($url)")
                end
            end
        end
    end
end

function parse_all(dir=".")
    fs = readdir(dir)
    fs = filter(endswith(".qmd"), fs)
    fs = filter(x -> !=(x, "index.qmd"), fs)
    fs = filter(x -> !=(x, "bytopic.qmd"), fs)

    d = DataFrame()
    for f in fs
        parse_file!(d, f)
    end

    subset!(d, :item => ByRow(!isnothing))
    sort(d, [:year, :month, :day]; rev=true)

end

function hierarchical(io::IO, d)
    h2s = unique(d.h2)
    h3s = unique(vcat(nothing, unique(d.h3)))
    for h2 ∈ h2s
        !isnothing(h2) && println(io, "## ", h2, "\n")
        for h3 ∈ h3s
            year′ = month′ = day′ = nothing

            di = subset(d, :h2 => ByRow(==(h2)), :h3 => ByRow(==(h3)))
            iszero(size(di)[1]) && continue

            !isnothing(h3) && println(io, "### ", h3, "\n")

            sort!(di, [:year, :month, :day]; rev=true)
            @show di

            for r in eachrow(di)
                (; year, month, day, item, url) = r
                isnothing(item) && continue
                isnothing(url) && continue
                if (year′, month′, day′) != (year, month, day)
                    year′, month′, day′ = year, month, day
                    println(io, "<i class='bi bi-calendar2-range'></i> [$month/$day/$year]($(_mo_no(month))-$day.qmd)", "\n\n")
           #         println(io, "**$month/$day/$year:**","\n\n")
                end
                println(io, "* $item", "\n")
                println(io, url, "\n")
            end
        end
    end
end

hierarchical(d) = sprint(io -> hierarchical(io, d))

end

using quarto_jll

function (@main)(args...)
    d = TrackerByTopic.parse_all()
    open("bytopic.qmd","w") do io
        println(io, """
---
title: List of article by topic
format:
  html:
    toc: true
---
""")
        TrackerByTopic.hierarchical(io, d)
    end
#    quarto() do bin
#        run(`quarto render /tmp/all.qmd`)
#    end

    return 1
end
