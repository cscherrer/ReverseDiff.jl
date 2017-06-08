module ReverseDiff

using Cassette
using Cassette: @defgenre, FunctionNote, Hook, Play, Record, Replay, Rewind, Cache,
                track, disarm, func, value, value!, cache, cache!, RealNote

using ForwardDiff

#############
# DiffGenre #
#############

@defgenre DiffGenre

@inline Cassette.promote_genre(a::DiffGenre, b::Cassette.ValueGenre) = a
@inline Cassette.promote_genre(a::Cassette.ValueGenre, b::DiffGenre) = b

@inline Cassette.note_cache_eltype(::DiffGenre, cache) = eltype(cache)

@inline Cassette.note_cache(::DiffGenre, value::Number) = zero(value)
@inline Cassette.note_cache(::DiffGenre, value::AbstractArray) = zeros(value)

##################
# Hook Fallbacks #
##################

@inline (h::Hook{Play,DiffGenre})(input...) = disarm(func(h))(input...)
@inline (h::Hook{Record,DiffGenre})(output, input::Tuple, cache...) = track(output, FunctionNote{DiffGenre}(func(h), input, cache...))

############
# includes #
############

include("derivatives/scalars.jl")

end # module
