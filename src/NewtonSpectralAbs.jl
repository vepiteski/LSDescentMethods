export NewtonSpectral

function NwtdirectionSpectral(H,g)
    Δ = ones(g)
    V = ones(H)
    try
        Δ, V = eig(H)
    catch
        Δ, V = eig(H + eye(H))
    end
    ϵ2 =  1.0e-8 
    Γ = 1.0 ./ max(abs(Δ),ϵ2)
    
    d = - (V * diagm(Γ) * V') * (g)
    return d
end


function NewtonSpectral(nlp :: AbstractNLPModel;
               atol :: Float64=1.0e-8, rtol :: Float64=1.0e-6,
               max_eval :: Int=0,
               verbose :: Bool=true,
               mem :: Int=5,
               linesearch :: Function = Newarmijo_wolfe,
               kwargs...)

    x = copy(nlp.meta.x0)
    n = nlp.meta.nvar
    
    xt = Array(Float64, n)
    ∇ft = Array(Float64, n)
    
    f = obj(nlp, x)
    ∇f = grad(nlp, x)

    H = hess(nlp,x)
    tempH = (H+tril(H,-1)')
    H = full(tempH)
    
    ∇fNorm = BLAS.nrm2(n, ∇f, 1)
    ϵ = atol + rtol * ∇fNorm
    max_eval == 0 && (max_eval = max(min(100, 2 * n), 5000))
    iter = 0
    
    verbose && @printf("%4s  %8s  %7s  %8s  %4s\n", "iter", "f", "‖∇f‖", "∇f'd", "bk")
    verbose && @printf("%4d  %8.1e  %7.1e", iter, f, ∇fNorm)
    
    optimal = ∇fNorm <= ϵ
    tired = nlp.counters.neval_obj + nlp.counters.neval_grad + nlp.counters.neval_hess > max_eval
    
    β = 0.0
    d = zeros(∇f)
    scale = 1.0
    
    while !(optimal || tired)
        d = NwtdirectionSpectral(H,∇f)
        slope = BLAS.dot(n, d, 1, ∇f, 1)

        verbose && @printf("  %8.1e", slope)
        
        # Perform improved Armijo linesearch.
        h = C1LineFunction(nlp, x, d)


        t, good_grad, ft, nbk, nbW = linesearch(h, f, slope, ∇ft, verbose=false; kwargs...)
        verbose && @printf("  %4d\n", nbk)
        
        BLAS.blascopy!(n, x, 1, xt, 1)
        BLAS.axpy!(n, t, d, 1, xt, 1)
        good_grad || (∇ft = grad!(nlp, xt, ∇ft))
        
        # Move on.
        s = xt - x
        y = ∇ft - ∇f
        β = (∇ft⋅y) / (∇f⋅∇f)
        x = xt
        f = ft

        H = hess(nlp,x)
        tempH = (H+tril(H,-1)')
        H = full(tempH)

        BLAS.blascopy!(n, ∇ft, 1, ∇f, 1)

        # norm(∇f) bug: https://github.com/JuliaLang/julia/issues/11788
        ∇fNorm = BLAS.nrm2(n, ∇f, 1)
        iter = iter + 1
        
        verbose && @printf("%4d  %8.1e  %7.1e", iter, f, ∇fNorm)
        
        optimal = ∇fNorm <= ϵ
        tired = nlp.counters.neval_obj + nlp.counters.neval_grad + nlp.counters.neval_hess > max_eval
    end
    verbose && @printf("\n")
    
    status = tired ? "UserLimit" : "Optimal"
    return (x, f, ∇fNorm, iter, optimal, tired, status)
end
