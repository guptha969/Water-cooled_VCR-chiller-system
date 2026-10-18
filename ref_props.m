function varargout = ref_props(fn, varargin)
%REF_PROPS  R134a thermodynamic properties from lookup tables (generated from CoolProp).
%   Units: P [Pa], T [degC], h [J/kg], s [J/kgK], rho [kg/m3]
%
%   Psat = ref_props('Psat', T)          Tsat = ref_props('Tsat', P)
%   hf/hg/sf/sg/rhof/rhog = ref_props('hf', T) ...   (saturated properties at T)
%   h    = ref_props('h_liq', T, P)      compressed-liquid enthalpy
%   h2s  = ref_props('h_isen', Pc, s1)   isentropic end enthalpy at pressure Pc
%   st   = ref_props('state', P, h, mdot)   full stream state (see below)
%   st   = ref_props('state_PT', P, T, mdot) stream state from P and T (single phase)
%
%   Stream fields returned by 'state':
%     P, T, h, s, rho, Tsat, x (quality, NaN if single phase), phase (text),
%     superheat (K, >0 only for vapour), subcool (K, >0 only for liquid),
%     mdot (kg/s), vdot (m3/s)
t = tables_();
switch fn
    case 'Psat',  varargout{1} = exp(iu_(t.lPsat, varargin{1}));
    case 'Tsat',  varargout{1} = tsat_(t, varargin{1});
    case 'hf',    varargout{1} = iu_(t.hf,   varargin{1});
    case 'hg',    varargout{1} = iu_(t.hg,   varargin{1});
    case 'sf',    varargout{1} = iu_(t.sf,   varargin{1});
    case 'sg',    varargout{1} = iu_(t.sg,   varargin{1});
    case 'rhof',  varargout{1} = iu_(t.rhof, varargin{1});
    case 'rhog',  varargout{1} = iu_(t.rhog, varargin{1});
    case 'h_liq'
        T = varargin{1}; P = varargin{2};
        Ps = exp(iu_(t.lPsat, T));
        varargout{1} = iu_(t.hf, T) + ...
                       iu_(t.dhdp, T)*(P - Ps);
    case 'h_isen'
        varargout{1} = h_isen_(t, varargin{1}, varargin{2});
    case 'state'
        if numel(varargin) < 3, varargin{3} = 0; end
        varargout{1} = state_(t, varargin{1}, varargin{2}, varargin{3});
    case 'state_PT'
        P = varargin{1}; T = varargin{2};
        if numel(varargin) < 3, varargin{3} = 0; end
        Tsat = tsat_(t, P);
        if T > Tsat
            row = vrow_(t, P);
            h = interp1(t.Tg(row.v), row.h(row.v), T, 'linear', 'extrap');
        else
            h = ref_props('h_liq', T, P);
        end
        varargout{1} = state_(t, P, h, varargin{3});
    otherwise
        error('ref_props: unknown function %s', fn);
end
end

%% ------------------------------------------------------------------
function t = tables_()
persistent T
if isempty(T)
    here = fileparts(mfilename('fullpath'));
    T = load(fullfile(here, 'r134a_props.mat'));
    T.lPsat = log(T.Psat);
    T.TsatP = interp1(log(T.Psat), T.Ts, log(T.Pg), 'linear', 'extrap');   % Tsat on the uniform pressure grid
end
t = T;
end

function row = vrow_(t, P)
% superheated-vapour properties along temperature at pressure P (cached, last few pressures)
persistent keys rows n
if isempty(keys), keys = nan(1, 8); rows = cell(1, 8); n = 0; end
k = find(abs(keys - P) < 1e-3, 1);
if ~isempty(k), row = rows{k}; return; end
i = floor((P - t.Pg(1))/10e3) + 1; i = min(max(i, 1), numel(t.Pg) - 1);
w = (P - t.Pg(i))/10e3;
row.h   = (1 - w)*t.H(i, :)   + w*t.H(i+1, :);
row.s   = (1 - w)*t.S(i, :)   + w*t.S(i+1, :);
row.rho = (1 - w)*t.RHO(i, :) + w*t.RHO(i+1, :);
row.v = ~isnan(row.h) & ~isnan(row.s);
n = mod(n, 8) + 1;
keys(n) = P; rows{n} = row;
end

function st = state_(t, P, h, mdot)
Tsat = tsat_(t, P);
hf = iu_(t.hf, Tsat);
hg = iu_(t.hg, Tsat);
st.P = P; st.h = h; st.Tsat = Tsat; st.mdot = mdot;
st.superheat = 0; st.subcool = 0; st.x = NaN;
if h <= hf                                            % subcooled liquid
    T = interp1(t.hf, t.Ts, h, 'linear', 'extrap');
    for it = 1:3
        corr = iu_(t.dhdp, T)*(P - exp(iu_(t.lPsat, T)));
        T = interp1(t.hf, t.Ts, h - corr, 'linear', 'extrap');
    end
    st.T = T;
    st.s = iu_(t.sf, T);
    st.rho = iu_(t.rhof, T);
    st.subcool = max(0, Tsat - T);
    st.phase = 'subcooled liquid';
elseif h >= hg                                        % superheated vapour
    row = vrow_(t, P);
    T = interp1(row.h(row.v), t.Tg(row.v), h, 'linear', 'extrap');
    st.T = T;
    st.s = interp1(t.Tg(row.v), row.s(row.v), T, 'linear', 'extrap');
    rr = row.rho; st.rho = interp1(t.Tg(row.v), rr(row.v), T, 'linear', 'extrap');
    st.superheat = max(0, T - Tsat);
    st.phase = 'superheated vapour';
else                                                  % two-phase mixture
    x = (h - hf)/(hg - hf);
    rf = iu_(t.rhof, Tsat);
    rg = iu_(t.rhog, Tsat);
    sf = iu_(t.sf, Tsat);
    sg = iu_(t.sg, Tsat);
    st.T = Tsat; st.x = x;
    st.s = sf + x*(sg - sf);
    st.rho = 1/(x/rg + (1 - x)/rf);
    st.phase = sprintf('two-phase (x = %.2f)', x);
end
st.vdot = mdot/st.rho;
end

function h2s = h_isen_(t, Pc, s1)
Tsat = tsat_(t, Pc);
sg = iu_(t.sg, Tsat);
if s1 <= sg                                           % ends inside the dome
    sf = iu_(t.sf, Tsat);
    hf = iu_(t.hf, Tsat);
    hg = iu_(t.hg, Tsat);
    x = max(0, (s1 - sf)/(sg - sf));
    h2s = hf + x*(hg - hf);
else
    row = vrow_(t, Pc);
    T2s = interp1(row.s(row.v), t.Tg(row.v), s1, 'linear', 'extrap');
    h2s = interp1(t.Tg(row.v), row.h(row.v), T2s, 'linear', 'extrap');
end
end

function y = iu_(tab, T)
% linear interpolation / extrapolation on the uniform saturation grid T = -30:0.5:95 degC
i = (T + 30)/0.5 + 1;
k = min(max(floor(i), 1), numel(tab) - 1);
y = tab(k) + (i - k)*(tab(k+1) - tab(k));
end

function T = tsat_(t, P)
i = (P - t.Pg(1))/10e3 + 1;
k = min(max(floor(i), 1), numel(t.Pg) - 1);
T = t.TsatP(k) + (i - k)*(t.TsatP(k+1) - t.TsatP(k));
end
