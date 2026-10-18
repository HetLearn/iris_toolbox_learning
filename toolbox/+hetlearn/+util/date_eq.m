function tf = date_eq(a, b)
%DATE_EQ  Element-wise equality of IRIS dates (robust to Dater/double).
%
%   tf = hetlearn.util.date_eq(a, b)
%
%   a, b  IRIS dates (Dater or serial doubles); scalar expansion applies.

tf = abs(double(a) - double(b)) < 1e-6;
end
