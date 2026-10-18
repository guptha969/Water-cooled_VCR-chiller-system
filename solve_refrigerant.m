function [R, ok] = solve_refrigerant(P, D, ctl, wev, wcd, speed, x0, m0)
%SOLVE_REFRIGERANT  Close the refrigerant loop  EVAPORATOR -> COMPRESSOR -> CONDENSER -> EXPANSION VALVE.
%   The four blocks are chained in that order. The ring is "torn" at the condenser outlet and
%   two unknowns are iterated (Newton, finite-difference Jacobian):
%        x = [ T_evap ; T_cond ]
%   Given x the chain is run: valve -> evaporator -> compressor -> condenser, and two residuals
%   must vanish:
%     r2 (always)    condenser-outlet enthalpy from the condenser energy balance  =  h assumed
%                    from the charge, i.e. liquid subcooled by P.subcool at T_cond
%     r1 (valve mode) manual: compressor flow = valve orifice flow
%                     auto  : evaporator outlet enthalpy = enthalpy at P.superheat above T_evap
%   Inputs wev / wcd are the water streams entering the evaporator / condenser.
mref = m0;
Tmax_e = wev.T - 0.3; Tmin_c = wcd.T + 1.0;
lim = @(x) [min(max(x(1), -18), Tmax_e); min(max(x(2), Tmin_c), 72)];
% starting guesses: caller's warm start first, then guesses based on the water inlet temperatures
starts = {x0(:), [wev.T - 10; wcd.T + 10], [wev.T - 6; wcd.T + 14], [wev.T - 14; wcd.T + 8]};
ok = false;
for s0 = 1:numel(starts)
    x = lim(starts{s0});
    [r, ~] = loop_eval(x, mref);
    for it = 1:30
        if norm(r) < 2e-4, ok = true; break; end
        J = zeros(2, 2); dx = 0.03;
        for j = 1:2
            xp = x; xp(j) = xp(j) + dx;
            [rp, ~] = loop_eval(xp, mref);
            J(:, j) = (rp - r)/dx;
        end
        if rcond(J) < 1e-10, step = -r; else, step = -J\r; end
        step = max(min(step, 4), -4);
        a = 1; improved = false;
        for ls = 1:5
            xn = lim(x + a*step);
            [rn, ~] = loop_eval(xn, mref);
            if norm(rn) < norm(r), improved = true; break; end
            a = a/2;
        end
        if ~improved, break; end
        x = xn; r = rn;
    end
    if ok || norm(r) < 2e-3, ok = true; break; end
end
[r, R] = loop_eval(x, mref);
R.iterations = it; R.residual = norm(r); R.ok = ok || norm(r) < 2e-3; ok = R.ok;

    function [res, R] = loop_eval(x, m)
        Te = x(1); Tc = x(2);
        Pe = ref_props('Psat', Te); Pc = ref_props('Psat', Tc);
        h3 = ref_props('h_liq', Tc - P.subcool, Pc);             % liquid line set by the charge
        opening = NaN; if ~ctl.exv_auto, opening = ctl.exv_open; end
        for k = 1:4
            S3 = ref_props('state', Pc, h3, m);
            [S4, iex] = blk_expansion(S3, D.exv, true, Pe, opening);
            [S1, wev_out, iev] = blk_evaporator(S4, wev, D.evap, true);
            [S2, ico] = blk_compressor(S1, D.comp, true, Pc, speed);
            if ico.mdot > 0, m = 0.3*m + 0.7*ico.mdot; end
        end
        [S3c, wcd_out, icd] = blk_condenser(S2, wcd, D.cond, true);
        res = zeros(2, 1);
        if ctl.exv_auto
            h1t = ref_props('state_PT', Pe, Te + P.superheat, 1).h;
            res(1) = (S1.h - h1t)/1e4;
        else
            res(1) = (ico.mdot - iex.mdot_cap)/D.m_des;
        end
        res(2) = (S3c.h - h3)/1e4;
        R.S1 = S1; R.S2 = S2; R.S3 = S3c; R.S4 = S4; R.m = m;
        R.Te = Te; R.Tc = Tc; R.Pe = Pe; R.Pc = Pc;
        R.info.exv = iex; R.info.evap = iev; R.info.comp = ico; R.info.cond = icd;
        R.wev_out = wev_out; R.wcd_out = wcd_out;
        R.Q_evap = iev.Q; R.Q_cond = icd.Q; R.W_comp = ico.W; R.opening = iex.opening;
    end
end
