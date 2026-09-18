# Pitchfork

An instrument tuner for the Omarchy Quattro bar. Note, cents, and input level
for a guitar or bass, read from a PipeWire input.

![The Pitchfork panel: a 4-string bass D string in tune at 73.48 Hz, +2 cents, with the low E and A already checked off](preview.png)

## Install

```
omarchy plugin add https://github.com/KeMezz/omarchy-pitchfork.git --enable
```

Runtime requires the Omarchy Quattro/Quickshell plugin host, `pw-cat` (shipped
with PipeWire), and `python3` 3.12 or newer with `math.sumprod`. They are present
on a stock Omarchy system; Pitchfork installs no packages and compiles nothing.

## Update and remove

```
omarchy plugin update io.github.kemezz.pitchfork
omarchy plugin remove io.github.kemezz.pitchfork
```

Removing deletes the plugin directory and takes the widget out of the bar. Your
chosen input and instrument live in `~/.config/omarchy-pitchfork/`, outside the
plugin directory, so delete that too for a clean uninstall:

```
rm -rf ~/.config/omarchy-pitchfork
```

When upgrading from the earlier Omarchy Tuner/Pitchfork state layout, version
0.2.1 imports the saved input and tuning into `settings.json` the first time the
new file is absent. It keeps the legacy file as a recovery copy.

## Use

Click the tuning fork in the bar, pick **Chromatic**, **Guitar** or **Bass**,
and play a note.

- **Chromatic** names the nearest of the twelve semitones, and asks nothing else.
- **Guitar** and **Bass** add two rows: the instrument (6- or 7-string guitar,
  4-, 5- or 6-string bass) and the tuning applied to it (standard, drop,
  half- or full-step down, DADGAD). The readout then names the nearest of *that
  instrument's own strings*, so a string a whole tone flat still reads as the
  string you meant rather than as its neighbour. The strings sit under the meter
  and fill in as each is played in tune.
- In tune, the whole readout turns the accent colour — and so does the fork in
  the bar, so it reads at a glance with the panel closed.
- The reading is captioned with the instrument and tuning it is being measured
  against, and the bar tooltip carries the same line, so neither has to be
  looked up in a dropdown.

## Custom tunings

Anything not in the built-in list goes in `~/.config/omarchy-pitchfork/tunings.json`.
The file is optional, read at startup and again whenever it is saved, and its
entries appear in the Tuning row underneath the built-in ones.

```json
{
  "tunings": [
    {
      "id": "open-g",
      "label": "Open G",
      "instruments": ["guitar6"],
      "strings": ["D2", "G2", "D3", "G3", "B3", "D4"]
    },
    {
      "id": "two-steps-down",
      "label": "Two steps down",
      "shift": -4
    }
  ]
}
```

- `id` is a slug, unique, and cannot be one the built-ins already use.
- `label` is what the menu shows. It defaults to the id.
- `strings` replaces the string set outright, low string first, sharps or flats.
- `shift` moves every string instead, by a whole number of semitones.
- Exactly one of `strings` or `shift`.
- `instruments` narrows where the tuning is offered. A `strings` entry is only
  ever offered on instruments with that many strings, so a six-note voicing
  never appears on a four-string bass whether it names one or not.

An entry that cannot be tuned to — a duplicate id, a note name that does not
parse, a shift of zero — is skipped, and the rest of the file still loads. A
file that is not valid JSON at all leaves you with the built-in tunings. If a
tuning that is currently selected disappears from the file, the panel falls
back to Standard without rewriting your stored choice, so putting the entry
back restores it.

A laptop's internal microphone is a poor input for this. Its noise floor is high
enough that a quietly played instrument never becomes the most periodic thing in
the window, and an unplugged electric instrument is not audible to it at all.

## What it does to your machine

Plugins run unsandboxed inside the long-lived shell process, so:

- It opens an audio input **only while the panel is open**. Audio is analysed a
  window at a time in memory and discarded — nothing is written to disk and
  nothing leaves the machine.
- While the panel is open it runs `python3 scripts/pitch-detect.py`, which in
  turn runs `pw-cat` to read the input. Both are bound to the panel's lifetime
  even if the shell kills the plugin outright. One `mkdir -p` creates
  `~/.config/omarchy-pitchfork/` for the settings file.
- Device names, saved input ids, and detector errors are always rendered as
  plain text. The verification suite checks every QML `Text` element so those
  strings cannot be interpreted as markup that loads a referenced resource.
- Pitchfork initiates no network connection at runtime. The normal Omarchy
  install and update commands access GitHub only to clone or fetch this source.
- No sudo, no pkexec, no systemd units, no plugin-owned installer, no bundled
  binaries, and no privileged action.
- At runtime, Pitchfork's own code writes exactly one file,
  `~/.config/omarchy-pitchfork/settings.json`; it does not write Omarchy's
  configuration. `tunings.json` in the same directory is read and watched for
  changes, never written, so it stays yours to edit. Omarchy's install, enable, update, and remove commands manage
  the plugin registration outside that runtime boundary.

## Development

```
make check   # validate, lint QML, and run every regression test
make sync    # copy a validated change into the local Omarchy install
make summon  # open the panel
```

A QML change also needs `omarchy-restart-shell`: this Omarchy build has no hot
reload for local plugin components, so a synced `.qml` sits on disk while the
shell serves the copy it loaded at startup. The detector script does not need
the restart.

GitHub Actions runs the portable part of the gate on every push and pull
request: manifest JSON and symlink checks, shell syntax, the `Text.PlainText`
policy lint, and all Node/Python tests. Full `make check` remains the release
gate because `omarchy plugin validate`, `qmllint`, and the `qs.Ui` imports come
from a stock Omarchy installation and are not available on a generic Ubuntu
runner.

If no note appears, `scripts/pitch-detect.py --meter` shows what the detector
actually hears — a moving level bar means capture works, and the aperiodicity
figure says how close a rejected reading was to registering.

[Design notes](docs/design.md) cover the detection algorithm, the detector's
line protocol, the tuning model, and the complete runtime, diagnostic, and
development/CI dependency inventory.

## License

MIT. See `LICENSE`.
