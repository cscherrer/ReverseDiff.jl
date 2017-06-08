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
            push!(args, :(ForwardDiff.Dual{T}(value(input[$i]::$R), chunk, Val{$(note_count)}())))
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

@inline increment_cache!(x::Cassette.RealNote, y) = cache!(x, cache(x) + y)

###################
# DiffGenre Hooks #
###################

# Play #
#------#

@inline function (h::Hook{Play,DiffGenre})(input::Real...)
    dual_output = dualcall(func(h), input)
    return ForwardDiff.value(dual_output), Cache(partials(dual_output))
end

# Replay #
#--------#

@inline function (h::Hook{Replay,DiffGenre})(output::Real, input::Tuple{Vararg{Real}}, parent::FunctionNote)
    dual_output = dualcall(func(h), input)
    value!(output, ForwardDiff.value(dual_output))
    cache!(parent, partials(dual_output))
    return nothing
end

# Rewind #
#--------#

@generated function (h::Hook{Rewind,DiffGenre})(output::Real, input::NTuple{N,Real}, parent::FunctionNote) where {N}
    increments = Expr(:block, Any[])
    note_count = 0
    for i in 1:N
        R = input.parameters[i]
        if R <: Cassette.RealNote
            note_count += 1
            push!(increments.args, :(increment_cache!(input[$i]::$(R), output_deriv * input_derivs[$(note_count)])))
        end
    end
    return quote
        $(Expr(:meta, :inline))
        output_deriv = cache(output)
        input_derivs = cache(parent)
        $(increments)
        cache!(output, zero(output_deriv))
        return nothing
    end
end
