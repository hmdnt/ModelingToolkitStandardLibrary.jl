"""
    HeatCapacitor(; name, C, T = 273.15 + 20)

Lumped thermal element storing heat

# States:

  - `T`: [`K`] Temperature of element. It accepts an initial value, which defaults to 273.15 + 20.
  - `der_T`: [`K/s`] Time derivative of temperature

# Connectors:

  - `port`

# Parameters:

  - `C`: [`J/K`] Heat capacity of element (= cp*m)
"""
@mtkmodel HeatCapacitor begin
    @components begin
        port = HeatPort()
    end
    @parameters begin
        C, [description = "Heat capacity of element"]
    end
    @variables begin
        T(t) = 273.15 + 20
        der_T(t) = 0.0
    end

    @equations begin
        T ~ port.T
        der_T ~ port.Q_flow / C
        D(T) ~ der_T
    end
end

"""
    ThermalConductor(; name, G)

Lumped thermal element transporting heat without storing it.

# States:

see [`Element1D`](@ref)

# Connectors:

`port_a`
`port_b`

# Parameters:

  - `G`: [`W/K`] Constant thermal conductance of material
"""
@mtkmodel ThermalConductor begin
    @extend Q_flow, dT = element1d = Element1D()
    @parameters begin
        G
    end
    @equations begin
        Q_flow ~ G * dT
    end
end

"""
    ThermalResistor(; name, R)

Lumped thermal element transporting heat without storing it.

# States:

  - `dT`:  [`K`] Temperature difference across the component a.T - b.T
  - `Q_flow`: [`W`] Heat flow rate from port a -> port b

# Connectors:

  - `port_a`
  - `port_b`

# Parameters:

  - `R`: [`K/W`] Constant thermal resistance of material
"""
@mtkmodel ThermalResistor begin
    @extend Q_flow, dT = element1d = Element1D()
    @parameters begin
        R
    end
    @equations begin
        dT ~ R * Q_flow
    end
end

"""
    ThermalDistributedResistor(; name, R, C, n)

Distributed thermal element transporting heat with the ability to store it.

# States:

  - `T(t)[1:n+2]`   :  [`K`] Temperature of subdivisions
  - `dT`            :  [`K`] Temperature difference across the component a.T - b.T

# Connectors:

  - `port_a`
  - `port_b`

# Parameters:

  - `R`: [`K/W`] Constant thermal resistance of material
  - `C`: [`J/K`] Constant thermal capacitance of material
  - `n`: Number of subdivisions
"""

@component function ThermalDistributedResistor(; name, R, C, n=1)
    sts = @variables (T(t))[1:n+2] dT(t)

    @named port_a = HeatPort()
    @named port_b = HeatPort()
    n1 = n + 2
    Re = R/n
    Ce = C/n

    eqs = [
        dT ~ T[1] - T[n1];
        T[1] ~ port_a.T;
        T[n1] ~ port_b.T;
        port_a.Q_flow ~ (T[1] - T[2])*2/Re;
        port_b.Q_flow ~ -(T[n1-1] - T[n1])*2/Re;
        [D(T[i]) ~ (T[i-1] - 2*T[i] + T[i+1])/(Re*Ce) for i in 2:n1-1]...;
    ]
    return ODESystem(eqs, t, [sts...;], []; systems = [port_a, port_b], name = name)
end

"""
    ConvectiveConductor(; name, G)

Lumped thermal element for heat convection.

# States:

  - `dT`:  [`K`] Temperature difference across the component `solid.T` - `fluid.T`
  - `Q_flow`: [`W`] Heat flow rate from `solid` -> `fluid`

# Connectors:

  - `solid`
  - `fluid`

# Parameters:

  - `G`: [W/K] Convective thermal conductance
"""
@mtkmodel ConvectiveConductor begin
    @extend Q_flow, dT = convective_element1d = ConvectiveElement1D()
    @parameters begin
        G
    end
    @equations begin
        Q_flow ~ G * dT
    end
end

"""
    ConvectiveResistor(; name, R)

Lumped thermal element for heat convection.

# States:

  - `dT`: [`K`] Temperature difference across the component `solid.T` - `fluid.T`
  - `Q_flow`: [`W`] Heat flow rate from `solid` -> `fluid`

# Connectors:

  - `solid`
  - `fluid`

# Parameters:

  - `R`: [`K/W`] Constant thermal resistance of material
"""
@mtkmodel ConvectiveResistor begin
    @extend Q_flow, dT = convective_element1d = ConvectiveElement1D()
    @parameters begin
        R
    end
    @equations begin
        dT ~ R * Q_flow
    end
end

"""
    BodyRadiation(; name, G)

Lumped thermal element for radiation heat transfer.

# States:

  - `dT`:  [`K`] Temperature difference across the component a.T - b.T
  - `Q_flow`: [`W`] Heat flow rate from port a -> port b

# Connectors:

  - `port_a`
  - `port_b`

# Parameters:

  - `G`: [m^2] Net radiation conductance between two surfaces # Stefan-Boltzmann constant TODO: extract into physical constants module or use existing one
"""
@mtkmodel BodyRadiation begin
    begin
        sigma = 5.6703744191844294e-8 # Stefan-Boltzmann constant TODO: extract into physical constants module or use existing one
    end

    @extend Q_flow, dT, port_a, port_b = element1d = Element1D()
    @parameters begin
        G
    end
    @equations begin
        Q_flow ~ G * sigma * (port_a.T^4 - port_b.T^4)
    end
end

"""
    ThermalCollector(; name, m = 1)

Collects `m` heat flows

This is a model to collect the heat flows from `m` heatports to one single heatport.

# States:

# Connectors:

  - `port_a1` to `port_am`
  - `port_b`

# Parameters:

  - `m`: Number of heat ports (e.g. m=2: `port_a1`, `port_a2`)
"""
@component function ThermalCollector(; name, m::Integer = 1)
    port_a = [HeatPort(name = Symbol(:port_a, i)) for i in 1:m]
    @named port_b = HeatPort()
    eqs = [port_b.Q_flow + sum(k -> k.Q_flow, port_a) ~ 0
        port_b.T ~ port_a[1].T]
    for i in 1:(m - 1)
        push!(eqs, port_a[i].T ~ port_a[i + 1].T)
    end
    ODESystem(eqs, t, [], []; systems = [port_a..., port_b], name = name)
end
