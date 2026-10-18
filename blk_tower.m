function [out, info] = blk_tower(in, amb, par, on)
%BLK_TOWER  Induced-draft cooling tower (evaporative cooling of condenser water).
%   in    hot water from the condenser
%   amb   ambient struct with field Twb (wet-bulb temperature, degC)
%
%   Equations
%     NTU   = NTU_des * (mdot_w/mdot_w_des)^(-0.6)       (more water -> lower effectiveness)
%     eps   = 1 - exp(-NTU)
%     T_out = T_in - eps*(T_in - T_wb)                    (can never go below the wet-bulb)
%     Q     = mdot_w*cp*(T_in - T_out)
%     evaporation = Q/h_fg,  blowdown = evaporation/(cycles-1),  makeup = evaporation + blowdown
%   OFF (fan stopped): out = in, the tower is bypassed and rejects no heat.
info.name = 'Cooling tower'; info.on = on; info.Q = 0; info.W = 0; info.makeup = 0; info.note = '';
out = in;
if ~on
    info.note = 'BYPASSED: out = in, no heat rejected'; return;
end
info.W = par.P_fan;
if in.mdot <= 1e-9
    info.note = 'no water flow'; return;
end
NTU = par.NTU*(in.mdot/par.mdot_w_des)^(-0.6);
eps = 1 - exp(-NTU);
Tout = in.T - max(0, eps*(in.T - amb.Twb));
Q = in.mdot*in.cp*(in.T - Tout);
out.T = Tout;
evap = Q/2.43e6;
info.Q = Q; info.makeup = evap*(1 + 1/(par.cycles - 1));
info.eps = eps; info.approach = Tout - amb.Twb;
info.note = sprintf('water %.1f -> %.1f degC, approach %.1f K, makeup %.1f L/h', ...
                    in.T, Tout, Tout - amb.Twb, info.makeup*3600);
end
