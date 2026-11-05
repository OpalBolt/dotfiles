# VoxType dictation

Press `Super+V` to start recording. Press it again to stop. VoxType types the
transcript into the focused app, then opens a Foot window with a Yes/No menu.

Choose **Yes** to replace the transcript with text cleaned by the local Ollama
model `gemma4:12b-it-qat`. Choose **No** or press Escape to keep the transcript.
The cleanup removes hesitation sounds and filler phrases. If Ollama fails, the
original text stays in place.

After the cleaned text appears, a second Foot menu offers **Keep cleaned** or
**Undo cleanup**. Choose **Undo cleanup** to restore the raw transcript. Choose
**Keep cleaned** or press Escape to leave the cleaned text in place.

Keep the cursor at the end of the text until you close the second popup. Do
not edit the text while either popup is open. The script replaces text with
Backspace keystrokes, so it must find the cursor at the end of the text.

`scripts/record-toggle.sh` toggles recording for Mango and Waybar.
`scripts/post-process.sh` types the raw transcript and opens the popup.
`scripts/cleanup-prompt.sh` shows the menu and calls Ollama only for **Yes**.

Requires VoxType, Mango, Foot, `tv` (television), `wtype`, `jq`, `curl`, and a
local Ollama server with `gemma4:12b-it-qat` installed.
