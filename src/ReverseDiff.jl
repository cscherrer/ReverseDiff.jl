module ReverseDiff

using Cassette
using Cassette: @defgenre, func, value, value!, cache, cache!

using ForwardDiff

const SCALAR_PRIMITIVES = Symbol[:-, :sqrt, :cbrt, :abs, :abs2, :inv, :log, :log10, :log2,
                                 :log1p, :exp, :exp2, :expm1, :sin, :cos, :tan, :sec, :csc,
                                 :cot, :sind, :cosd, :tand, :secd, :cscd, :cotd, :asin,
                                 :acos, :atan, :asec, :acsc, :acot, :asind, :acosd, :atand,
                                 :asecd, :acscd, :acotd, :sinh, :cosh, :tanh, :sech, :csch,
                                 :coth, :asinh, :acosh, :atanh, :asech, :acsch, :acoth,
                                 :deg2rad, :rad2deg, :gamma, :lgamma, :+, :*, :/, :^,
                                 :atan2, :hypot, :mod]

const ARRAY_PRIMITIVES = Symbol[:eltype, :start, :length, :size, :getindex, :setindex!]

#############
# DiffGenre #
#############

@defgenre DiffGenre

@inline Base.promote_rule(::Type{DiffGenre}, ::Type{G}) where {G<:Cassette.AbstractGenre} = DiffGenre

##############
# Directives #
##############

const RealNote = Cassette.ValueNote{<:Cassette.AbstractGenre,<:Real}
const ArrayNote = Cassette.ValueNote{<:Cassette.AbstractGenre,<:AbstractArray}

# InterceptAs #
#-------------#

@inline (i::Cassette.InterceptAs{DiffGenre})(args...) = Cassette.Primitive()

@inline (i::Cassette.InterceptAs{DiffGenre})(args::AbstractArray...) = Cassette.NotPrimitive()

for f in ARRAY_PRIMITIVES
    @eval @inline (i::Cassette.InterceptAs{DiffGenre,typeof($f)})(args::AbstractArray...) = Cassette.Primitive()
end

# Play #
#------#

@inline (p::Cassette.Play{DiffGenre})(input...) = Cassette.Disarm(func(p))(input...)

for f in SCALAR_PRIMITIVES
    @eval begin
        @inline function (p::Cassette.Play{DiffGenre,typeof($f)})(input::Union{Real,RealNote}...)
            dual_output = dualcall(func(p), input)
            return ForwardDiff.value(dual_output), Cassette.Cache(cacheable_partials(dual_output))
        end
    end
end

# Record #
#--------#

@inline (r::Cassette.Record{DiffGenre})(output, input) = output

@inline function (r::Cassette.Record{DiffGenre})(output, input, cache)
    return Cassette.ValueNote(output, Cassette.FunctionNote{DiffGenre}(func(r), input), cache)
end

# # Replay #
# #--------#
#
# @inline function (r::Replay{DiffGenre})(output::RealNote, input::Tuple{Vararg{Union{Real,RealNote}}}, parent::Note)
#     dual_output = dualcall(func(r), input)
#     value!(output, ForwardDiff.value(dual_output))
#     cache!(parent, cacheable_partials(dual_output))
#     return nothing
# end
#
# # Rewind #
# #--------#
#
# @inline function (r::Rewind{DiffGenre})(output::RealNote, input::Tuple{Vararg{Union{Real,RealNote}}}, parent::Note)
#     adjoint = cache(output)
#     partials = cache(parent)
#     propagate_deriv!(input, adjoint, partials)
#     cache!(output, zero(adjoint))
#     return nothing
# end

#############
# Utilities #
#############

@inline cacheable_partials(x) = nothing
@inline cacheable_partials(x::ForwardDiff.Dual) = ForwardDiff.partials(x)

@inline increment_cache!(x::RealNote, y) = cache!(x, cache(x) + y)

@generated function dualcall(f::F, input::NTuple{N,Union{Real,RealNote}}) where {F,N}
    tag = ForwardDiff.Tag(F, input)
    args = Any[]
    note_count = 0
    for i in 1:N
        R = input.parameters[i]
        if R <: RealNote
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

@generated function propagate_deriv!(input::NTuple{N,Union{Real,RealNote}}, adjoint, partials) where {N}
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

end # module
