module LSDescentMethods

export ALL_solvers, STOP_solvers

using NLPModels
using Optimize

using LinearOperators

using PyPlot

using Stopping

include("armijo_wolfe.jl")

# AbstractLineFunction = Union{C1LineFunction,C2LineFunction}
ALL_solvers = Function[]
STOP_solvers = Function[]

include("lbfgs.jl")
push!(ALL_solvers,Newlbfgs)
include("steepest.jl")
#push!(ALL_solvers,steepest)
include("formulae.jl")
include("CG_generic.jl")
include("CG_FR.jl")
push!(ALL_solvers,CG_FR)
include("CG_PR.jl")
push!(ALL_solvers,CG_PR)
include("CG_HS.jl")
push!(ALL_solvers,CG_HS)
include("CG_HZ.jl")
push!(ALL_solvers,CG_HZ)
include("HessianDense.jl")
include("NewtonSpectralAbs.jl")
include("NewtonLDLtAbs.jl")
#using HSL
include("HessianSparse.jl")
#include("NewtonMA57Abs.jl")
include("HessianOp.jl")

include("cgTN.jl")
include("NewtonCG.jl")
include("Newton.jl")
push!(ALL_solvers,Newton)

include("BFGS_Jo.jl")

using LineSearch, LineSearches



end # module
