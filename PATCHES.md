# ryzen_monitor Patches

The `ryzen_monitor` tool installed by this project includes two key modifications from the original [AzagraMac/ryzen_monitor](https://github.com/AzagraMac/ryzen_monitor) repository. These patches are applied automatically by the `install.sh` script or were applied manually in the provided source.

## 1. Driver Version Compatibility

**Issue:** The original library only supported `ryzen_smu` driver versions `0.1.0` through `0.1.2`. The current driver version is `0.1.5`, which caused the tool to fail with an incompatibility error.

**Fix:** Updated `src/lib/libsmu.h` to include newer versions in the supported list.

```c
/* Version the loaded driver must use to be compatible. */
#define KERNEL_DRIVER_SUPP_VERS_COUNT 6   // Changed from 3
static char kernel_driver_supported_versions[KERNEL_DRIVER_SUPP_VERS_COUNT][10] = {
    "0.1.0",
    "0.1.1",
    "0.1.2",
    "0.1.3", // Added
    "0.1.4", // Added
    "0.1.5"  // Added
};
```

## 2. Single-Shot Mode (`-1`)

**Issue:** The tool was designed as an interactive monitoring application (`top`-like) with an infinite loop, making it unsuitable for logging or scripting usage (e.g., cron jobs).

**Fix:** Added a new flag `-1` (or usually integrated into option parsing) to `src/ryzen_monitor.c` to perform a single read and exit.

**Changes in `src/ryzen_monitor.c`:**
1.  Added `static int run_once = 0;`
2.  Added argument parsing for `-1` in `main()`:
    ```c
    case '1':
        run_once = 1;
        break;
    ```
3.  Modified the main loop in `start_pm_monitor()`:
    ```c
    if (!run_once) {
        fprintf(stdout, "\e[1;1H\e[2J"); // Clear screen only if interactive
    }
    // ... draw_screen ...
    if (!run_once) {
        fprintf(stdout, "\e[?25l"); // Hide cursor only if interactive
    }
    fflush(stdout);

    if (run_once) {
        break; // Exit loop
    }
    ```
