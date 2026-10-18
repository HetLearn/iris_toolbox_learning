r"""
Rebuild Dynare IRFs from a saved Dynare first-order solution (oo_.dr)

Fallback for when MATLAB cannot run run_dynare_irfs.m. Reads a .mat file saved
by Dynare 4.6 (M_ and oo_), takes Dynare's own decision rule

    y(t) - ys = ghx * (y(t-1) - ys)[states] + ghu * u(t)

and iterates it for 40 periods after a 1-std shock, exactly as Dynare's
irf.m does at order 1. Writes the same CSV layout as run_dynare_irfs.m.

Copied from ucur-dsge/sw07-irispie/validation/dynare_irfs/ and adapted for
models/sw07/validation: 40 periods, output into this folder, and an optional
check that M_.params and the shock stds equal a Dynare mode file (to 1e-12)
before anything is written.

Usage:
    python export_dynare_dr_irfs.py <dynare .mat file> <tag> [<mode .mat file>]

Run for this package:
    python export_dynare_dr_irfs.py C:/dynare_work/sw_ext/swX1_out.mat swX1 ../estimation/swX1_mode.mat
"""


import sys
import os
import numpy as np
import scipy.io as sio


mat_file, tag = sys.argv[1], sys.argv[2]
out_dir = os.path.dirname(os.path.abspath(__file__))
num_periods = 40

r = sio.loadmat(mat_file, struct_as_record=False, squeeze_me=True, )
M, dr = r["M_"], r["oo_"].dr

endo_names = [str(n).strip() for n in M.endo_names]
exo_names = [str(n).strip() for n in M.exo_names]
param_names = [str(n).strip() for n in M.param_names]
order_var = np.atleast_1d(dr.order_var).astype(int) - 1
state_var = np.atleast_1d(dr.state_var).astype(int) - 1
ghx, ghu = np.atleast_2d(dr.ghx), np.atleast_2d(dr.ghu)

# Shock impact matrix as in Dynare's irf.m: Cholesky factor of Sigma_e
# Optional: verify that the saved model is at the mode before exporting
if len(sys.argv) > 3:
    mode = sio.loadmat(sys.argv[3], squeeze_me=True)
    mode_names = [str(n).strip() for n in np.atleast_1d(mode["parameter_names"])]
    mode_vals = np.atleast_1d(mode["xparam1"]).astype(float)
    pdict = dict(zip(param_names, np.atleast_1d(M.params)))
    sdict = dict(zip(exo_names, np.sqrt(np.diag(np.atleast_2d(M.Sigma_e)))))
    diffs = [abs((sdict[n] if n in sdict else pdict[n]) - v) for n, v in zip(mode_names, mode_vals)]
    print(f"Mode check: {len(diffs)} estimated values, max abs diff vs {os.path.basename(sys.argv[3])} = {max(diffs):.3g}")
    if max(diffs) > 1e-12:
        sys.exit("M_ is not at the mode; recompute the decision rule at the mode first")

chol_sigma = np.linalg.cholesky(np.atleast_2d(M.Sigma_e) + 1e-14 * np.eye(len(exo_names)))

rows = []
for j, shock in enumerate(exo_names):
    x = np.zeros(len(endo_names))          # deviations, declaration order
    for t in range(num_periods):
        u = chol_sigma[:, j] if t == 0 else np.zeros(len(exo_names))
        x_new = np.zeros(len(endo_names))
        x_new[order_var] = ghx @ x[state_var] + ghu @ u
        x = x_new
        for i, name in enumerate(endo_names):
            rows.append(f"{name}_{shock},{t+1},{x[i]:.17g}")

with open(os.path.join(out_dir, f"dynare_irfs_{tag}.csv"), "w") as f:
    f.write("name,period,value\n" + "\n".join(rows) + "\n")

with open(os.path.join(out_dir, f"dynare_params_{tag}.csv"), "w") as f:
    f.write("name,value\n")
    for n, v in zip(param_names, np.atleast_1d(M.params)):
        f.write(f"{n},{v:.17g}\n")
    for n, v in zip(exo_names, np.sqrt(np.diag(np.atleast_2d(M.Sigma_e)))):
        f.write(f"std_{n},{v:.17g}\n")

print(f"Wrote dynare_irfs_{tag}.csv and dynare_params_{tag}.csv")
