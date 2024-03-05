json_error() = error("""
    to use JSON as format, include the 'JSON' dependency in your project and
    import it into your environment.""")
json_module() = Base.get_extension(@__MODULE__(), :SerdeJSONExt)

function to_json(args...)
    ext = json_module()
    if ext === nothing
        json_error()
    else
        return ext.to_json(args...)
    end
end

function to_pretty_json(args...)
    ext = json_module()
    if ext === nothing
        json_error()
    else
        return ext.to_pretty_json(args...)
    end
end

function deser_json(args...)
    ext = json_module()
    if ext === nothing
        json_error()
    else
        return ext.deser_json(args...)
    end
end

function parse_json(args...)
    ext = json_module()
    if ext === nothing
        json_error()
    else
        return ext.parse_json(args...)
    end
end

