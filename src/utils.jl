################
# track/track! #
################

track(x, tp::Tape = Tape()) = track(x, eltype(x), tp)
track(xts::Tuple, tp::Tape = Tape()) = track(xts, eltype(first(xts)), tp)
track{A}(xs::Tuple, ::Type{A}, tp::Tape = Tape()) = map(x -> track(x, A, tp), xs)

track{T,A}(x::AbstractArray{T}, ::Type{A}, tp::Tape = Tape()) = track(x, A, Nullable(tp))
track{A}(x::Number, ::Type{A}, tp::Tape = Tape()) = track(x, A, Nullable(tp))
track!(xts, xs, tp::Tape = Tape()) = track!(xts, xs, Nullable(tp))

track{A}(x::Number, ::Type{A}, tp::Nullable{Tape}) = Tracked(x, A, tp)
track{T,A}(x::AbstractArray{T}, ::Type{A}, tp::Nullable{Tape}) = track!(similar(x, Tracked{T,A}), x, tp)

function track!{T,A}(xt::Tracked{T,A}, x::Number, tp::Nullable{Tape})
    xt.value = x
    xt.adjoint = zero(A)
    xt.tape = tp
    return xt
end

function track!{T,A}(xt::AbstractArray{Tracked{T,A}}, x::AbstractArray, tp::Nullable{Tape})
    for i in eachindex(xt)
        xt[i] = Tracked(x[i], A, tp)
    end
    return xt
end

function track!(xts::Tuple, xs::Tuple, tp::Nullable{Tape})
    for i in eachindex(xts)
        track!(xts[i], xs[i], tp)
    end
    return xts
end

##################################
# array accessors/tape selection #
##################################

value{T}(arr::AbstractArray{T}) = value!(similar(arr, valtype(T)), arr)

function value!(out, arr)
    for i in eachindex(out)
        out[i] = value(arr[i])
    end
    return out
end

function setvalue!(out, arr)
    for i in eachindex(out)
        setvalue!(out[i], arr[i])
    end
    return out
end

function setvalue!(f, out, arr)
    for i in eachindex(out)
        setvalue!(out[i], f(arr[i]))
    end
    return out
end

adjoint{T}(arr::AbstractArray{T}) = adjoint!(similar(arr, adjtype(T)), arr)

function adjoint!(out, arr)
    for i in eachindex(out)
        out[i] = adjoint(arr[i])
    end
    return out
end

function setadjoint!(out, arr)
    for i in eachindex(out)
        setadjoint!(out[i], arr[i])
    end
    return out
end

function setadjoint!(f, out, arr)
    for i in eachindex(out)
        setadjoint!(out[i], f(arr[i]))
    end
    return out
end

function tape(arr::AbstractArray)
    for t in arr
        !(isnull(tape(t))) && return tape(t)
    end
    return Nullable{Tape}()
end

tape(a::AbstractArray, b::AbstractArray) = (tp = tape(a); isnull(tp) ? tape(b) : tp)
tape(a, b::AbstractArray) = (tp = tape(a); isnull(tp) ? tape(b) : tp)
tape(a::AbstractArray, b) = (tp = tape(a); isnull(tp) ? tape(b) : tp)

#####################
# seeding/unseeding #
#####################

seed!(t::Tracked) = (setadjoint!(t, one(adjtype(t))); return t)
seed!(t::TapeNode) = (seed!(t.outputs); return t)

unseed!(t::Tracked) = (setadjoint!(t, zero(adjtype(t))); return t)
unseed!(t::TapeNode) = (unseed!(t.inputs); unseed!(t.outputs); return t)
unseed!(::Union{Void, Number}) = nothing
unseed!(ts) = for t in ts; unseed!(t); end

#######################
# adjoint propagation #
#######################

function extract_and_decrement_adjoint!(x::AbstractArray, y::AbstractArray)
    for i in eachindex(x)
        x[i].adjoint -= adjoint(y[i])
    end
    return x
end

function extract_and_increment_adjoint!(x::AbstractArray, y::AbstractArray)
    for i in eachindex(x)
        x[i].adjoint += adjoint(y[i])
    end
    return x
end

function increment_adjoint!(x::AbstractArray, y::AbstractArray)
    for i in eachindex(x)
        x[i].adjoint += y[i]
    end
    return x
end

function increment_adjoint!(x::AbstractArray, y::Real)
    for i in eachindex(x)
        x[i].adjoint += y
    end
    return x
end

increment_adjoint!(x::Tracked, y::Real) = (x.adjoint += y)
