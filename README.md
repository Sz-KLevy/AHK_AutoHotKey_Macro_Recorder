# AHK AutoHotkey Macro Recorder

A professional-grade, GUI-based automation tool developed in **AutoHotkey (AHK) v2**. This application is designed to record, persist, and replay complex sequences of keyboard and mouse interactions with high-fidelity timing and precision.

## 🚀 Features

*   **High-Fidelity Recording:** Utilizes AHK's `InputHook` for low-level keyboard monitoring and high-frequency polling for mouse coordinate tracking.
*   ** precise Playback Engine:** Reconstructs user events chronologically by merging separate input streams (Mouse & Keyboard), ensuring accurate execution of macros relative to the original recording timestamps.
*   **GUI Control Panel:** A user-friendly graphical interface for managing recording sessions, playback, and file operations.
*   **Persistence Layer:** Custom serialization implementation allows for Saving and Loading macro sequences to/from structured text files (`.txt`), enabling reusable automation scripts.
*   **Configurable Contexts:** Supports multiple coordinate modes (`Screen`, `Window`, `Client`) to adapt to different automation environments.
*   **DPI Awareness:** Includes `SetThreadDpiAwarenessContext` implementation to ensure accurate mouse positioning across high-resolution displays.

## 🛠️ Requirements

*   **Runtime Environment:** [AutoHotkey v2.0](https://www.autohotkey.com/v2/) or later.
*   **OS:** Windows 10/11 (due to AHK v2 dependencies).

## 📦 Installation & Setup

1.  **Download & Install:** Ensure AutoHotkey v2 is installed on your system.
2.  **Clone/Download:** Get this repository to your local machine.
3.  **Launch:** Double-click `src/MacroRecorder.ahk` to initialize the application.

## 🎮 Usage Guide

### Main Interface
The main dashboard provides immediate access to core functions:
*   **Start/Stop Recording:** Begins capturing input events.
*   **Play:** Executes the currently loaded macro sequence.
*   **Save/Load:** Serializes the current session to a file or deserializes an existing one.

### Default Hotkeys
Global hotkeys allow for control without focusing the application window:

| Action | Default Hotkey | Description |
| :--- | :--- | :--- |
| **Start Recording** | `F1` | Initializes the recording hooks and timers. |
| **Stop Recording** | `F1` | Terminates hooks and finalizes the input log. |
| **Play Macro** | `F2` | Starts the playback engine. |
| **Exit App** | `Alt + D` | Terminates the application instance. |
| **Reload App** | `Alt + U` | Hot-reloads the script (useful for development). |

### Configuration
Access the **Options** menu to customize:
*   **Hotkeys:** Remap control keys to avoid conflicts with other applications.
*   **Mouse Mode:**
    *   `Screen`: Coordinates are relative to the entire desktop.
    *   `Window`: Coordinates are relative to the active window.
    *   `Client`: Coordinates are relative to the active window's client area (excluding title bar/borders).

## 🔧 Technical Details

The application is structured into modular classes for maintainability:

*   **`AppGUI`**: Manages the event-driven UI, including Main, Options, and Credits views.
*   **`DataLog`**: Handles the storage of raw input events and implements the `MergeLogs()` algorithm to synchronize mouse and keyboard data streams for playback.
*   **`Setting`**: Manages application state and configuration persistence during runtime.
*   **`InputHook`**: Leveraging AHK's modern `InputHook` object for robust key interception compared to legacy `KeyWait` or `Input` commands.

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).