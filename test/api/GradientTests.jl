module GradientTests

using DiffBase, ForwardDiff, ReverseDiff, Base.Test

include("../utils.jl")

println("testing gradient/gradient!...")
tic()

############################################################################################
function test_unary_gradient(f, x)
    test = ForwardDiff.gradient!(DiffBase.GradientResult(x), f, x)

    # without Options

    @test_approx_eq_eps ReverseDiff.gradient(f, x) DiffBase.gradient(test) EPS

    out = similar(x)
    ReverseDiff.gradient!(out, f, x)
    @test_approx_eq_eps out DiffBase.gradient(test) EPS

    result = DiffBase.GradientResult(x)
    ReverseDiff.gradient!(result, f, x)
    @test_approx_eq_eps DiffBase.value(result) DiffBase.value(test) EPS
    @test_approx_eq_eps DiffBase.gradient(result) DiffBase.gradient(test) EPS

    # with Options

    opts = ReverseDiff.Options(x)

    @test_approx_eq_eps ReverseDiff.gradient(f, x, opts) DiffBase.gradient(test) EPS

    out = similar(x)
    ReverseDiff.gradient!(out, f, x, opts)
    @test_approx_eq_eps out DiffBase.gradient(test) EPS

    result = DiffBase.GradientResult(x)
    ReverseDiff.gradient!(result, f, x, opts)
    @test_approx_eq_eps DiffBase.value(result) DiffBase.value(test) EPS
    @test_approx_eq_eps DiffBase.gradient(result) DiffBase.gradient(test) EPS

    # with Record

    r = ReverseDiff.Record(f, rand(size(x)))

    @test_approx_eq_eps ReverseDiff.gradient!(r, x) DiffBase.gradient(test) EPS

    out = similar(x)
    ReverseDiff.gradient!(out, r, x)
    @test_approx_eq_eps out DiffBase.gradient(test) EPS

    result = DiffBase.GradientResult(x)
    ReverseDiff.gradient!(result, r, x)
    @test_approx_eq_eps DiffBase.value(result) DiffBase.value(test) EPS
    @test_approx_eq_eps DiffBase.gradient(result) DiffBase.gradient(test) EPS
end

for f in DiffBase.MATRIX_TO_NUMBER_FUNCS
    testprintln("MATRIX_TO_NUMBER_FUNCS", f)
    test_unary_gradient(f, rand(5, 5))
end

for f in DiffBase.VECTOR_TO_NUMBER_FUNCS
    testprintln("VECTOR_TO_NUMBER_FUNCS", f)
    test_unary_gradient(f, rand(5))
end

for f in DiffBase.TERNARY_MATRIX_TO_NUMBER_FUNCS
    testprintln("TERNARY_MATRIX_TO_NUMBER_FUNCS", f)

    a, b, c = rand(5, 5), rand(5, 5), rand(5, 5)

    test_val = f(a, b, c)
    test_a = ForwardDiff.gradient(x -> f(x, b, c), a)
    test_b = ForwardDiff.gradient(x -> f(a, x, c), b)
    test_c = ForwardDiff.gradient(x -> f(a, b, x), c)

    # without Options

    ∇a, ∇b, ∇c = ReverseDiff.gradient(f, (a, b, c))
    @test_approx_eq_eps ∇a test_a EPS
    @test_approx_eq_eps ∇b test_b EPS
    @test_approx_eq_eps ∇c test_c EPS

    ∇a, ∇b, ∇c = map(similar, (a, b, c))
    ReverseDiff.gradient!((∇a, ∇b, ∇c), f, (a, b, c))
    @test_approx_eq_eps ∇a test_a EPS
    @test_approx_eq_eps ∇b test_b EPS
    @test_approx_eq_eps ∇c test_c EPS

    ∇a, ∇b, ∇c = map(DiffBase.GradientResult, (a, b, c))
    ReverseDiff.gradient!((∇a, ∇b, ∇c), f, (a, b, c))
    @test_approx_eq_eps DiffBase.value(∇a) test_val EPS
    @test_approx_eq_eps DiffBase.value(∇b) test_val EPS
    @test_approx_eq_eps DiffBase.value(∇c) test_val EPS
    @test_approx_eq_eps DiffBase.gradient(∇a) test_a EPS
    @test_approx_eq_eps DiffBase.gradient(∇b) test_b EPS
    @test_approx_eq_eps DiffBase.gradient(∇c) test_c EPS

    # with Options

    opts = ReverseDiff.Options((a, b, c))

    ∇a, ∇b, ∇c = ReverseDiff.gradient(f, (a, b, c), opts)
    @test_approx_eq_eps ∇a test_a EPS
    @test_approx_eq_eps ∇b test_b EPS
    @test_approx_eq_eps ∇c test_c EPS

    ∇a, ∇b, ∇c = map(similar, (a, b, c))
    ReverseDiff.gradient!((∇a, ∇b, ∇c), f, (a, b, c), opts)
    @test_approx_eq_eps ∇a test_a EPS
    @test_approx_eq_eps ∇b test_b EPS
    @test_approx_eq_eps ∇c test_c EPS

    ∇a, ∇b, ∇c = map(DiffBase.GradientResult, (a, b, c))
    ReverseDiff.gradient!((∇a, ∇b, ∇c), f, (a, b, c), opts)
    @test_approx_eq_eps DiffBase.value(∇a) test_val EPS
    @test_approx_eq_eps DiffBase.value(∇b) test_val EPS
    @test_approx_eq_eps DiffBase.value(∇c) test_val EPS
    @test_approx_eq_eps DiffBase.gradient(∇a) test_a EPS
    @test_approx_eq_eps DiffBase.gradient(∇b) test_b EPS
    @test_approx_eq_eps DiffBase.gradient(∇c) test_c EPS

    # with Record

    r = ReverseDiff.Record(f, (rand(size(a)), rand(size(b)), rand(size(c))))

    ∇a, ∇b, ∇c = ReverseDiff.gradient!(r, (a, b, c))
    @test_approx_eq_eps ∇a test_a EPS
    @test_approx_eq_eps ∇b test_b EPS
    @test_approx_eq_eps ∇c test_c EPS

    ∇a, ∇b, ∇c = map(similar, (a, b, c))
    ReverseDiff.gradient!((∇a, ∇b, ∇c), r, (a, b, c))
    @test_approx_eq_eps ∇a test_a EPS
    @test_approx_eq_eps ∇b test_b EPS
    @test_approx_eq_eps ∇c test_c EPS

    ∇a, ∇b, ∇c = map(DiffBase.GradientResult, (a, b, c))
    ReverseDiff.gradient!((∇a, ∇b, ∇c), r, (a, b, c))
    @test_approx_eq_eps DiffBase.value(∇a) test_val EPS
    @test_approx_eq_eps DiffBase.value(∇b) test_val EPS
    @test_approx_eq_eps DiffBase.value(∇c) test_val EPS
    @test_approx_eq_eps DiffBase.gradient(∇a) test_a EPS
    @test_approx_eq_eps DiffBase.gradient(∇b) test_b EPS
    @test_approx_eq_eps DiffBase.gradient(∇c) test_c EPS
end

############################################################################################

println("done (took $(toq()) seconds)")

end # module
