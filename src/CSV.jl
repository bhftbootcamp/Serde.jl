import ..Ext

to_csv(args...; kwargs...) = Ext.CSV().to_csv(args...; kwargs...)
deser_csv(args...; kwargs...) = Ext.CSV().deser_csv(args...; kwargs...)
parse_csv(args...; kwargs...) = Ext.CSV().parse_csv(args...; kwargs...)
