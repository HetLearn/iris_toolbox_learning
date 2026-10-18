function h = md5(data)
%MD5  Lower-case hex MD5 digest of a char row or a byte vector.
%
%   h = hetlearn.util.md5(data)
%
%   Inputs
%     data  char (hashed as UTF-8) or numeric/uint8 byte vector
%
%   Output
%     h     32-character lower-case hex string

if ischar(data) || isstring(data)
    data = unicode2native(char(data), 'UTF-8');
end
md = java.security.MessageDigest.getInstance('MD5');
if ~isempty(data)
    md.update(typecast(uint8(data(:)), 'int8'));
end
d = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(d, 2)', 1, []));
end
