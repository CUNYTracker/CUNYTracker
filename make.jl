## to make this page
## edit _quarto.yml to point to new file
## run julia make.jl; push to github
## fix typos
## run julia make_topic.jl
## push to github

function canonicalize_links!(f)
    ls = readlines(f)
    open(f, "w") do io
        for l in ls
            l = replace(l, "www-chronicle-com.csi.ezproxy.cuny.edu" => "www.chronicle.com")
            # others?
            println(io, l)
        end
    end
end


# julia -e process_qmd_file.jl
function (@main)(args...)
    fs = readdir("qmd_raw")
    for g in fs
        @show "process $g"
        @show "Add to _quarto.yml"
        f = "qmd_raw/$g"
        canonicalize_links!(f)

        m,d = split(replace(g,".qmd"=>""), "-")
        m = uppercasefirst(m)
        open(g, "w") do io
            println(io, "# ", m, " ", d)
            seen___ = false
            for l ∈ readlines(f)
                @show l
                if !seen___ && startswith(l, "----")
                    seen___ = true
                    continue
                end
                !seen___ && continue

                if startswith(l, "http")
                    l = replace(l, "www-chronicle-com.csi.ezproxy.cuny.edu" =>
                                "www.chronicle.com")
                    l = first(split(l, "?utm_source"))
                    println(io, "[", l, "](",  l, ")")
                else
                    println(io, l)
                end
            end
        end
    end
end
