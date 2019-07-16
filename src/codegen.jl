
# Returns a vector of tuples (nm, t),
# where nm is a Symbol for field name, and t a Type.
function nametypetuples(t::DATATYPE_OR_UNIONALL)
    @nospecialize t

    _fieldnames = fieldnames(t)
    _fieldtypes = fieldtypes(t)
    @assert length(_fieldnames) == length(_fieldtypes)
    return [ (_fieldnames[i], _fieldtypes[i]) for i in 1:length(_fieldnames) ]
end

# don't touch this
function codegen_serialize(expr, datatype::DATATYPE_OR_UNIONALL) :: Expr
    @nospecialize expr datatype

    # returns expression:
    # "fieldname" => val.val.fieldname
    function field_value_pair_expr(nm::Symbol, @nospecialize(tt::Type{T})) :: Expr where {T}
        # val.val.fieldname
        val_expr = Expr(:., Expr(:., :val, QuoteNode(:val)), QuoteNode(nm))

        # BSONSerializer.encode(val.val.fieldname)
        encode_expr = Expr(:call, Expr(:., :BSONSerializer, QuoteNode(:encode)), val_expr)

        # "fieldname" => BSONSerializer.encode(val.val.fieldname)
        Expr(:call, :(=>), "$nm", encode_expr)
    end

    # "f1" => val.val.1, "f2" => val.val.f2, ...
    field_value_pairs = Expr(:tuple,
        [ field_value_pair_expr(nm, t) for (nm, t) in nametypetuples(datatype) ]...)

    expr_str = "$expr"

    quote
        function BSONSerializer.serialize(val::BSONSerializer.Serializable{$datatype})
            return BSONSerializer.BSON("type" => $expr_str, "args" => BSONSerializer.BSON($field_value_pairs...))
        end
   end
end

# don't touch this
function codegen_deserialize(expr, datatype::DATATYPE_OR_UNIONALL) :: Expr
    @nospecialize expr datatype

    function arg_expr(nm::Symbol, @nospecialize(tt::Type{T})) :: Expr where {T}
        nm_str = "$nm"
        val_expr = Expr(:ref, :args, nm_str)
        decode_expr = Expr(:call, Expr(:., :BSONSerializer, QuoteNode(:decode)), val_expr, T)
        return decode_expr
    end

    arg_list = Expr(:tuple,
        [ arg_expr(nm, t) for (nm, t) in nametypetuples(datatype) ]...)

    expr_str = "$expr"
    quote
        function BSONSerializer.deserialize(bson::Union{BSONSerializer.BSON, Dict}, ::Type{BSONSerializer.Serializable{$datatype}})
            args = bson["args"]
            ($datatype)($arg_list...)
        end
    end
end

function is_type_reference(@nospecialize(m), s::Symbol; debug::Bool=false) :: Bool
    result = isa(m.eval(s), DATATYPE_OR_UNIONALL)
    debug && !result && @info("is_type_reference: symbol $s is not a $(DATATYPE_OR_UNIONALL).")
    return result
end

function is_type_reference(caller_module::Module, expr::Expr; debug::Bool=false) :: Bool
    @nospecialize caller_module expr

    if debug
        @info("is_type_reference: input:")
        dump(expr)
    end

    is_module_name(expr::Symbol) = true
    is_module_name(expr::QuoteNode) = is_module_name(expr.value)
    is_module_name(other) = false
    function is_module_name(expr::Expr)
        if expr.head == :.
            @assert length(expr.args) == 2
            return is_module_name(expr.args[1]) && is_module_name(expr.args[2])
        end
    end

    is_type_name(expr::Symbol) = true
    is_type_name(expr::QuoteNode) = is_type_name(expr.value)
    is_type_name(other) = false

    # let's go slowly, because we're going to eval some expressions...
    if expr.head == :.
        @assert length(expr.args) == 2
        possibly_module_name = expr.args[1]
        possibly_type_name = expr.args[2]

        if is_module_name(possibly_module_name)
            type_owner_module = caller_module.eval(possibly_module_name)
            if isa(type_owner_module, Module)
                if is_type_name(possibly_type_name)
                    eval_result = caller_module.eval(expr)
                    result = isa(eval_result, DATATYPE_OR_UNIONALL)
                    debug && !result && @info("$expr::$(typeof(eval_result)) is not a $(DATATYPE_OR_UNIONALL) on $caller_module.")
                    return result
                else
                    debug && @info("$possibly_type_name is not a type name")
                end
            else
                debug && @info("$possibly_module_name evaluated to $(typeof(type_owner_module))")
            end
        else
            debug && @info("$possibly_module_name is not a module name.")
        end
    else
        debug && @info("expression head was not `.`")
    end

    return false
end

macro BSONSerializable(expr::Union{Expr, Symbol}, debug::Bool=false)
    @nospecialize expr

    debug && println("macro input: $expr, type $(typeof(expr))")

    if is_type_reference(__module__, expr, debug=debug)
        debug && println("$expr is a type reference.")
        datatype = __module__.eval(expr)
        expr_serialize_method = codegen_serialize(expr, datatype)
        expr_deserialize_method = codegen_deserialize(expr, datatype)

        debug && println(expr_serialize_method)
        __module__.eval(expr_serialize_method)
        __module__.eval(quote
            BSONSerializer.encode(val::$datatype) = BSONSerializer.serialize(BSONSerializer.Serializable(val))
            BSONSerializer.encode_type(::Type{$datatype}) = BSON
        end)

        debug && println(expr_deserialize_method)
        __module__.eval(expr_deserialize_method)
        __module__.eval(quote
            BSONSerializer.decode(val::Union{BSONSerializer.BSON, Dict}, ::Type{$datatype}) = BSONSerializer.deserialize(val, BSONSerializer.Serializable{$datatype})
        end)

        return
    elseif isa(expr, Expr) && expr.head == :struct
        println("macro was applied to struct definition. Skipping...")
        return esc(expr)
    else
        error("Couldn't apply @BSONSerialize to $expr.")
    end
end
