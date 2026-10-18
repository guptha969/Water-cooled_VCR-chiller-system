function [out, info] = blk_expansion(in, par, on, Pdown, opening)
%BLK_EXPANSION  Thermostatic / electronic expansion valve (throttling block).
%   in      refrigerant stream from the condenser (liquid line)
%   Pdown   pressure downstream of the valve = evaporator pressure [Pa]
%   opening valve opening 0..1, or NaN = automatic (valve opens just enough to pass the
%           circulating flow, which is what a superheat-controlling TXV does)
%
%   Equations
%     orifice flow     mdot_valve = Cd * A_max * opening * sqrt( 2 * rho_in * (P_in - P_down) )
%     throttling       h_out = h_in                      (isenthalpic, no work or heat)
%     pressure drop    P_out = P_down   ->   dP = P_in - P_down
%   Flash gas appears as vapour quality x_out > 0 because the liquid cools to T_sat(P_down).
%   OFF: out = in (valve fully bypassed, no pressure drop).
info.name = 'Expansion valve'; info.on = on; info.dP = 0; info.mdot_cap = NaN;
info.opening = NaN; info.Q = 0; info.W = 0; info.note = '';
if ~on
    out = in; info.note = 'BYPASSED: out = in, no pressure drop'; return;
end
dP = max(in.P - Pdown, 0);
k = par.Cd*par.A_max*sqrt(2*in.rho*dP);          % kg/s at 100 % opening
if isnan(opening)
    if k > 0 && in.mdot > 0
        opening = min(1, max(0.05, in.mdot/k));
    else
        opening = 0.05;
    end
end
info.opening = opening;
info.mdot_cap = k*opening;
info.dP = dP;
out = ref_props('state', Pdown, in.h, in.mdot);      % isenthalpic: h_out = h_in
info.note = sprintf('dP = %.0f kPa, flash-gas x = %.2f', dP/1e3, out.x);
if opening >= 0.999 && in.mdot > info.mdot_cap*1.001
    info.note = [info.note ' | VALVE FULLY OPEN: refrigerant starved'];
end
end
