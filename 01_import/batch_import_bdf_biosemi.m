% =========================================================================
% batch_import_bdf_biosemi.m
%
% PURPOSE:
%   Batch-import BioSemi .bdf resting-state files, apply channel
%   coordinates, keep only the 128 scalp EEG channels + 8 external (EXT)
%   channels, discard everything else (Status channel, etc.), resample to
%   512 Hz, and save as EEGLAB .set files with the SAME base filename to a
%   separate output folder.  NO re-referencing is applied.
%
% BioSemi 128-channel cap layout (Active Two system):
%   Channels  1 – 128  : scalp EEG  (A1–A32, B1–B32, C1–C32, D1–D32)
%   Channels 129 – 136 : external electrodes  (EXG1 – EXG8)
%   Channel  137+      : Status / trigger channel  --> discarded here
%
% INPUTS:
%   BDF source folder : E:\Resultados\TESIS MNC\1.EEG RS\
%   Channel coord file: E:\Resultados\TESIS MNC\TBR-JNeurosci\128BIOSEMI_EXG.xyz
%
% OUTPUT:
%   EEGLAB .set + .fdt files saved to: E:\Resultados\TESIS MNC\RS\
%   (same base filename as the original .bdf)
%
% REQUIREMENTS:
%   EEGLAB >= 2021 must be on the MATLAB path (or initialised before use).
%   BioSig plugin for EEGLAB is needed to read .bdf files.
%   --> In EEGLAB: File > Manage EEGLAB extensions > search "BioSig"
%
% USAGE:
%   1. Make sure EEGLAB is initialised:  eeglab; close;
%   2. Run this script.
% =========================================================================

clear; clc;

% -------------------------------------------------------------------------
% 1.  CONFIGURATION  –  edit these paths if your setup differs
% -------------------------------------------------------------------------

% Folder containing the raw .bdf files
bdf_folder   = 'E:\Resultados\TESIS MNC\1.EEG RS\';

% Destination folder for the processed .set files
out_folder   = 'E:\Resultados\TESIS MNC\RS\';

% Channel coordinate file (.xyz format, 128 EEG + 8 EXT)
coord_file   = 'E:\Resultados\TESIS MNC\TBR-JNeurosci\128BIOSEMI_EXG.xyz';

% Target sampling rate after resampling
target_srate = 512;   % Hz

% Number of scalp EEG channels in the BioSemi cap
n_eeg = 128;

% Number of external (EXG) channels to keep
n_ext = 8;

% Total channels to keep  (scalp + external)
n_keep = n_eeg + n_ext;   % = 136

% -------------------------------------------------------------------------
% 2.  VERIFY EEGLAB AND BIOSIG ARE AVAILABLE
% -------------------------------------------------------------------------
if ~exist('pop_loadset', 'file')
    error(['EEGLAB is not on the MATLAB path.\n' ...
           'Please run   eeglab;   first, then re-run this script.']);
end

if ~exist('pop_biosig', 'file')
    error(['pop_biosig (BioSig plugin) not found.\n' ...
           'Install it via EEGLAB > File > Manage EEGLAB extensions.']);
end

% -------------------------------------------------------------------------
% 3.  VERIFY PATHS EXIST
% -------------------------------------------------------------------------
if ~isfolder(bdf_folder)
    error('BDF source folder not found:\n  %s', bdf_folder);
end

if ~isfolder(out_folder)
    fprintf('Output folder does not exist. Creating it...\n');
    mkdir(out_folder);
end

if ~isfile(coord_file)
    error('Channel coordinate file not found:\n  %s', coord_file);
end

% -------------------------------------------------------------------------
% 4.  COLLECT ALL .bdf FILES
% -------------------------------------------------------------------------
bdf_list = dir(fullfile(bdf_folder, '*.bdf'));
bdf_list = natural_sort_files(bdf_list);       % <-- natural order

if isempty(bdf_list)
    error('No .bdf files found in:\n  %s', bdf_folder);
end

fprintf('Found %d .bdf file(s) to process.\n\n', numel(bdf_list));

