function [out, info] = blk_compressor(in, par, on, Pdisch, speed)
%BLK_COMPRESSOR  Reciprocating or centrifugal compressor block.
%   in       refrigerant stream at suction (P, T, h, s, rho ...)
%   Pdisch   discharge pressure demanded by the condenser side [Pa]
%   speed    speed fraction 0..1 of rated speed (inverter / unloading)
%
%   Common equations
%     h_2s = h(P_disch, s_in)                    isentropic end state (property tables)
%     h_2  = h_in + (h_2s - h_in)/eta_is          real discharge enthalpy
%     W_sh = mdot*(h_2 - h_in);   W_el = W_sh/eta_motor
%   Reciprocating (par.type = 'reciprocating')
%     eta_v = 1 - c*( (P_disch/P_in)^(1/n) - 1 )  clearance-volume effect
%     mdot  = rho_suction * V_disp * (N*speed/60) * eta_v
%   Centrifugal (par.type = 'centrifugal')
%     U = pi*D*N*speed/60,  head capability  dh0 = psi*U^2
%     characteristic   dh_is = dh0*(1 - (mdot/mdot_choke)^2),  mdot_choke = phi_max*rho*U*D^2
%     surge if mdot < surge_frac*mdot_choke (flag only)
%   OFF (or speed 0): out = in.
info.name = 'Compressor'; info.on = on; info.W = 0; info.Wsh = 0; info.mdot = 0; info.Q = 0;
info.PR = NaN; info.eta_v = NaN; info.note = ''; info.surge = false;
if ~on || speed <= 0
    out = in; info.note = 'BYPASSED/STOPPED: out = in, no pressure rise'; return;
end
PR = Pdisch/in.P;
h2s = ref_props('h_isen', Pdisch, in.s);
if strcmp(par.type, 'centrifugal')
    U = pi*par.D*par.rpm*speed/60;
    dh0 = par.psi*U^2;
    dh_req = h2s - in.h;
    mch = par.phi_max*in.rho*U*par.D^2;
    ratio = dh_req/dh0;
    if ratio >= 1
        m = 0; info.note = 'STALL: head demand exceeds capability';
    else
        m = mch*sqrt(1 - ratio);
        if m < par.surge_frac*mch
            info.surge = true; info.note = 'SURGE WARNING: flow below surge line';
        end
    end
    info.eta_v = NaN;
else
    eta_v = max(0, 1 - par.clearance*(PR^(1/par.poly_n) - 1));
    m = in.rho*par.Vdisp*(par.rpm*speed/60)*eta_v;
    info.eta_v = eta_v;
end
if m <= 0
    out = in; return;
end
h2 = in.h + (h2s - in.h)/par.eta_is;
out = ref_props('state', Pdisch, h2, m);
info.mdot = m; info.PR = PR;
info.Wsh = m*(h2 - in.h); info.W = info.Wsh/par.eta_motor;
if isempty(info.note)
    info.note = sprintf('PR = %.2f, W = %.2f kW, discharge %.1f degC', PR, info.W/1e3, out.T);
end
if ~isnan(in.x) && in.x < 0.999
    info.note = [info.note ' | WET SUCTION (liquid carry-over)'];
end
end
