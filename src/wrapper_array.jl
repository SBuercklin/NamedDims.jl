# `L` is for labels, it should be a `Tuple` of `Symbol`s
struct NamedDimsArray{L, T, N, A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    data::A
end

function NamedDimsArray{L}(orig::AbstractArray{T,N}) where {L, T, N}
    if !(L isa NTuple{N, Symbol})
        throw(ArgumentError(
            "A $N dimentional array, needs a $N-tuple of dimension names. Got: $L"
        ))
    end
    return NamedDimsArray{L, T, N, typeof(orig)}(orig)
end
function NamedDimsArray(orig::AbstractArray{T,N}, names::NTuple{N, Symbol}) where {T, N}
    return NamedDimsArray{names}(orig)
end

parent_type(::Type{<:NamedDimsArray{L,T,N,A}}) where {L,T,N,A} = A
Base.parent(x::NamedDimsArray) = x.data


"""
    dim_names(A)

Returns a tuple of containing the names of all the dimensions of the array `A`.
"""
dim_names(::Type{<:NamedDimsArray{L}}) where L = L
dim_names(x::T) where T<:NamedDimsArray = dim_names(T)


name2dim(a::NamedDimsArray{L}, name) where L = name2dim(L, name)



#############################
# AbstractArray Interface
# https://docs.julialang.org/en/v1/manual/interfaces/index.html#man-interface-array-1

## Minimal
Base.size(a::NamedDimsArray) = size(parent(a))
Base.size(a::NamedDimsArray, dim) = size(parent(a), name2dim(a, dim))


## optional
Base.IndexStyle(::Type{A}) where A<:NamedDimsArray = Base.IndexStyle(parent_type(A))

Base.length(a::NamedDimsArray) = length(parent(a))

Base.axes(a::NamedDimsArray) = axes(parent(a))
Base.axes(a::NamedDimsArray, dim) = axes(parent(a), name2dim(a, dim))


function Base.similar(a::NamedDimsArray{L}, args...) where L
    return NamedDimsArray{L}(similar(parent(a), args...))
end


###############################
# kwargs indexing

"""
    order_named_inds(A, named_inds...)

Returns the indices that have the names and values given by `named_inds`
sorted into the order expected for the dimension of the array `A`.
If any dimensions of `A` are not present in the named_inds,
then they are given the value `:`, for slicing

For example:
```
A = NamedDimArray(rand(4,4), (:x,, :y))
order_named_inds(A; y=10, x=13) == (13,10)
order_named_inds(A; x=2, y=1:3) == (2, 1:3)
order_named_inds(A; y=5) == (:, 5)
```

This provides the core indexed lookup for `getindex` and `setindex` on the Array `A`
"""
order_named_inds(A::AbstractArray; named_inds...) = order_named_inds(dim_names(A); named_inds...)

###################
# getindex / view / dotview
# Note that `dotview` is undocumented but needed for making `a[x=2] .= 3` work

for f in (:getindex, :view, :dotview)
    @eval begin
        @propagate_inbounds function Base.$f(A::NamedDimsArray; named_inds...)
            inds = order_named_inds(A; named_inds...)
            return Base.$f(A, inds...)
        end

        @propagate_inbounds function Base.$f(a::NamedDimsArray, inds::Vararg{<:Integer})
            # Easy scalar case, will just return the element
            return Base.$f(parent(a), inds...)
        end

        @propagate_inbounds function Base.$f(a::NamedDimsArray, inds...)
            # Some nonscalar case, will return an array, so need to give that names.
            data = Base.$f(parent(a), inds...)
            L = determine_remaining_dim(dim_names(a), inds)
            return NamedDimsArray{L}(data)
        end
    end
end

############################################
# setindex!
@propagate_inbounds function Base.setindex!(A::NamedDimsArray, value; named_inds...)
    inds = order_named_inds(A; named_inds...)
    return setindex!(A, value, inds...)
end

@propagate_inbounds function Base.setindex!(a::NamedDimsArray, value, inds...)
    return setindex!(parent(a), value, inds...)
end
