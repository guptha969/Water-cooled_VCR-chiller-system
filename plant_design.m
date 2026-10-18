function D = plant_design(P)
%PLANT_DESIGN  Size every block from the design duty so the whole plant is consistent.
%   Design point: Te_des / Tc_des, 12/7 degC chilled water, 32/37 degC condenser water.
cpw = 4180;
Q = P.Q_chiller;
Te = P.Te_des; Tc = P.Tc_des;
Pe = ref_props('Psat', Te); Pc = ref_props('Psat', Tc);

% --- design refrigerant cycle
S1 = ref_props('state_PT', Pe, Te + P.superheat, 1);
h3 = ref_props('h_liq', Tc - P.subcool, Pc);
S3 = ref_props('state', Pc, h3, 1);
S4 = ref_props('state', Pe, h3, 1);
m = Q/(S1.h - S4.h);
h2s = ref_props('h_isen', Pc, S1.s);
h2 = S1.h + (h2s - S1.h)/P.eta_is;
Qc = m*(h2 - h3);
D.m_des = m; D.Qc_des = Qc; D.W_des = m*(h2 - S1.h)/P.eta_motor; D.COP_des = Q/D.W_des;

% --- compressor
PR = Pc/Pe;
comp.type = P.comp_type; comp.rpm = P.rpm; comp.eta_is = P.eta_is; comp.eta_motor = P.eta_motor;
comp.clearance = P.clearance; comp.poly_n = P.poly_n;
eta_v = 1 - P.clearance*(PR^(1/P.poly_n) - 1);
comp.Vdisp = m/(S1.rho*(P.rpm/60)*eta_v);
if strcmp(P.comp_type, 'centrifugal')
    ratio = 0.55;                                   % design point sits at 55 % of head capability
    dh0 = (h2s - S1.h)/ratio;
    U = sqrt(dh0/P.cf_psi);
    comp.rpm = P.cf_rpm; comp.psi = P.cf_psi; comp.surge_frac = P.cf_surge;
    comp.D = 60*U/(pi*comp.rpm);
    comp.phi_max = m/(sqrt(1 - ratio)*S1.rho*U*comp.D^2);
end
D.comp = comp;

% --- heat exchangers
mw_ev = Q/(cpw*(P.T_chw_ret - P.T_chw_sup));
eps_e = (P.T_chw_ret - P.T_chw_sup)/(P.T_chw_ret - Te);
D.evap.UA = -mw_ev*cpw*log(1 - eps_e); D.evap.mdot_w_des = mw_ev; D.evap.dP = 0;
mw_cd = Qc/(cpw*(P.T_cw_out - P.T_cw_in));
eps_c = (P.T_cw_out - P.T_cw_in)/(Tc - P.T_cw_in);
D.cond.UA = -mw_cd*cpw*log(1 - eps_c); D.cond.mdot_w_des = mw_cd; D.cond.dP = 0;
D.mdot_chw = mw_ev; D.mdot_cw = mw_cd;

% --- expansion valve (design opening 60 %)
dP = Pc - Pe;
A_des = m/(P.exv_Cd*sqrt(2*S3.rho*dP));
D.exv.Cd = P.exv_Cd; D.exv.A_max = A_des/P.exv_open_des;

% --- pumps
D.pump_chw = pump_(mw_ev, P.dP_chw, P, 'CHW pump');
D.pump_cw  = pump_(mw_cd, P.dP_cw, P, 'CW pump');

% --- fan-coil units: one per room, sized for oversize * its peak load
for i = 1:numel(P.room_names)
    Qi = P.fcu_oversize*max(P.Q24(:, i));
    Cw = Qi/5;                                       % 5 K water rise
    Ca = Qi/P.fcu_air_dT;                            % total-heat equivalent air capacity rate
    Cmin = min(Ca, Cw); Cmax = max(Ca, Cw); Cr = Cmin/Cmax;
    eps = Qi/(Cmin*(P.T_set_room - P.T_chw_sup));
    NTU = log((1 - eps*Cr)/(1 - eps))/(1 - Cr);
    f.name = ['FCU ' P.room_names{i}]; f.UA = NTU*Cmin; f.mdot_w_des = Cw/cpw;
    f.cp_eff = 1006/P.SHR; f.m_air = Ca/f.cp_eff;
    f.P_blower = (f.m_air/1.12)*150/0.4;             % 150 Pa, 40 % fan efficiency
    f.Qdes = Qi;
    D.fcu(i) = f;
end
D.fcu_share = [D.fcu.mdot_w_des]/sum([D.fcu.mdot_w_des]);

% --- cooling tower (design wet-bulb 28 degC)
eps_t = (P.T_cw_out - P.T_cw_in)/(P.T_cw_out - P.tower_Twb_des);
D.tower.NTU = -log(1 - eps_t); D.tower.mdot_w_des = mw_cd;
D.tower.P_fan = 0.03*Qc; D.tower.cycles = P.tower_cycles;

% --- loop water inertia
D.C_chw = P.V_chw*997*cpw; D.C_cw = P.V_cw*997*cpw;
D.design.S1 = S1; D.design.S3 = S3; D.design.S4 = S4; D.design.Pe = Pe; D.design.Pc = Pc;
D.design.PR = PR; D.design.eta_v = eta_v; D.design.h2 = h2; D.design.Q = Q;
end

function p = pump_(m, dP, P, name)
p.name = name; p.eta = P.eta_pump; p.mdot_max = P.pump_max_ratio*m;
p.K = dP/m^2;
p.dP0 = p.K*m^2/(1 - (m/p.mdot_max)^2);
end
