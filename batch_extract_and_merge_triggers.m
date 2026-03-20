% =========================================================================
% batch_extract_and_merge_triggers.m
%
% PURPOSE:
%   1. Reads EEG files (.set) from the TRIGGERS folder (which contain the
%      clean event/trigger information).
%   2. Saves trigger data as a .mat file (one per subject) so MATLAB can
%      load them later in batch.
%   3. Loads the matching EEG file from the RS folder (resting-state, no
%      events) and "pastes" the triggers onto it, then saves the updated
%      file back to the RS folder.
%   4. Writes a human-readable .txt report per subject with: subject name,
%      trigger sequence, inter-trigger intervals, time from recording start
%      to the first trigger, and total recording duration.
%
% REQUIREMENTS:
%   - EEGLAB must be on the MATLAB path (or launched before running this
%     script). Tested with EEGLAB 2023.x.
%   - Both folders must contain .set files with matching base names.
%
% FOLDER STRUCTURE expected:
%   TRIGGERS folder : E:\Resultados\TESIS MNC\1.EEG_RS_clean\TRIGGERS\
%                     (contains .set files WITH trigger/event info)
%   RS folder       : E:\Resultados\TESIS MNC\RS\
%                     (contains .set files WITHOUT trigger/event info,
%                      same base filenames as in the TRIGGERS folder)
%
% OUTPUT (written inside the RS folder):
%   <subjectName>_triggers.mat   --> triggers struct, ready for MATLAB batch
%   <subjectName>_triggers.txt   --> human-readable trigger-only table
%   <subjectName>_report.txt     --> full report (intervals, total time…)
%   <subjectName>_withEvents.set --> RS file updated with the merged events
%   <subjectName>_withEvents.fdt --> associated data file (created by EEGLAB)
%
% USAGE:
%   Simply run this script inside MATLAB after making sure EEGLAB is
%   already initialised (run eeglab; close; first if needed).
% =========================================================================

clear; clc;

% -------------------------------------------------------------------------
% 1.  CONFIGURE PATHS  (edit these two lines to match your setup)
% -------------------------------------------------------------------------
triggers_folder = 'E:\Resultados\TESIS MNC\1.EEG_RS_clean\TRIGGERS\';
rs_folder       = 'E:\Resultados\TESIS MNC\RS\';

% Output folder: results will be saved inside the RS folder for tidiness.
output_folder   = rs_folder;   % change if you prefer a separate folder

% -------------------------------------------------------------------------
% 2.  MAKE SURE EEGLAB FUNCTIONS ARE AVAILABLE
% -------------------------------------------------------------------------
% Try to call a basic EEGLAB function; if it fails, ask the user to init.
if ~exist('pop_loadset', 'file')
    error(['EEGLAB functions not found on MATLAB path.\n' ...
           'Please run  eeglab;  in the command window first, ' ...
           'then re-run this script.']);
end

% -------------------------------------------------------------------------
% 3.  COLLECT ALL .set FILES IN THE TRIGGERS FOLDER
% -------------------------------------------------------------------------
trigger_files = dir(fullfile(triggers_folder, '*.set'));
trigger_files = natural_sort_files(trigger_files); % <-- natural order

if isempty(trigger_files)
    error('No .set files found in: %s', triggers_folder);
end

fprintf('Found %d .set file(s) in TRIGGERS folder.\n\n', numel(trigger_files));

