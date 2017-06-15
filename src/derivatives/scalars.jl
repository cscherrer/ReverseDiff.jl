###################
# DiffGenre Hooks #
###################

# Play #
#------#

@inline function (p::Play{DiffGenre})(input::Real...)
    dual_output = dualcall(func(p), input)
    return ForwardDiff.value(dual_output), Cache(cacheable_partials(dual_output))
end

# Replay #
#--------#

@inline function (r::Replay{DiffGenre})(output::RealNote, input::Tuple{Vararg{Real}}, parent::FunctionNote)
    dual_output = dualcall(func(r), input)
    value!(output, ForwardDiff.value(dual_output))
    cache!(parent, cacheable_partials(dual_output))
    return nothing
end

# Rewind #
#--------#

@inline function (r::Rewind{DiffGenre})(output::RealNote, input::Tuple{Vararg{Real}}, parent::FunctionNote)
    adjoint = cache(output)
    partials = cache(parent)
    propagate_deriv!(input, adjoint, partials)
    cache!(output, zero(adjoint))
    return nothing
end

#############
# Utilities #
#############

@inline cacheable_partials(x) = nothing
@inline cacheable_partials(x::ForwardDiff.Dual) = ForwardDiff.partials(x)

@inline increment_cache!(x::RealNote, y) = cache!(x, cache(x) + y)

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

@generated function propagate_deriv!(input::NTuple{N,Real}, adjoint, partials) where {N}
    increments = Expr(:block, Any[])
    note_count = 0
    for i in 1:N
        R = input.parameters[i]
        if R <: RealNote
            note_count += 1
            push!(increments.args, :(increment_cache!(input[$i]::$(R), adjoint * partials[$(note_count)])))
        end
    end
    return quote
        $(Expr(:meta, :inline))
        $(increments)
        return nothing
    end
end
