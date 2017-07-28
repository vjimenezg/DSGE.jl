"""
```
density(φ_new::Float64, φ_old::Float64, yt::Array{Float64,1}, perror::Array{Float64,1}, EE::Array;initialize::Int64=0)
```
Returns the appropriate probability (right now from a Normal distribution) evaluated at perror.
"""

function density(φ_new::Float64, φ_old::Float64, yt::Array{Float64,1}, perror::Array{Float64,1}, EE::Array{Float64,2};initialize::Int64=0)
    # Non-initialization step (tempering and final iteration)
    if initialize==0
        return (φ_new/φ_old)^(length(yt)/2)*exp(-1/2*perror'*(φ_new-φ_old)*inv(EE)*perror)[1]
    # Initialization step (using 2π instead of φ_old)
    else
        return ((φ_new/(2*pi))^(length(yt)/2)*(det(EE)^(-1/2))*exp((-1/2)*perror'*φ_new*inv(EE)*perror))[1]
    end
 end