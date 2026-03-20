function sorted_list = natural_sort_files(file_list)
% NATURAL_SORT_FILES  Sort a struct array from dir() in natural order.
%
%   sorted_list = natural_sort_files(file_list)
%
%   INPUT:
%     file_list   : struct array returned by  dir('folder/*.ext')
%
%   OUTPUT:
%     sorted_list : same struct array reordered so that numeric parts
%                   inside filenames are compared as numbers, not strings.
%                   Example:
%                     Alphabetic : S1, S10, S11, S2, S20, S3
%                     Natural    : S1, S2, S3, S10, S11, S20
%
%   USAGE:
%     files = dir('E:\MyData\*.set');
%     files = natural_sort_files(files);
%     for i = 1:numel(files)
%         disp(files(i).name)
%     end

    % Extract filenames into a cell array
    names = {file_list.name};

    % Build a zero-padded version of each name for sorting
    padded = cellfun(@pad_numbers, names, 'UniformOutput', false);

    % Sort the padded names alphabetically --> yields natural numeric order
    [~, sort_idx] = sort(padded);

    % Reorder the original struct array
    sorted_list = file_list(sort_idx);

end


% -------------------------------------------------------------------------
% HELPER: replace every digit run with a 20-char zero-padded equivalent
% -------------------------------------------------------------------------
function s_out = pad_numbers(s_in)
% PAD_NUMBERS  Manually find all digit sequences and pad them with zeros.
%   'S10_rest' --> 'S00000000000000000010_rest'
%   'S2_rest'  --> 'S00000000000000000002_rest'
%
%   We avoid using a function handle inside regexprep (not supported in
%   all MATLAB versions). Instead we use regexp to find token positions
%   and rebuild the string piece by piece.

    % regexp returns start and end positions of each digit-run match
    [tok_start, tok_end] = regexp(s_in, '\d+', 'start', 'end');

    if isempty(tok_start)
        % No digits in the filename at all, return as-is
        s_out = s_in;
        return
    end

    % Walk through the original string, replacing digit runs with their
    % zero-padded equivalents (always 20 characters wide)
    s_out  = '';
    cursor = 1;   % current read position in s_in

    for k = 1 : numel(tok_start)

        % 1. Copy the non-digit characters before this token
        if cursor < tok_start(k)
            s_out = [s_out, s_in(cursor : tok_start(k) - 1)]; %#ok<AGROW>
        end

        % 2. Pad the digit substring to 20 characters
        digit_str  = s_in(tok_start(k) : tok_end(k));
        digit_val  = str2double(digit_str);
        padded_str = sprintf('%020.0f', digit_val);

        s_out  = [s_out, padded_str]; %#ok<AGROW>
        cursor = tok_end(k) + 1;

    end

    % 3. Copy any remaining non-digit tail
    if cursor <= numel(s_in)
        s_out = [s_out, s_in(cursor : end)];
    end

end
