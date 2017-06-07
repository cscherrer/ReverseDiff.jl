module ReverseDiff

using Cassette
using Cassette: @defgenre, FunctionNote, Untrack, Hook, Play,
                Record, Replay, Rewind, track, untrack
using ForwardDiff

#############
# DiffGenre #
#############

@defgenre DiffGenre

@inline Cassette.promote_genre(a::DiffGenre, b::Cassette.ValueGenre) = a
@inline Cassette.promote_genre(a::Cassette.ValueGenre, b::DiffGenre) = b
@inline Cassette.note_cache(::DiffGenre, value::Number) = zero(value)
@inline Cassette.note_cache(::DiffGenre, value::AbstractArray) = zeros(value)
@inline Cassette.note_cache_eltype(::DiffGenre, value) = eltype(value)

##################
# Hook Fallbacks #
##################

@inline (h::Hook{Play,DiffGenre})(input...) = (Untrack(h.func)(input...), nothing)
@inline (h::Hook{Play,DiffGenre})(::Type{T}) where {T} = (Untrack(h.func)(T), nothing)

@inline (h::Hook{Record,DiffGenre})(output, input::Tuple,             cache) = track(output, h.genre, FunctionNote(h.genre, h.func, input, cache))
@inline (h::Hook{Record,DiffGenre})(output, input::Tuple{<:DataType}, cache) = track(output, h.genre)

############
# includes #
############

include("derivatives/scalars.jl")

end # module
