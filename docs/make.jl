using Documenter
using Serde

DocMeta.setdocmeta!(Serde, :DocTestSetup, :(using Serde); recursive = true)

makedocs(;
    modules = [Serde],
    repo = "https://github.com/bhftbootcamp/Serde.jl/blob/{commit}{path}#{line}",
    sitename = "Serde.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://bhftbootcamp.github.io/Serde.jl",
        edit_link = "master",
        assets = String[],
        repolink = "https://github.com/bhftbootcamp/Serde.jl.git",
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => [
            "pages/json.md",
            "pages/toml.md",
            "pages/csv.md",
            "pages/query.md",
            "pages/xml.md",
            "pages/yaml.md",
            "pages/utils.md",
        ],
        "For Developers" => ["pages/extended_ser.md", "pages/extended_de.md"],
    ],
    checkdocs = :missing_docs,
)

deploydocs(; repo = "github.com/bhftbootcamp/Serde.jl", devbranch = "master")
