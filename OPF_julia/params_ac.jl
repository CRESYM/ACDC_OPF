"""
    params_ac(acgrid_name::String, dcgrid_name::String) -> NamedTuple

The function processes the entire AC network data grid-by-grid, 
compute and return AC grid parameters.

Returns a NamedTuple with the following fields:
  - network_ac        : Dict. AC network containing all network data.
  - ngrids            : Int64. Number of AC grids.
  - baseMVA_ac        : Int64. AC base MVA.
  - bus_entire_ac     : Matrix{Float64}. Complete bus data (filtered by voltage level).
  - branch_entire_ac  : Matrix{Float64}. Complete branch data (filtered by a branch flag).
  - gen_entire_ac     : Matrix{Float64}. Complete generator data.
  - gencost_entire_ac : Matrix{Float64}. Complete generation cost data.
  - res_entire_ac     : Matrix{Float64}. Complete RES data.
  - bus_ac            : Vector{Matrix{Float64}}. Bus data for each AC grid.
  - branch_ac         : Vector{Matrix{Float64}}. Branch data for each AC grid.
  - generator_ac      : Vector{Matrix{Float64}}. Generator data for each AC grid.
  - gencost_ac        : Vector{Matrix{Float64}}. Generator cost for each AC grid.
  - res_ac            : Vector{Matrix{Float64}}. RES data for each AC grid.
  - recRef_ac         : Vector{Vector{Int64}}. Recording the reference bus for each AC grid.
  - pd_ac             : Vector{Vector{Float64}}. Active loads (per unit).
  - qd_ac             : Vector{Vector{Float64}}. Rective loads (per unit).
  - sres_ac           : Vector{Vector{Float64}}. RES capacity (per unit).
  - nbuses_ac         : Vector{Int64}. Number of buses for each AC grid.
  - nbranches_ac      : Vector{Int64}. Number of branches for each AC grid.
  - ngens_ac          : Vector{Int64}. Number of generators for each AC grid.
  - nress_ac          : Vector{Int64.} Number of RESs for each AC grid.
  - GG_ac, BB_ac      : Vector{Matrix{Float64}}. Real and Imaginary parts of the AC admittance matrix (per unit).
  - GG_ft_ac, BB_ft_ac: Vector{Vector{Float64}}. Branch off-diagonal entries (from-to) (per unit).
  - GG_tf_ac, BB_tf_ac: Vector{Vector{Float64}}. Branch off-diagonal entries (to-from) (per unit).
  - fbus_ac, tbus_ac  : Vector{Vector{Int64}}. "From" and "to” bus indices per grid.

See also: create_ac.jl, makeYbus.jl
"""
function params_ac(acgrid_name::String)::NamedTuple

    #--------------------------------------------------------------------------
    # 1. Load AC grid data 
    #--------------------------------------------------------------------------
    network_ac = create_ac(acgrid_name)
    baseMVA_ac = network_ac["baseMVA"]

    # AC bus and branch data
    bus_entire_ac = network_ac["bus"]
    branch_entire_ac = network_ac["branch"][network_ac["branch"][:, 11] .== 1, :]

    # Generator and generation cost data
    gen_entire_ac = network_ac["generator"]
    gencost_entire_ac = network_ac["gencost"]

    # RES data
    res_entire_ac = network_ac["res"]

    # Determine number of AC grids from bus data 
    ngrids = length(unique(bus_entire_ac[:, 14]))

    #--------------------------------------------------------------------------
    # 2. Initialize arrays to store grid data
    #--------------------------------------------------------------------------
    bus_ac       = Vector{Matrix{Float64}}(undef, ngrids)
    branch_ac    = Vector{Matrix{Float64}}(undef, ngrids)
    generator_ac = Vector{Matrix{Float64}}(undef, ngrids)
    gencost_ac   = Vector{Matrix{Float64}}(undef, ngrids)
    res_ac       = Vector{Matrix{Float64}}(undef, ngrids)
    pd_ac        = Vector{Vector{Float64}}(undef, ngrids)
    qd_ac        = Vector{Vector{Float64}}(undef, ngrids)
    sres_ac      = Vector{Vector{Float64}}(undef, ngrids)
    nbuses_ac    = Vector{Int}(undef, ngrids)
    nbranches_ac = Vector{Int}(undef, ngrids)
    ngens_ac     = Vector{Int}(undef, ngrids)
    nress_ac     = Vector{Int}(undef, ngrids)

    # AC network admittance components for each grid
    YY_ac = Vector{Matrix{Complex{Float64}}}(undef, ngrids)
    GG_ac = Vector{Matrix{Float64}}(undef, ngrids)
    BB_ac = Vector{Matrix{Float64}}(undef, ngrids)
    
    # Branch indices and flow parameters for each grid
    fbus_ac   = Vector{Vector{Int}}(undef, ngrids)
    tbus_ac   = Vector{Vector{Int}}(undef, ngrids)
    GG_ft_ac  = Vector{Vector{Float64}}(undef, ngrids)
    BB_ft_ac  = Vector{Vector{Float64}}(undef, ngrids)
    GG_tf_ac  = Vector{Vector{Float64}}(undef, ngrids)
    BB_tf_ac  = Vector{Vector{Float64}}(undef, ngrids)
    
    # Reference bus information for each grid
    IDtoCountmap = Vector{Vector{Int}}(undef, ngrids)
    refbuscount  = Vector{Int}(undef, ngrids)
    recRef_ac    = Vector{Vector{Int}}(undef, ngrids)

    #--------------------------------------------------------------------------
    # 3. Process each AC grid separately
    #--------------------------------------------------------------------------
    for ng in 1:ngrids
        
        recRef_ac[ng] = Int[]

        # Partition bus, branch, generator, and gencost data for grid #ng
        bus_ac[ng] = bus_entire_ac[bus_entire_ac[:, 14] .== ng, :]
        branch_ac[ng] = branch_entire_ac[branch_entire_ac[:, 14] .== ng, :]
        generator_ac[ng] = gen_entire_ac[gen_entire_ac[:, 22] .== ng, :]
        gencost_ac[ng] = gencost_entire_ac[gencost_entire_ac[:, 8] .== ng, :]
        res_ac[ng] = res_entire_ac[res_entire_ac[:, 12] .== ng, :]

        # Record the number of buses, branches, generators, RESs in grid #ng
        nbuses_ac[ng] = size(bus_ac[ng], 1)
        nbranches_ac[ng] = size(branch_ac[ng], 1)
        ngens_ac[ng] = size(generator_ac[ng], 1)
        nress_ac[ng] = size(res_ac[ng], 1)

        # Record the reference bus index in grid #ng
        IDtoCountmap[ng] = zeros(Int, nbuses_ac[ng])
        refbuscount[ng] = 0
        for i in 1:nbuses_ac[ng]
            ID = Int(bus_ac[ng][i, 1])
            IDtoCountmap[ng][ID] = i  
            # Mark as reference bus
            if bus_ac[ng][i, 2] == 3  
                refbuscount[ng] = i  
            end
        end
        push!(recRef_ac[ng], refbuscount[ng])

        # Compute AC network admittance matrix
        YY_ac[ng] = makeYbus(baseMVA_ac, bus_ac[ng], branch_ac[ng])
        GG_ac[ng] = real.(YY_ac[ng])
        BB_ac[ng] = imag.(YY_ac[ng])
        
        # Extract branch "from" and "to" indices for grid #ng
        fbus_ac[ng] = Int.(branch_ac[ng][:, 1])
        tbus_ac[ng] = Int.(branch_ac[ng][:, 2])
        GG_ft_ac[ng] = GG_ac[ng][CartesianIndex.(fbus_ac[ng], tbus_ac[ng])]  
        BB_ft_ac[ng] = BB_ac[ng][CartesianIndex.(fbus_ac[ng], tbus_ac[ng])]
        GG_tf_ac[ng] = GG_ac[ng][CartesianIndex.(tbus_ac[ng], fbus_ac[ng])]
        BB_tf_ac[ng] = BB_ac[ng][CartesianIndex.(tbus_ac[ng], fbus_ac[ng])]

        # Normalize load values
        pd_ac[ng] = bus_ac[ng][:, 3] / baseMVA_ac
        qd_ac[ng] = bus_ac[ng][:, 4] / baseMVA_ac

        # Normalize RES capacity
        sres_ac[ng] = res_ac[ng][:, 3] / baseMVA_ac
    end

    #--------------------------------------------------------------------------
    # 4. Return a NamedTuple containing all computed AC parameters
    #--------------------------------------------------------------------------
    return NamedTuple(( 
        network_ac = network_ac,
        baseMVA_ac = baseMVA_ac,
        bus_entire_ac = bus_entire_ac,
        branch_entire_ac = branch_entire_ac,
        gen_entire_ac = gen_entire_ac,
        gencost_entire_ac = gencost_entire_ac,
        res_entire_ac = res_entire_ac,
        ngrids = ngrids,
        bus_ac = bus_ac,
        branch_ac = branch_ac,
        generator_ac = generator_ac,
        gencost_ac = gencost_ac,
        res_ac = res_ac,
        recRef_ac = recRef_ac,
        pd_ac = pd_ac,
        qd_ac = qd_ac,
        sres_ac = sres_ac,
        nbuses_ac = nbuses_ac,
        nbranches_ac = nbranches_ac,
        ngens_ac = ngens_ac,
        nress_ac = nress_ac, 
        GG_ac = GG_ac,
        BB_ac = BB_ac,
        GG_ft_ac = GG_ft_ac,
        BB_ft_ac = BB_ft_ac,
        GG_tf_ac = GG_tf_ac,
        BB_tf_ac = BB_tf_ac,
        fbus_ac = fbus_ac,
        tbus_ac = tbus_ac
    ))
end

