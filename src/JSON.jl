import ..Ext

to_json(args...) = Ext.JSON().to_json(args...)
to_pretty_json(args...) = Ext.JSON().to_pretty_json(args...)
deser_json(args...) = Ext.JSON().deser_json(args...)
parse_json(args...) = Ext.JSON().parse_json(args...)
