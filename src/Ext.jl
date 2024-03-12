"""
Handle module extensions.

Allows convenient access to the defined module extensions, mostly meant for internal use in
testing.

See also [`JSON`](@ref Ext.JSON).
"""
module Ext

export JSON,
    CSV,
    TOML

"""
    get_ext(ext)

Get extension `ext` as module to invoke functions from. `ext` must be one of: `:JSON`
"""
function get_ext(ext::Symbol)::Module
    ext_symbol = nothing
    if ext === :JSON
        ext_symbol = :SerdeJSONExt
    elseif ext === :CSV
        ext_symbol = :SerdeCSVExt
    elseif ext === :TOML
        ext_symbol = :SerdeTOMLExt
    else
        error("cannot retrieve unknown extension '$ext'")
    end

    ext = Base.get_extension(@__MODULE__(), ext_symbol)
    if ext === nothing
        error("""extension '$ext_symbol' cannot be loaded: please ensure that all dependent
              packages are imported into your environment""")
    end

    return ext
end

JSON() = get_ext(:JSON)
CSV() = get_ext(:CSV)
TOML() = get_ext(:TOML)

end
