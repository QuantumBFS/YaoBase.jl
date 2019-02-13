export batch_normalize, batch_normalize!, rotmat,
    hilbertkron, rand_hermitian, rand_unitary, fidelity_mix, fidelity_pure,
    general_controlled_gates, general_c1_gates, linop2dense

using LuxurySparse, LinearAlgebra

"""
    batch_normalize!(matrix)

normalize a batch of vector.
"""
function batch_normalize!(s::AbstractMatrix, p::Real=2)
    B = size(s, 2)
    for i = 1:B
        normalize!(view(s, :, i), p)
    end
    s
end

"""
    batch_normalize

normalize a batch of vector.
"""
function batch_normalize(s::AbstractMatrix, p::Real=2)
    ts = copy(s)
    batch_normalize!(ts, p)
end

"""
    hilbertkron(num_bit::Int, gates::Vector{AbstractMatrix}, locs::Vector{Int}) -> AbstractMatrix

Return general kronecher product form of gates in Hilbert space of `num_bit` qubits.

* `gates` are a list of matrices.
* `start_locs` should have the same length as `gates`, specifing the gates starting positions.
"""
function hilbertkron(num_bit::Int, ops::Vector{T}, start_locs::Vector{Int}) where T<:AbstractMatrix
    sizes = [op |> _nactive for op in ops]
    start_locs = num_bit .- start_locs .- sizes .+ 2

    order = sortperm(start_locs)
    sorted_ops = ops[order]
    sorted_start_locs = start_locs[order]
    num_ids = vcat(sorted_start_locs[1]-1, diff(push!(sorted_start_locs, num_bit+1)) .- sizes[order])

    _wrap_identity(sorted_ops, num_ids)
end

# kron, and wrap matrices with identities.
function _wrap_identity(data_list::Vector{T}, num_bit_list::Vector{Int}) where T<:AbstractMatrix
    length(num_bit_list) == length(data_list) + 1 || throw(ArgumentError())

    ⊗ = kron
    reduce(zip(data_list, num_bit_list[2:end]); init=IMatrix(1 << num_bit_list[1])) do x, y
        x ⊗ y[1] ⊗ IMatrix(1<<y[2])
    end
end

"""
    general_controlled_gates(num_bit::Int, projectors::Vector{Tp}, cbits::Vector{Int}, gates::Vector{AbstractMatrix}, locs::Vector{Int}) -> AbstractMatrix

Return general multi-controlled gates in hilbert space of `num_bit` qubits,

* `projectors` are often chosen as `P0` and `P1` for inverse-Control and Control at specific position.
* `cbits` should have the same length as `projectors`, specifing the controling positions.
* `gates` are a list of controlled single qubit gates.
* `locs` should have the same length as `gates`, specifing the gates positions.
"""
function general_controlled_gates(
    n::Int,
    projectors::Vector{<:AbstractMatrix},
    cbits::Vector{Int},
    gates::Vector{<:AbstractMatrix},
    locs::Vector{Int}
)
    IMatrix(1<<n) - hilbertkron(n, projectors, cbits) +
        hilbertkron(n, vcat(projectors, gates), vcat(cbits, locs))
end

"""
    general_c1_gates(num_bit::Int, projector::AbstractMatrix, cbit::Int, gates::Vector{AbstractMatrix}, locs::Vector{Int}) -> AbstractMatrix

general (low performance) construction method for control gate on different lines.
"""
general_c1_gates(num_bit::Int, projector::Tp, cbit::Int, gates::Vector{Tg}, locs::Vector{Int}) where {Tg<:AbstractMatrix, Tp<:AbstractMatrix} =
hilbertkron(num_bit, [IMatrix(2) - projector], [cbit]) + hilbertkron(num_bit, vcat([projector], gates), vcat([cbit], locs))

"""
    rotmat(M::AbstractMatrix, θ::Real)

Returns rotated `M`: ``exp(-\\frac{imθ}{2} M)``.
"""
rotmat(M::AbstractMatrix, θ::Real) = exp(-im * θ/2 * M)


"""
    linop2dense([T=ComplexF64], linear_map!::Function, n::Int) -> Matrix

Returns the dense matrix representation given linear map function.
"""
linop2dense(linear_map!::Function, n::Int) = linop2dense(ComplexF64, linear_map!, n)
linop2dense(::Type{T}, linear_map!::Function, n::Int) = linear_map!(Matrix{T}(I, 1<<n, 1<<n))

################### Fidelity ###################
"""
    fidelity_pure(v1::Vector, v2::Vector)

fidelity for pure states.
"""
fidelity_pure(v1::Vector, v2::Vector) = abs(v1'*v2)

"""
    fidelity_mix(m1::Matrix, m2::Matrix)

Fidelity for mixed states.

Reference:
    http://iopscience.iop.org/article/10.1088/1367-2630/aa6a4b/meta
"""
function fidelity_mix(m1::Matrix, m2::Matrix)
    O = m1'*m2
    tr(sqrt(O*O'))
end

"""
    rand_unitary(N::Int) -> Matrix

Random unitary matrix.
"""
function rand_unitary(N::Int)
    qr(randn(ComplexF64, N, N)).Q |> Matrix
end

"""
    rand_hermitian(N::Int) -> Matrix

Random hermitian matrix.
"""
function rand_hermitian(N::Int)
    A = randn(ComplexF64, N, N)
    A + A'
end