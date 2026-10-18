function b = file_bytes(file)
%FILE_BYTES  Raw bytes of a file as a uint8 row vector.
%
%   b = hetlearn.util.file_bytes(file)
%
%   Errors (hetlearn:util:noFile) if the file cannot be opened.

fid = fopen(file, 'r');
if fid < 0
    error('hetlearn:util:noFile', 'Cannot open %s', file);
end
b = fread(fid, Inf, '*uint8')';
fclose(fid);
end
