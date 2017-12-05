"""
```
initial_draw(m::AbstractModel, data::Array{Float64}, c::ParticleCloud)
```

Draw from a general starting distribution (set by default to be from the prior) to initialize the SMC algorithm.
Returns a tuple (logpost, loglh) and modifies the particle objects in the particle cloud in place.

"""
function initial_draw(m::AbstractModel, data::Array{Float64}, c::ParticleCloud)
    dist_type = get_setting(m, :initial_draw_source)
    if dist_type == :normal
        params = zeros(n_parameters(m))
        hessian = zeros(n_parameters(m),n_parameters(m))
        try
            file = h5open(rawpath(m, "estimate", "paramsmode.h5"), "r")
            params = read(file,"params")
            close(file)
        catch
            throw("There does not exist a valid mode file at "*rawpath(m,"estimate","paramsmode.h5"))
        end

        try
            file = h5open(rawpath(m, "estimate", "hessian.h5"), "r")
            hessian = read(file, "hessian")
            close(file)
        catch
            throw("There does not exist a valid hessian file at "*rawpath(m,"estimate","hessian.h5"))
        end

        S_diag, U = eig(hessian)
        big_eig_vals = find(x -> x>1e-6, S_diag)
        rank = length(big_eig_vals)
        n = length(params)
        S_inv = zeros(n, n)
        for i = (n-rank+1):n
            S_inv[i, i] = 1/S_diag[i]
        end
        hessian_inv = U*sqrt(S_inv)
        dist = DSGE.DegenerateMvNormal(params, hessian_inv)
    end

    n_part = length(c)
    draws =
    dist_type == :prior ? rand(m.parameters, n_part) : rand(dist, n_part)

    loglh = zeros(n_part)
    logpost = zeros(n_part)
    for i in 1:size(draws)[2]
        success = false
        while !success
            try
                update!(m, draws[:, i])
                loglh[i] = likelihood(m, data)
                logpost[i] = prior(m)
            catch
                draws[:, i] =
                dist_type == :prior ? rand(m.parameters, 1) : rand(dist, 1)
                continue
            end
            success = true
        end
    end
    update_draws!(c, draws)
    update_loglh!(c, loglh)
    update_logpost!(c, logpost)
end

"""
```
mvnormal_mixture_draw{T<:AbstractFloat}(p, Σ; cc, α, d_prop)
```

Create a `DegenerateMvNormal` distribution object, `d`, from a parameter vector, `p`, and a
covariance matrix, `Σ`.

Generate a draw from the mixture distribution of the `DegenerateMvNormal` scaled by `cc^2`
and with mixture proportion `α`, a `DegenerateMvNormal` centered at the same mean, but with a
covariance matrix of the diagonal entries of `Σ` scaled by `cc^2` with mixture
proportion `(1 - α)/2`, and an additional proposed distribution with the same covariance
matrix as `d` but centered at the new proposed mean, `p_prop`, scaled by `cc^2`, and with mixture proportion `(1 - α)/2`.

If no `p_prop` is given, but an `α` is specified, then the mixture will consist of `α` of
the standard distribution and `(1 - α)` of the diagonalized covariance distribution.

### Arguments
`p`: The mean of the desired distribution
`Σ`: The standard deviation of the desired distribution

"""
function mvnormal_mixture_draw{T<:AbstractFloat}(p::Vector{T}, Σ::Matrix{T};
                                                 cc::T = 1.0, α::T = 1.,
                                                 p_prop::Vector{T} = zeros(length(p)))
    @assert 0 <= α <= 1
    d = DegenerateMvNormal(p, Σ)
    d_diag = DegenerateMvNormal(p, diagm(diag(Σ)))
    d_prop = p_prop == zeros(length(p)) ? d_diag : DegenerateMvNormal(p_prop, Σ)

    normal_component = α*(d.μ + cc*d.σ*randn(length(d)))
    diag_component   = (1 - α)/2*(d_diag.μ + cc*d_diag.σ*randn(length(d_diag)))
    proposal_component   = (1 - α)/2*(d_prop.μ + cc*d_prop.σ*randn(length(d_prop)))

    return normal_component + diag_component + proposal_component
end


function init_stage_print(cloud::ParticleCloud; verbose::Symbol=:low)
	println("--------------------------")
        println("Iteration = $(cloud.stage_index) / $(cloud.n_Φ)")
	println("--------------------------")
        println("phi = $(cloud.tempering_schedule[cloud.stage_index])")
	println("--------------------------")
        println("c = $(cloud.c)")
	println("--------------------------")
    if VERBOSITY[verbose] >= VERBOSITY[:high]
        μ = weighted_mean(cloud)
        σ = weighted_std(cloud)
        for n=1:length(cloud.particles[1])
            println("$(cloud.particles[1].keys[n]) = $(round(μ[n], 5)), $(round(σ[n], 5))")
	    end
    end
end

function end_stage_print(cloud::ParticleCloud, total_sampling_time::Float64; verbose::Symbol=:low)
    total_sampling_time_minutes = total_sampling_time/60
    expected_time_remaining_sec = (total_sampling_time/cloud.stage_index)*(cloud.n_Φ - cloud.stage_index)
    expected_time_remaining_minutes = expected_time_remaining_sec/60

    println("--------------------------")
        println("Iteration = $(cloud.stage_index) / $(cloud.n_Φ)")
        println("time elapsed: $(round(total_sampling_time_minutes, 4)) minutes")
        println("estimated time remaining: $(round(expected_time_remaining_minutes, 4)) minutes")
    println("--------------------------")
        println("phi = $(cloud.tempering_schedule[cloud.stage_index])")
    println("--------------------------")
        println("c = $(cloud.c)")
        println("accept = $(cloud.accept)")
        println("ESS = $(cloud.ESS)   ($(cloud.resamples) total resamples.)")
    println("--------------------------")
    if VERBOSITY[verbose] >= VERBOSITY[:high]
        μ = weighted_mean(cloud)
        σ = weighted_std(cloud)
        for n=1:length(cloud.particles[1])
            println("$(cloud.particles[1].keys[n]) = $(round(μ[n], 5)), $(round(σ[n], 5))")
        end
    end
end