% -------------------------------------------------------------------------
% 4.  LOOP OVER EACH SUBJECT FILE
% -------------------------------------------------------------------------
for iFile = 1 : numel(trigger_files)

    % --- 4a. Derive subject name from filename ----------------------------
    [~, subj_name, ~] = fileparts(trigger_files(iFile).name);
    fprintf('=== Processing subject: %s (%d/%d) ===\n', ...
            subj_name, iFile, numel(trigger_files));

    % --- 4b. Load the TRIGGER file with EEGLAB ---------------------------
    EEG_trig = pop_loadset('filename', trigger_files(iFile).name, ...
                            'filepath', triggers_folder);

    % Verify that the TRIGGERS file actually has events
    if isempty(EEG_trig.event)
        warning('File %s has NO events. Skipping.\n', trigger_files(iFile).name);
        continue
    end

    % =====================================================================
    % 5.  EXTRACT TRIGGER INFORMATION
    % =====================================================================

    % Number of events in this recording
    n_events = numel(EEG_trig.event);

    % Pre-allocate arrays for clarity
    ev_type   = cell(n_events, 1);   % trigger label  (string or number)
    ev_latency_samp = zeros(n_events, 1); % latency in samples
    ev_latency_sec  = zeros(n_events, 1); % latency converted to seconds

    for iEv = 1 : n_events
        % EEGLAB stores event type as either string or number
        raw_type = EEG_trig.event(iEv).type;
        if isnumeric(raw_type)
            ev_type{iEv} = num2str(raw_type);
        else
            ev_type{iEv} = char(raw_type);
        end

        % Latency is stored in SAMPLES; convert to seconds using srate
        ev_latency_samp(iEv) = EEG_trig.event(iEv).latency;
        ev_latency_sec(iEv)  = (EEG_trig.event(iEv).latency - 1) / EEG_trig.srate;
        %   Note: EEGLAB latency is 1-based, so we subtract 1 before dividing
    end

    % Total recording duration in seconds
    total_duration_sec = EEG_trig.pnts / EEG_trig.srate;

    % Time from recording START (t = 0) to the FIRST trigger
    t_start_to_first = ev_latency_sec(1);

    % Inter-trigger intervals: diff between consecutive events
    % iti(k) = time from event k to event k+1
    iti = diff(ev_latency_sec);   % length = n_events - 1

    % =====================================================================
    % 6.  SAVE TRIGGERS AS .mat  (the "glue" file for batch processing)
    % =====================================================================
    % We store a struct that mirrors EEGLAB's EEG.event structure so it
    % can be directly assigned later.

    triggers_struct.event            = EEG_trig.event;   % full EEGLAB event array
    triggers_struct.srate            = EEG_trig.srate;
    triggers_struct.type_labels      = ev_type;
    triggers_struct.latency_samples  = ev_latency_samp;
    triggers_struct.latency_seconds  = ev_latency_sec;
    triggers_struct.iti_seconds      = iti;
    triggers_struct.total_dur_sec    = total_duration_sec;
    triggers_struct.subject          = subj_name;
    triggers_struct.source_file      = trigger_files(iFile).name;

    mat_filename = fullfile(output_folder, [subj_name '_triggers.mat']);
    save(mat_filename, 'triggers_struct');
    fprintf('  [OK] Trigger .mat saved  ->  %s\n', mat_filename);

    % =====================================================================
    % 7.  SAVE A PLAIN-TEXT TRIGGER TABLE  (pure trigger info, human-readable)
    % =====================================================================
    txt_trig_file = fullfile(output_folder, [subj_name '_triggers.txt']);
    fid_trig = fopen(txt_trig_file, 'w');

    fprintf(fid_trig, 'TRIGGER TABLE\n');
    fprintf(fid_trig, 'Subject  : %s\n', subj_name);
    fprintf(fid_trig, 'Source   : %s\n', trigger_files(iFile).name);
    fprintf(fid_trig, 'Samp.rate: %d Hz\n', EEG_trig.srate);
    fprintf(fid_trig, 'N events : %d\n\n', n_events);
    fprintf(fid_trig, '%-6s  %-20s  %-16s  %-16s\n', ...
            'Index', 'Type', 'Latency(samples)', 'Latency(sec)');
    fprintf(fid_trig, '%s\n', repmat('-', 1, 64));

    for iEv = 1 : n_events
        fprintf(fid_trig, '%-6d  %-20s  %-16d  %-16.4f\n', ...
                iEv, ev_type{iEv}, ev_latency_samp(iEv), ev_latency_sec(iEv));
    end

    fclose(fid_trig);
    fprintf('  [OK] Trigger .txt saved  ->  %s\n', txt_trig_file);

    % =====================================================================
    % 8.  WRITE FULL REPORT .txt
    % =====================================================================
    report_file = fullfile(output_folder, [subj_name '_report.txt']);
    fid_rep = fopen(report_file, 'w');

    fprintf(fid_rep, '============================================================\n');
    fprintf(fid_rep, '  EEG TRIGGER REPORT\n');
    fprintf(fid_rep, '============================================================\n');
    fprintf(fid_rep, 'Subject name       : %s\n', subj_name);
    fprintf(fid_rep, 'Source (TRIGGER)   : %s\n', trigger_files(iFile).name);
    fprintf(fid_rep, 'Sampling rate      : %d Hz\n', EEG_trig.srate);
    fprintf(fid_rep, 'Total rec. duration: %.4f s  (%.2f min)\n', ...
            total_duration_sec, total_duration_sec / 60);
    fprintf(fid_rep, 'Number of triggers : %d\n\n', n_events);

    % -- Trigger sequence (all labels in order) ---------------------------
    fprintf(fid_rep, 'TRIGGER SEQUENCE:\n');
    fprintf(fid_rep, '  ');
    for iEv = 1 : n_events
        if iEv < n_events
            fprintf(fid_rep, '%s -> ', ev_type{iEv});
        else
            fprintf(fid_rep, '%s\n', ev_type{iEv});
        end
    end
    fprintf(fid_rep, '\n');

    % -- Timing details ---------------------------------------------------
    fprintf(fid_rep, 'TIMING DETAILS:\n');
    fprintf(fid_rep, '  Recording start  -->  Trigger #1 (%s) : %.4f s\n', ...
            ev_type{1}, t_start_to_first);

    for iEv = 1 : n_events - 1
        fprintf(fid_rep, '  Trigger #%d (%s)  -->  Trigger #%d (%s) : %.4f s\n', ...
                iEv,   ev_type{iEv}, ...
                iEv+1, ev_type{iEv+1}, ...
                iti(iEv));
    end

    % Time from last trigger to end of recording
    t_last_to_end = total_duration_sec - ev_latency_sec(end);
    fprintf(fid_rep, '  Trigger #%d (%s)  -->  Recording end       : %.4f s\n\n', ...
            n_events, ev_type{end}, t_last_to_end);

    % -- EEG file with event info (will be written after merging) ---------
    merged_set_name = [subj_name '_withEvents.set'];
    fprintf(fid_rep, 'EEG FILE WITH MERGED EVENTS:\n');
    fprintf(fid_rep, '  %s\n', fullfile(output_folder, merged_set_name));
    fprintf(fid_rep, '  (see trigger table for per-event latencies)\n\n');
    fprintf(fid_rep, '============================================================\n');

    fclose(fid_rep);
    fprintf('  [OK] Report .txt saved   ->  %s\n', report_file);

    % =====================================================================
    % 9.  MERGE TRIGGERS INTO THE MATCHING RS FILE
    % =====================================================================

    % Build the expected RS filename (same base name, different folder)
    rs_set_file = fullfile(rs_folder, [subj_name '.set']);

    if ~isfile(rs_set_file)
        warning(['RS file not found for subject %s.\n' ...
                 '  Expected: %s\n  Skipping merge step.\n'], ...
                 subj_name, rs_set_file);
        continue
    end

    % Load the RS (resting-state) file
    EEG_rs = pop_loadset('filename', [subj_name '.set'], ...
                          'filepath', rs_folder);

    % --- Sanity check: durations should match (within 1 sample tolerance) -
    dur_rs   = EEG_rs.pnts   / EEG_rs.srate;
    dur_trig = EEG_trig.pnts / EEG_trig.srate;
    if abs(dur_rs - dur_trig) > (1 / EEG_rs.srate)
        warning(['Duration mismatch for subject %s:\n' ...
                 '  RS file   : %.4f s\n' ...
                 '  TRIG file : %.4f s\n' ...
                 '  Merging anyway, but please verify.\n'], ...
                 subj_name, dur_rs, dur_trig);
    end

    % Copy events from the TRIGGER file into the RS file
    EEG_rs.event    = EEG_trig.event;
    EEG_rs.urevent  = EEG_trig.urevent;   % keep the original unreferenced events

    % Let EEGLAB rebuild its internal epoch/event bookkeeping
    EEG_rs = eeg_checkset(EEG_rs);

    % Save the merged file with a new name to avoid overwriting the original
    EEG_rs = pop_saveset(EEG_rs, ...
                          'filename', merged_set_name, ...
                          'filepath', output_folder, ...
                          'savemode', 'onefile');   % saves .set + .fdt together

    fprintf('  [OK] Merged RS .set saved ->  %s\n\n', ...
            fullfile(output_folder, merged_set_name));

end % end of subject loop

fprintf('\n>>> Batch processing complete. All outputs are in:\n    %s\n', output_folder);
