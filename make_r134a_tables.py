"""Generates r134a_props.mat (R134a property tables) from CoolProp. Run once: python make_r134a_tables.py"""
import numpy as np
from CoolProp.CoolProp import PropsSI
from scipy.io import savemat
R = "R134a"; K = 273.15
Ts = np.arange(-30, 95.01, 0.5)
def sat(prop, q): return np.array([PropsSI(prop, "T", t + K, "Q", q, R) for t in Ts])
Psat = sat("P", 0); hf = sat("H", 0); hg = sat("H", 1); sf = sat("S", 0); sg = sat("S", 1)
rhof = sat("D", 0); rhog = sat("D", 1)
dhdp = np.array([(PropsSI("H", "T", t + K, "P", p + 1.0e6, R) - h) / 1.0e6 for t, p, h in zip(Ts, Psat, hf)])
Pg = np.arange(100e3, 3000e3 + 1, 10e3); Tg = np.arange(-30, 150.01, 1.0)
H = np.full((len(Pg), len(Tg)), np.nan); S = H.copy(); RHO = H.copy()
for i, p in enumerate(Pg):
    tsat = PropsSI("T", "P", p, "Q", 1, R) - K
    for j, t in enumerate(Tg):
        if t > tsat + 0.05:
            H[i, j] = PropsSI("H", "T", t + K, "P", p, R)
            S[i, j] = PropsSI("S", "T", t + K, "P", p, R)
            RHO[i, j] = PropsSI("D", "T", t + K, "P", p, R)
savemat("r134a_props.mat", dict(Ts=Ts, Psat=Psat, hf=hf, hg=hg, sf=sf, sg=sg, rhof=rhof, rhog=rhog,
                                dhdp=dhdp, Pg=Pg, Tg=Tg, H=H, S=S, RHO=RHO), format="5")
print("ok", H.shape)
