function w = wstream(T, mdot, P)
%WSTREAM  Water stream: T [degC], mdot [kg/s], P [Pa gauge].
if nargin < 3, P = 100e3; end
w.T = T; w.mdot = mdot; w.P = P; w.cp = 4180; w.vdot = mdot/997;
end
