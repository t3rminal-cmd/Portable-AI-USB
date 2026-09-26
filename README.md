# Portable Private AI on a USB Drive (Windows)

Run a private AI chat assistant, including uncensored models, from a USB drive on any Windows PC. After setup, your chats never leave the drive and no internet connection is needed.

This is a Windows-only fork of [techjarves/Portable-AI-USB](https://github.com/techjarves/Portable-AI-USB), with the bugs from the original fixed (see [What changed](#what-changed-from-the-original)).

It uses two programs, both kept on the USB:

- **Ollama**: the engine that runs the AI model.
- **AnythingLLM**: the chat window you type into.

## What you need

- **Windows 10 (version 1803 or newer) or Windows 11.**
- **A USB drive of 32 GB or more**, USB 3.0 or faster. A small external SSD works even better. 16 GB is enough for one small model.
- **RAM for the model you pick:**

| # | Model | Download | RAM | Type |
|---|-------|----------|-----|------|
| 1 | NemoMix Unleashed 12B | ~7.0 GB | 16 GB | Uncensored, best quality (recommended) |
| 2 | Dolphin 2.9 Llama 3 8B | ~4.9 GB | 8 GB | Uncensored all-rounder |
| 3 | Mistral 7B Instruct v0.3 | ~4.1 GB | 8 GB | Standard, good at coding |
| 4 | Qwen 2.5 7B Instruct | ~4.7 GB | 8 GB | Standard, multilingual |
| 5 | Llama 3.2 3B Instruct | ~2.0 GB | 8 GB or less | Standard, fast on old PCs |
| 6 | Phi-3.5 Mini 3.8B | ~2.2 GB | 8 GB or less | Standard, good reasoning |
| C | Custom | varies | varies | Any GGUF file from Hugging Face |

## Setup (one time, needs internet)

1. **Format the USB as exFAT.** In File Explorer, right-click the drive, choose **Format**, set File system to **exFAT**, and click **Start**. This erases the drive. Do not use FAT32: it cannot hold files over 4 GB.
2. **Download this repo.** On GitHub, click **Code > Download ZIP** and unzip it.
3. **Copy all the files onto the root of the USB**, for example directly into `E:\` (not inside a folder).
4. **Double-click `install.bat` on the USB.** If Windows SmartScreen appears, click **More info > Run anyway**.
5. **Pick your model(s).** Type a number, for example `1`, or several separated by commas, like `2,5`.
6. **Install AnythingLLM onto the USB.** Partway through, the AnythingLLM installer opens:
   - When it asks where to install, choose the `anythingllm` folder on your USB, for example `E:\anythingllm`. The setup window shows the exact path.
   - At the end, **untick "Run AnythingLLM"** and click Finish.
7. **Wait for the downloads.** Leave the window open. The AI engine is about 2 GB and takes a few minutes to unpack onto the USB; the window can look idle while it does. If the internet drops or you close the window, run `install.bat` again: finished steps are skipped and downloads continue where they stopped.

When it says **SETUP COMPLETE**, you're done. If it says **SETUP FINISHED WITH PROBLEMS**, it lists what failed and why. Fix that and run `install.bat` again.

## Using it

1. Plug in the USB and double-click **`start-windows.bat`**.
2. Keep the black window open. It runs the AI engine.
3. Chat in the AnythingLLM window. To switch models, go to **Settings > LLM**.
4. When you're done, click the black window and **press Enter**. That shuts everything down cleanly.
5. Safely eject the USB before unplugging it.

Replies take roughly 10 to 30 seconds on a typical CPU. A PC with a recent NVIDIA or AMD graphics card is much faster; Ollama uses it automatically.

**Check it's private:** turn off Wi-Fi and send a message. If it still answers, everything is running from the USB.

## Privacy notes

- The USB engine runs on its own port (`127.0.0.1:11435`), accessible only from the same PC. It never mixes with a copy of Ollama already installed on the PC.
- Models, chats and settings are stored on the USB. Ollama's identity key is stored on the USB too.
- AnythingLLM's anonymous usage statistics are switched off.
- **Setup leaves a trace on the PC you install from.** The AnythingLLM installer adds an entry to that PC's installed-apps list. You can remove it under **Settings > Apps** afterwards. The app itself stays on the USB. Running the AI on other PCs doesn't install anything on them.
- **One feature can go online.** The first time you upload a document into a chat, AnythingLLM downloads a small embedding model (the model it uses to search documents) from the internet. Plain chatting never needs the internet.
- If you change AnythingLLM's LLM provider to a cloud service (such as OpenAI), your chats go to that service. The launcher warns you when this is the case.

## Troubleshooting

| Problem | Fix |
|---|---|
| "This drive is formatted as FAT32" | Back up the USB, reformat it as exFAT, copy the files back and run `install.bat` again. |
| "These files are on C:" | You ran it from your PC's own drive. Copy the files to the USB first. |
| "AnythingLLM was installed on this PC instead of the USB" | Uninstall AnythingLLM under Settings > Apps, run `install.bat` again and choose the USB folder in the installer. |
| "Port 11435 is already in use" | Another program uses that port. Close it or restart the PC, then try again. |
| "The AI engine did not start" | The last lines of `ollama\server.log` are shown. Common causes: not enough free RAM, or antivirus blocking `ollama.exe`. |
| "JavaScript error" when AnythingLLM opens | Close it and run `start-windows.bat` again. The launcher clears the old PC's cached paths. |
| No models in AnythingLLM | Run `install.bat` again and pick a model. |
| Many lines like `lib/ollama/...: Can't restore time: Invalid argument` | You have an older copy of the scripts. The files were unpacked, but setup then switched to a much slower unzip. Let that finish if it's running. If it failed or you closed it, delete the `ollama` folder on the USB, [update the scripts](#updating-the-scripts) and run `install.bat` again. |
| Setup seems stuck on "Extracting" | Unpacking the engine takes a few minutes on a USB drive. If it says "Trying the slower built-in unzip instead", it can take 10 minutes or more. Don't close the window. |
| Antivirus blocks or deletes `ollama.exe` | Allow it in your antivirus. It's the official, digitally signed Ollama engine, and setup checks its checksum. Then run `install.bat` again. |

## Updating the scripts

To get a newer version of these scripts without losing your models or chats:

1. Download the latest ZIP from this repo (**Code > Download ZIP**) and unzip it.
2. Copy only these files onto the USB, replacing the old ones: `install.bat`, `start-windows.bat`, `install-core.ps1`, `start-core.ps1`, `common.ps1`, and `README.md`.

Don't delete the `ollama`, `models`, `anythingllm` or `anythingllm_data` folders. They hold your engine, your models, the chat app and your chats.

## What's on the USB after setup

```
USB Drive\
|-- install.bat          <- run once to set up (or again to add models)
|-- start-windows.bat    <- run every time to start the AI
|-- install-core.ps1     <- setup logic (called by install.bat)
|-- start-core.ps1       <- launcher logic (called by start-windows.bat)
|-- common.ps1           <- shared helpers
|-- ollama\              <- AI engine; your models live in ollama\data
|-- models\              <- list of installed models (downloads are deleted after import)
|-- anythingllm\         <- chat app
`-- anythingllm_data\    <- your chats and settings
```

## What changed from the original

- **Removed** the Mac and Linux files and the unused `optimiced.bat`.
- **Doesn't touch Ollama already installed on the PC.** Before, if the PC already ran Ollama, models could be imported into the PC instead of the USB, and shutting down killed the PC's Ollama too. The USB engine now uses its own port, and shutdown stops only the processes it started.
- **Downloads are verified.** Models are checked against the SHA-256 checksums published on Hugging Face. The Ollama engine is checked against its release's published checksums. The AnythingLLM installer's digital signature is checked.
- **Downloads resume and can't be mistaken for finished.** A download goes to a `.part` file and only counts once it completes and passes verification. Before, an interrupted download could be treated as done.
- **Failures are reported.** Before, a failed model import was reported as a success, and a failed engine download could still end in "SETUP COMPLETE".
- **The engine is started properly.** Setup and the launcher wait for the engine to answer instead of sleeping for a few seconds. Setup checks which models are installed only after the engine starts, so it no longer re-imports every model on every run.
- **Settings are kept.** The launcher updates only the few AnythingLLM settings it needs, instead of overwriting the settings file.
- **About half the disk space per model.** After a model is imported into the engine, the downloaded copy is deleted. Before, every model was stored twice.
- **Safer setup.** Setup stops on FAT32 drives, warns when run from the PC's own drive, warns when space is low, and detects when AnythingLLM was installed on the PC instead of the USB.
- Files are written without a byte-order mark (BOM) so the default model name isn't corrupted. Batch files use Windows line endings. ARM64 Windows PCs get the ARM64 engine.
- **Unpacking works on exFAT.** The engine is unpacked without restoring file dates, which exFAT drives rejected ("Can't restore time").

## License

MIT License. See [LICENSE](LICENSE).
