# Shutdown Task Script

This script processes instruction files in a specified directory and executes shutdown tasks based on the file contents.

## Require environment

- windows11
- [uv](https://docs.astral.sh/uv/getting-started/installation/#winget)

note: The requirement for `uv` is because the script uses the Python package manager `uv` to execute scripts based on the instruction files. Therefore, if you want to use shell scripts or other scripting languages for the tasks, `uv` is not required.

## How to Use

1. **Setup the Directory Structure**:
   - Place the script (`shutdown.ps1`) in the desired directory.
   - Ensure the following subdirectories exist:
     - `shutdown_tasks`: Directory where instruction files are stored.
     - `shutdown_tasks/archive`: Directory where processed files will be archived.

2. **Instruction File Format**:
   - File names must follow the format: `<priority>_<count>_<days>_<identifier>.txt`
     - `priority`: `h` for high priority, `n` for normal priority.
     - `count`: Number of times the task should run (`p` for infinite).
     - `days`: Days of the week the task should run (e.g., `123` for Monday, Tuesday, Wednesday).
     - `identifier`: A unique identifier for the task.
   - The first line of the file should contain the command to execute.

3. **Execution**:
   - Run the script using PowerShell:

     ```powershell
     .\shutdown.ps1
     ```

   - The script will:
     - Process high-priority files (`h_*`) first, followed by normal-priority files (`n_*`).
     - Execute the command in the first line of each file if the current day matches the specified days.
     - Update the `count` in the file name or move the file to the `archive` directory if `count` reaches zero.

4. **Logging**:
   - Logs are written to `shutdown_tasks/shutdown_task_log.txt`.
   - The log includes information about processed files, skipped files, and errors.

5. **Shutdown**:
   - After processing all files, the script initiates a system shutdown with a 10-second delay.
   - To disable the shutdown, comment out the following line in the script:

     ```powershell
     #shutdown.exe /s /t 10
     ```

## Notes

- Ensure the script has the necessary permissions to read, write, and execute files in the `shutdown_tasks` directory.
- Test the script in a safe environment before deploying it in production.

---
