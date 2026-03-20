# Project Instructions for Claude

## Overview

This repository contains MATLAB scripts for preprocessing and analyzing **resting-state EEG data** recorded with a BioSemi 128-channel Active Two system.
The main research goal is to compute the **Theta/Beta Ratio (TBR)** and examine its association with impulsivity scores measured with the **Barratt Impulsiveness Scale (BIS-11)**.

---

## Response Language and Format Rules

- **Always respond in English**, regardless of the language used in the question.
- **Code comments must always be written in English**, even if the surrounding conversation is in Spanish or Italian.
- **Do NOT write reports or summaries unless explicitly requested.** Default responses should be code only.
- When producing code: always provide the **complete script**, ready to copy and paste.
- Exception: if only one or two lines need to change in an existing script, indicate the exact location and show only that fragment.
- The code is intended to be **shared with peer reviewers**, so it must be clean, well-commented, and reproducible.
- When citing methods or processing steps, include **author, year, and DOI** of the original published source (WoS/Scopus indexed journals, no preprints). Verify that the DOI resolves to a real paper.

---

## Recording Equipment

| Parameter | Value |
|-----------|-------|
| System | BioSemi Active Two |
| Scalp EEG channels | 128 (labeled as type `EEG`) |
| External channels | 8 (labeled as type `EXT`) |
| Reference during recording | CMS/DRL (BioSemi default, no re-referencing applied yet) |
| File format | BDF (BioSemi Data Format) |
| Original sampling rate | 2048 Hz (resampled to 512 Hz during import) |

### External Channel Assignments

| Channel | Label | Signal |
|---------|-------|--------|
| EXT1 | HEOG_L | Horizontal EOG – left |
| EXT2 | HEOG_R | Horizontal EOG – right |
| EXT3 | VEOG_U | Vertical EOG – up |
| EXT4 | VEOG_D | Vertical EOG – down |
| EXT5 | MAST_L | Left mastoid |
| EXT6 | MAST_R | Right mastoid |
| EXT7 | CARD_L | Cardiac – left |
| EXT8 | CARD_R | Cardiac – right |

### Channel coordinate file

```
E:\Resultados\TESIS MNC\TBR-JNeurosci\128BIOSEMI_EXG.xyz
```

Contains 136 rows: 128 scalp EEG + 8 EXT.

---

## Resting-State Paradigm

### Conditions

| Trigger code | Condition |
|-------------|-----------|
| `11` | Eyes Open (EO) |
| `12` | Eyes Closed (EC) |

### Structure

The recording consists of **8 epochs of 1 minute each**, alternating between EO and EC conditions.
There were **two counterbalanced sequences** across participants:

- **Condition 1:** EO – EC – EC – EO – EC – EO – EO – EC
- **Condition 2:** EC – EO – EO – EC – EO – EC – EC – EO

### Critical trigger logic

> ⚠️ **Non-standard trigger timing:** Each trigger marks the **end** of the preceding condition, not the onset of the next one.

The trigger was sent at the moment an audio instruction started playing (e.g., *"now close your eyes"*). Because participants needed a brief moment to hear and comply, the trigger marks the **transition point**, and the clean EEG epoch for any given condition is located **before** the trigger.

**Recommended epoching strategy:** epoch backwards from each trigger, e.g., `[-58.9, 0.1]` seconds relative to trigger onset, so that roughly 1 minute of clean data is captured before the instruction moment, with a small buffer after.

### Truncated recordings (known data issue)

Some participants' recordings were **cut at the beginning**: the first trigger that appears is the audio instruction trigger, meaning the very first condition has no onset marker. Because epoching goes backwards from the trigger, the first epoch can still be recovered from these truncated files — the data before the first visible trigger represents the first condition.

---

## Folder Structure

```
E:\Resultados\TESIS MNC\
│
├── 1.EEG RS\                   ← raw .bdf files (source)
│
├── 1.EEG_RS_clean\
│   └── TRIGGERS\               ← .set files containing corrected event/trigger info
│
└── RS\                         ← processed .set files (output after import pipeline)
```

---

## Existing Scripts in This Repository

The following scripts have already been created and are available in the repo.
**Do not recreate them from scratch** — build on them or reference them when relevant.

| Script | Purpose |
|--------|---------|
| `batch_import_bdf_biosemi.m` | Imports raw `.bdf` files, loads channel coordinates, keeps 128 EEG + 8 EXT channels, resamples to 512 Hz, saves `.set` to the `RS\` folder |
| `batch_extract_and_merge_triggers.m` | Reads corrected trigger info from `TRIGGERS\` folder, saves per-subject `.mat` and `.txt` trigger files, merges events into matching RS `.set` files, writes a timing report `.txt` |
| `natural_sort_files.m` | Utility function — sorts `dir()` output in natural numeric order (S1, S2, … S10, not S1, S10, S2). **Must be on the MATLAB path.** Always use this after any `dir()` call that lists subject files. |

### How to use `natural_sort_files`

Add one line after every `dir()` call that collects subject files:

```matlab
files = dir(fullfile(folder, '*.set'));
files = natural_sort_files(files);   % always sort before looping
```

---

## Preprocessing Standards

When writing preprocessing, epoching, ICA, or spectral analysis code, follow established standards for **resting-state EEG in cognitive neuroscience / psychophysiology**. All methodological choices must be justified with peer-reviewed citations (WoS/Scopus). Include at minimum:

- Bandpass filtering strategy and filter type
- Epoch length and overlap decisions
- Artifact rejection criteria (amplitude, gradient)
- ICA algorithm and rationale for component rejection
- Re-referencing strategy (when applied)
- Spectral estimation method (Welch, multitaper, etc.) and parameters
- Frequency band definitions (theta: 4–8 Hz; beta: 13–30 Hz, or justify if different)
- Electrode selection for TBR: must account for the spatial correspondence between the 128-channel BioSemi layout and standard 10-20 / 10-10 positions reported in TBR literature