% =========================================================================
% 5.  MAIN BATCH LOOP
% =========================================================================
for iFile = 1 : numel(bdf_list)

    bdf_name = bdf_list(iFile).name;
    [~, subj_name, ~] = fileparts(bdf_name);

    fprintf('--- [%d/%d]  %s ---\n', iFile, numel(bdf_list), bdf_name);

    % -----------------------------------------------------------------------
    % 5a.  IMPORT BDF FILE
    %   pop_biosig reads BioSemi .bdf using the BioSig library.
    %   'channels' selects channels 1:136 (128 EEG + 8 EXT).
    %   The Status channel (usually the last channel) is excluded by
    %   specifying the range explicitly, which avoids the non-EEG marker
    %   channel entering the dataset.
    % -----------------------------------------------------------------------
    fprintf('  Importing BDF...\n');

    EEG = pop_biosig(fullfile(bdf_folder, bdf_name), ...
                     'channels', 1 : n_keep);   % import only 1-136
    %   If pop_biosig does not accept 'channels' as a key, fall back to:
    %       EEG = pop_biosig(fullfile(bdf_folder, bdf_name));
    %   and the channel-selection step below (5c) will still trim correctly.

    % Store the original file reference in EEG.comments for traceability
    EEG.comments = sprintf('Imported from: %s', fullfile(bdf_folder, bdf_name));

    % -----------------------------------------------------------------------
    % 5b.  LOAD CHANNEL COORDINATES
    %   The .xyz file contains 136 rows (128 EEG + 8 EXT).
    %   pop_chanedit with 'load' replaces any default labels with the
    %   coordinates from the file.
    % -----------------------------------------------------------------------
    fprintf('  Loading channel coordinates...\n');

    EEG = pop_chanedit(EEG, 'load', {coord_file, 'filetype', 'xyz'});

    % -----------------------------------------------------------------------
    % 5c.  RENAME CHANNEL TYPES  (EEG channels and EXT channels)
    %   EEGLAB assigns all channels a generic type after import.
    %   We explicitly label channels 1-128 as 'EEG' and 129-136 as 'EXT'.
    %   This labelling is used by pop_select and many EEGLAB plugins.
    % -----------------------------------------------------------------------
    fprintf('  Setting channel types (EEG / EXT)...\n');

    for iCh = 1 : EEG.nbchan
        if iCh <= n_eeg
            EEG.chanlocs(iCh).type = 'EEG';
        elseif iCh <= n_keep
            EEG.chanlocs(iCh).type = 'EXT';
        else
            % Safety: should not exist after import with channel range
            EEG.chanlocs(iCh).type = 'OTHER';
        end
    end

    % -----------------------------------------------------------------------
    % 5d.  REMOVE ANY CHANNELS BEYOND INDEX n_keep  (defensive step)
    %   If pop_biosig ignored the 'channels' argument and loaded everything,
    %   this ensures we still end up with exactly 136 channels.
    % -----------------------------------------------------------------------
    if EEG.nbchan > n_keep
        fprintf('  Removing %d extra channel(s) (Status, misc)...\n', ...
                EEG.nbchan - n_keep);
        EEG = pop_select(EEG, 'channel', 1 : n_keep);
    end

    % Sanity check
    if EEG.nbchan ~= n_keep
        warning('  Expected %d channels but have %d after trimming. Check file.', ...
                n_keep, EEG.nbchan);
    end

    % -----------------------------------------------------------------------
    % 5e.  NO RE-REFERENCING
    %   Data is kept in its original reference (CMS/DRL for BioSemi).
    %   A comment is added for documentation purposes.
    % -----------------------------------------------------------------------
    EEG.ref = 'none (original BioSemi CMS/DRL)';

    % -----------------------------------------------------------------------
    % 5f.  RESAMPLE TO 512 Hz
    %   pop_resample uses an anti-aliasing FIR filter before downsampling.
    %   This reduces file size considerably for resting-state analyses.
    % -----------------------------------------------------------------------
    if EEG.srate ~= target_srate
        fprintf('  Resampling %d Hz --> %d Hz...\n', EEG.srate, target_srate);
        EEG = pop_resample(EEG, target_srate);
    else
        fprintf('  Sampling rate already %d Hz, no resampling needed.\n', ...
                target_srate);
    end

    % -----------------------------------------------------------------------
    % 5g.  FINAL EEGLAB CONSISTENCY CHECK
    % -----------------------------------------------------------------------
    EEG = eeg_checkset(EEG);

    % -----------------------------------------------------------------------
    % 5h.  SAVE AS .set  (same base filename, different folder)
    %   'savemode', 'onefile' writes both .set header and .fdt data matrix
    %   into the output folder.
    % -----------------------------------------------------------------------
    out_setname  = [subj_name '.set'];
    fprintf('  Saving  -->  %s\n', fullfile(out_folder, out_setname));

    EEG = pop_saveset(EEG, ...
                      'filename', out_setname, ...
                      'filepath', out_folder,  ...
                      'savemode', 'onefile');

    fprintf('  [OK] Done: %s  |  %d ch  |  %.1f s  |  %d Hz\n\n', ...
            out_setname, EEG.nbchan, EEG.pnts / EEG.srate, EEG.srate);

    % Clear to free RAM before next iteration
    clear EEG;

end % end of file loop

% =========================================================================
% 6.  DONE
% =========================================================================
fprintf('=================================================\n');
fprintf('Batch complete.  %d file(s) saved to:\n  %s\n', ...
        numel(bdf_list), out_folder);
fprintf('=================================================\n');
