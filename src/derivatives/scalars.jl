#############
# Utilities #
#############

@generated function dualcall(f::F, input::NTuple{N,Real}) where {F,N}
    tag = ForwardDiff.Tag(F, input)
    args = Any[]
    note_count = 1
    for i in 1:N
        R = x.parameters[i]
        if R <: Cassette.RealNote
            push!(args, :(ForwardDiff.Dual{T}(untrack(x[$i])::$R, chunk, Val{$(note_count)}())))
            note_count += 1
        else
            push!(args, :(x[$i]::$R))
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

partials(x) where {N} = nothing
partials(x::Dual) where {N} = ForwardDiff.partials(x)

###################
# DiffGenre Hooks #
###################

# Play #
#------#

@inline function (h::Hook{Play,DiffGenre})(input::Real...)
    dual_output = dualcall(h.func, input)
    return ForwardDiff.value(dual_output), Ref(partials(dual_output))
end

# Replay #
#--------#

@inline function (h::Hook{Replay,DiffGenre})(output::Real, input::Tuple{Vargarg{Real}}, cache::Ref)
    dual_output = dualcall(h.func, input)
    output.value = ForwardDiff.value(dual_output)
    cache[] = partials(dual_output)
end

# Rewind #
#--------#

@generated function (h::Hook{Rewind,DiffGenre})(output::Real, input::NTuple{N,Real}, cache::Ref) where {N}
    loads = Expr(:block, Any[])
    note_count = 1
    for i in 1:N
        R = input.parameters[i]
        if R <: Cassette.RealNote
            push!(loads.args, :((input[$i]::$(R)).cache += output_deriv * input_derivs[$(note_count)]))
            note_count += 1
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
