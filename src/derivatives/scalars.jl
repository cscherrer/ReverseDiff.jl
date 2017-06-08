#############
# Utilities #
#############

@generated function dualcall(f::F, input::NTuple{N,Real}) where {F,N}
    tag = ForwardDiff.Tag(F, input)
    args = Any[]
    note_count = 0
    for i in 1:N
        R = input.parameters[i]
        if R <: Cassette.RealNote
            note_count += 1
            push!(args, :(ForwardDiff.Dual{T}(untrack(input[$i]::$R), chunk, Val{$(note_count)}())))
        else
            push!(args, :(input[$i]::$R))
        end
    end
    call = Expr(:call, :f, args...)
    return quote
        $(Expr(:meta, :inline))
        chunk = ForwardDiff.Chunk{$(note_count)}()
        T = $(typeof(tag))
        return $(call)
    end
end

partials(x) = nothing
partials(x::ForwardDiff.Dual) = ForwardDiff.partials(x)

###################
# DiffGenre Hooks #
###################

# Play #
#------#

@inline function (h::Hook{Play,DiffGenre})(input::Real...)
    dual_output = dualcall(h.func, input)
    return ForwardDiff.value(dual_output), Cache(partials(dual_output))
end

# Replay #
#--------#

@inline function (h::Hook{Replay,DiffGenre})(output::Real, input::Tuple{Vararg{Real}}, cache::Cache)
    dual_output = dualcall(h.func, input)
    output.value = ForwardDiff.value(dual_output)
    cache[] = partials(dual_output)
end

# Rewind #
#--------#

@generated function (h::Hook{Rewind,DiffGenre})(output::Real, input::NTuple{N,Real}, cache::Cache) where {N}
    loads = Expr(:block, Any[])
    note_count = 0
    for i in 1:N
        R = input.parameters[i]
        if R <: Cassette.RealNote
            note_count += 1
            push!(loads.args, :((input[$i]::$(R)).cache += output_deriv * input_derivs[$(note_count)]))
        end
    end
    return quote
        $(Expr(:meta, :inline))
        output_deriv = output.cache
        input_derivs = cache[]
        $(loads)
        output.cache = zero(output_deriv)
        return nothing
    end
end
