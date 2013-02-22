2# A Julia implementation of QuickCheck, a specification-based tester
#
# QuickCheck was originally written for Haskell by Koen Claessen and John Hughes
# http://www.cse.chalmers.se/~rjmh/QuickCheck/

module QuickCheck

export property
export condproperty
export quantproperty

function lambda_arg_types(f::Function)
    if !isa(f.code, LambdaStaticData)
        error("You must supply either an anonymous function with typed arguments or an array of argument types.")
    end
    Type[eval(var.args[2]) for var in f.code.ast.args[1]]
end

# Simple properties
function property(f::Function, typs::Vector, ntests)
    arggens = [size -> generator(typ, size) for typ in typs]
    quantproperty(f, typs, ntests, arggens...)
end
property(f::Function, typs::Vector) = property(f, typs, 100)
property(f::Function, ntests) = property(f, lambda_arg_types(f), ntests)
property(f::Function) = property(f, 100)

# Conditional properties
function condproperty(f::Function, typs::Vector, ntests, maxtests, argconds...)
    arggens = [size -> generator(typ, size) for typ in typs]
    check_property(f, arggens, argconds, ntests, maxtests)
end
condproperty(f::Function, args...) = condproperty(f, lambda_arg_types(f), args...)

# Quantified properties (custom generators)
function quantproperty(f::Function, typs::Vector, ntests, arggens...)
    argconds = [_->true for t in typs]
    check_property(f, arggens, argconds, ntests, ntests)
end
quantproperty(f::Function, args...) = quantproperty(f, lambda_arg_types(f), args...)

function check_property(f::Function, arggens, argconds, ntests, maxtests)
    totalTests = 0
    for i in 1:ntests
        goodargs = false
        args = {}
        while !goodargs
            totalTests += 1
            if totalTests > maxtests
                println("Arguments exhausted after $i tests.")
                return
            end
            args = [arggen(div(i,2)+3) for arggen in arggens]
            goodargs = all([apply(x[1], tuple(x[2])) for x in zip(argconds, args)])
        end
        if !f(args...)
            error("Falsifiable, after $i tests:\n$args")
        end
    end
    println("OK, passed $ntests tests.")
end

# Default generators for primitive types
generator{T<:Unsigned}(::Type{T}, size) = convert(T, rand(1:size))
generator{T<:Signed}(::Type{T}, size) = convert(T, rand(-size:size))
generator{T<:FloatingPoint}(::Type{T}, size) = convert(T, (rand()-0.5).*size)
# This won't generate interesting UTF-8, but doing that is a Hard Problem
generator{T<:String}(::Type{T}, size) = convert(T, randstring(size))

generator(::Type{Any}, size) = error("Property variables cannot by typed Any.")

# Generator for array types
function generator{T,n}(::Type{Array{T,n}}, size)
    dims = [rand(1:size) for i in 1:n]
    reshape([generator(T, size) for x in 1:prod(dims)], dims...)
end

# Generator for composite types
function generator{C}(::Type{C}, size)
    if !isa(C, CompositeKind)
        error("No generator defined for type $C.")
    end
    C([generator(T, size) for T in C.types]...)
end

end
