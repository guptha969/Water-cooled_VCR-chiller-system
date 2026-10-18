function [out, info] = blk_pump(in, par, on, speed)
%BLK_PUMP  Centrifugal water pump working against a quadratic pipe-system curve.
%   Pump curve      dP_pump = dP0*speed^2 * (1 - (mdot/(mdot_max*speed))^2)
%   System curve    dP_sys  = K * mdot^2          (pipes, valves, coils, heat exchanger)
%   Operating point (solve pump = system):
%     mdot = speed * sqrt( dP0 / (K + dP0/mdot_max^2) )
%   Electric power   W = mdot*dP / (rho * eta_pump)
%   OFF: out = in (no flow is created, water stagnates).
info.name = par.name; info.on = on; info.W = 0; info.Q = 0; info.dP = 0; info.note = '';
out = in;
if ~on || speed <= 0
    info.note = 'BYPASSED/STOPPED: no flow created'; return;
end
m = speed*sqrt(par.dP0/(par.K + par.dP0/par.mdot_max^2));
dP = par.K*m^2;
out.mdot = m; out.vdot = m/997; out.P = in.P + dP;
info.dP = dP; info.mdot = m;
info.W = m*dP/(997*par.eta);
info.note = sprintf('%.2f kg/s (%.2f L/s), dP = %.0f kPa, %.0f W', m, m/0.997, dP/1e3, info.W);
end
