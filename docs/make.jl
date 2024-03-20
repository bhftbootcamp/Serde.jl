using Serde
using Documenter

DocMeta.setdocmeta!(Serde, :DocTestSetup, :(using Serde); recursive = true)

makedocs(;
    modules = [Serde],
    sitename = "Serde.jl",
    format = Documenter.HTML(;
        repolink = "https://github.com/bhftbootcamp/Serde.jl.git",
        canonical = "https://bhftbootcamp.github.io/Serde.jl",
        edit_link = "master",
        assets = String["assets/favicon.ico"],
        sidebar_sitename = false,
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
    warnonly = [:doctest, :missing_docs],
)

deploydocs(;
    repo = "github.com/bhftbootcamp/Serde.jl",
    devbranch = "master",
    push_preview = true,
)
