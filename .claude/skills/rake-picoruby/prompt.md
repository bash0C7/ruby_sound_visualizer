# PicoRuby Rake Operations Subagent

You are delegated to run PicoRuby build/flash/monitor operations via rake.

## Task

Run the specified rake task in the `picoruby/` directory and extract key information from verbose output.

## Command Format

```bash
cd picoruby && APP=<app_name> rake <task_name>
```

## Tasks

- `build`: Compile .rb → .mrb, copy to components/, run idf.py build
- `flash`: Flash firmware to ATOM Matrix ESP32
- `monitor`: Monitor serial output from device
- `check_env`: Verify ESP-IDF environment
- `cleanbuild`: Full clean rebuild
- `buildall`: Setup + build

## Output Filtering

Run the full command but extract ONLY these key lines:

1. **Errors** (report all):
   - Lines containing `Error:`, `error:`, `FAILED`, `abort`
   - Full stack traces for compilation/build failures

2. **Warnings** (report all):
   - Lines containing `Warning:`, `warning:`, `CRITICAL`

3. **Build Progress** (report summary):
   - `Compiling: <file>` - report file names being compiled
   - `Created app.mrb from <app_name>.mrb` - report MRB creation
   - `Removed:` lines - suppress (noise)
   - `Copied src_components contents` - report once

4. **Flash Progress** (report summary):
   - `Wrote ... bytes`, `Hash of data verified` - report important flash steps
   - ESP-IDF idf.py flash output - extract key completion lines

5. **Final Status** (report always):
   - `completed successfully` or `Build completed successfully`
   - Any abort/error exit status

## Implementation

Use bash to run the command and pipe through grep or similar to extract key lines:

```bash
cd picoruby && APP=<app_name> rake <task_name> 2>&1 | grep -E '(Error:|error:|Warning:|warning:|Compiling:|Created app|Wrote|completed successfully|FAILED|abort)' | head -100
```

Adjust grep pattern as needed to balance verbosity vs. information.

## Report Format

After command completion, summarize:

```
=== Rake Task: <task_name> (APP=<app_name>) ===
[Key extracted lines]

Status: SUCCESS / FAILURE
[Brief explanation if failure]
```
