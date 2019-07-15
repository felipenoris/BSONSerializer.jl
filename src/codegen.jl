
# Returns a vector of tuples (nm, t),
# where nm is a Symbol for field name, and t a DataType.
function nametypetuples(t::DataType)
    @nospecialize t

    _fieldnames = fieldnames(t)
    _fieldtypes = fieldtypes(t)
    @assert length(_fieldnames) == length(_fieldtypes)
    return [ (_fieldnames[i], _fieldtypes[i]) for i in 1:length(_fieldnames) ]
end

# don't touch this
function codegen_serialize(expr, datatype::DataType) :: Expr
    @nospecialize expr datatype

    # returns expression:
    # "fieldname" => val.val.fieldname
    function field_value_pair_expr(nm::Symbol, @nospecialize(tt::Type{T})) :: Expr where {T}
        # val.val.fieldname
        val_expr = Expr(:., Expr(:., :val, QuoteNode(:val)), QuoteNode(nm))

        # encode(val.val.fieldname)
        encode_expr = Expr(:call, :encode, val_expr)

        # "fieldname" => val.val.fieldname
        Expr(:call, :(=>), "$nm", encode_expr)
    end

    # "f1" => val.val.1, "f2" => val.val.f2, ...
    field_value_pairs = Expr(:tuple,
        [ field_value_pair_expr(nm, t) for (nm, t) in nametypetuples(datatype) ]...)

    expr_str = "$expr"

    quote
        function serialize(val::Serializable{$datatype})
            return BSON("type" => $expr_str, "args" => BSON($field_value_pairs...))
        end
   end
end

# don't touch this
function codegen_deserialize(expr, datatype::DataType) :: Expr
    @nospecialize expr datatype

    function arg_expr(nm::Symbol, @nospecialize(tt::Type{T})) :: Expr where {T}
        nm_str = "$nm"
        val_expr = Expr(:ref, :args, nm_str)
        decode_expr = Expr(:call, :decode, val_expr, T)
        return decode_expr
    end

    arg_list = Expr(:tuple,
        [ arg_expr(nm, t) for (nm, t) in nametypetuples(datatype) ]...)

    expr_str = "$expr"
    quote
        function deserialize(bson::Union{BSON, Dict}, ::Type{Serializable{$datatype}})
            args = bson["args"]
            ($datatype)($arg_list...)
        end
    end
end

is_type_reference(@nospecialize(mod), s::Symbol) = isa(mod.eval(s), DataType)

function is_type_reference(callee_module::Module, expr::Expr)
    @nospecialize callee_module expr

    # let's go slowly, because we're going to eval some expressions...
    if expr.head == :. && length(expr.args) == 2
        possibly_module_name = expr.args[1]
        possibly_type_name = expr.args[2]

        if isa(possibly_module_name, Symbol)
            type_owner_module = callee_module.eval(possibly_module_name)
            if isa(type_owner_module, Module)
                if isa(possibly_type_name, QuoteNode) && isa(possibly_type_name.value, Symbol)
                    return isa(callee_module.eval(expr), DataType)
                end
            end
        end
    end
    return false
end

macro BSONSerializable(expr::Union{Expr, Symbol})
    @nospecialize expr

    #println("macro input: $expr, type $(typeof(expr))")

    if is_type_reference(__module__, expr)
        #println("$expr is a type reference.")
        datatype = __module__.eval(expr)
        expr_serialize_method = codegen_serialize(expr, datatype)
        expr_deserialize_method = codegen_deserialize(expr, datatype)

        #println(expr_serialize_method)
        eval(expr_serialize_method)
        eval(quote
            encode(val::$datatype) = serialize(Serializable(val))
            encode_type(::Type{$datatype}) = BSON
        end)

        #println(expr_deserialize_method)
        eval(expr_deserialize_method)
        eval(quote
            decode(val::Union{BSON, Dict}, ::Type{$datatype}) = deserialize(val, Serializable{$datatype})
        end)

        return
    elseif isa(expr, Expr) && expr.head == :struct
        println("macro was applied to struct definition. Skipping...")
        return esc(expr)
    else
        error("Couldn't apply @BSONSerialize to $expr.")
    end
end
