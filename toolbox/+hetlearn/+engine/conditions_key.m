function key = conditions_key(reference)
%CONDITIONS_KEY  Field name used for a condition reference ('self' or a scenario id).
%
%   key = hetlearn.engine.conditions_key(reference)

if isempty(reference)
    reference = 'self';
end
key = matlab.lang.makeValidName(['ref_' char(reference)]);
end
