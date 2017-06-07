export CG_generic

function CG_generic(nlp :: AbstractNLPModel;
                    atol :: Float64=1.0e-8, rtol :: Float64=1.0e-6,
                    max_eval :: Int=20000,
                    max_iter :: Int=5000,
                    verbose :: Bool=false,
                    verboseLS :: Bool = false,
                    linesearch :: Function = Newarmijo_wolfe,
                    CG_formula :: Function = formula_HZ,
                    scaling :: Bool = true,
                    kwargs...)

    x = copy(nlp.meta.x0)
    n = nlp.meta.nvar

    xt = Array(Float64, n)
    ∇ft = Array(Float64, n)

    f = obj(nlp, x)
    ∇f = grad(nlp, x)

    ∇fNorm = norm(∇f, Inf)

    ϵ = atol + rtol * ∇fNorm
    iter = 0

    verbose && @printf("%4s  %8s  %7s  %8s  %4s %7s %8s\n", "iter", "f", "‖∇f‖", "∇f'd", "bk","t","scale")
    verbose && @printf("%4d  %8.1e  %7.1e", iter, f, ∇fNorm)

    optimal = ∇fNorm <= ϵ
    tired = nlp.counters.neval_obj + nlp.counters.neval_grad > max_eval

    β = 0.0
    d = zeros(∇f)
    scale = 1.0

    while !(optimal || tired)
        d = - ∇f + β*d
        slope = ∇f⋅d
        if slope > 0.0  # restart with negative gradient
            d = - ∇f
            slope =  ∇f⋅d
        end

        verbose && @printf("  %8.1e", slope)

        # Perform improved Armijo linesearch.
        h = C1LineFunction(nlp, x, d*scale)
        #t, good_grad, ft, nbk, nbW = linesearch(h, f, slope*scale, ∇ft, verbose=verboseLS; kwargs...)
        if linesearch==_strongwolfe2!
          x_out = copy(x)
          x_new = copy(x)
          if iter == 0
            gr_new = zeros(n)
          else
            gr_new = ∇f
          end
          p = d*scale
          lsr = LineSearchResults{Float64}([0.0],[f],[slope*scale],0)
          #lsr = [f, slope]
          alpha0 = 1.0
          mayterminate = false
          #print_with_color(:magenta,"on peut rentrer dans le linesearch \n")
          t = linesearch(nlp, x_out, p, x_new, lsr, alpha0, mayterminate; kwargs...)
          good_grad = false
          ft = obj(nlp, x + (t*scale)*d)
          nbk = NaN
          nbW = NaN
        elseif linesearch == _hagerzhang2!
          x_out = copy(x)
          s = d*scale
          xtmp = copy(x)
          lsr = LineSearchResults{Float64}([0.0],[f],[slope*scale],0)
          c = 1.0
          mayterminate = false
          t = linesearch(nlp, x_out, s, xtmp, lsr, c, mayterminate; kwargs... )
          good_grad = false
          ft = obj(nlp, x + (t*scale)*d)
          nbk = NaN
          nbW = NaN
        elseif linesearch==_morethuente2!
          x_out = copy(x)
          s = d*scale
          x_new = copy(x)
          lsr = LineSearchResults{Float64}([0.0],[f],[slope*scale],0)
          stp = 1.0
          mayterminate = false
          t= linesearch(nlp, x_out, s, x_new, lsr, stp, mayterminate; kwargs...)
          good_grad = false
          ft = obj(nlp, x + (t*scale)*d)
          nbk = NaN
          nbW = NaN
        elseif linesearch==_backtracking2!
          x_out = copy(x)
          s = d*scale
          x_scratch = copy(x)
          lsr = LineSearchResults{Float64}([0.0],[f],[slope*scale],0)
          t = linesearch(nlp, x_out, s, x_scratch, lsr; kwargs...)
          good_grad = false
          ft = obj(nlp, x + (t*scale)*d)
          nbk = NaN
          nbW = NaN
        else
          t, good_grad, ft, nbk, nbW = linesearch(h, f, slope*scale, ∇ft, verbose=verboseLS; kwargs...)
        end
        #print_with_color(:green,"après le linesearch \n")
        #println("t=",t)
        t *= scale
        verbose && @printf("  %4d  %8e  %8e \n", nbk, t, scale)

        xt = x + t*d

        good_grad || (∇ft = grad!(nlp, xt, ∇ft))
        # Move on.
        s = xt - x
        y = ∇ft - ∇f
        β = 0.0
        if (∇ft⋅∇f) < 0.2 * (∇ft⋅∇ft)   # Powell restart
            β = CG_formula(∇f,∇ft,s,d)
        end
        if scaling
            scale = (y⋅s) / (y⋅y)
        end
        if scale <= 0.0
            #println(" scale = ",scale)
            #println(" ∇f⋅s = ",∇f⋅s,  " ∇ft⋅s = ",∇ft⋅s)
            scale = 1.0
        end
        x = xt
        f = ft
        BLAS.blascopy!(n, ∇ft, 1, ∇f, 1)

        # norm(∇f) bug: https://github.com/JuliaLang/julia/issues/11788
        ∇fNorm = norm(∇f, Inf)
        iter = iter + 1

        # if iter >= 915
        #   verboseLS = true
        # end

        verbose && @printf("%4d  %8.1e  %7.1e", iter, f, ∇fNorm)

        optimal = ∇fNorm <= ϵ
        tired = nlp.counters.neval_obj + nlp.counters.neval_grad > max_eval
    end
    verbose && @printf("\n")

    status = tired ? "maximum number of evaluations" : "first-order stationary"
    return (x, f, ∇fNorm, iter, optimal, tired, status)
end
