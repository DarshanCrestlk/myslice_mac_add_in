# Mac installer and launcher flow (MySliceLTS)

This folder is the **macOS half** of MySlice Office Add-in: build a `.pkg` once, then handle every Document Library **Edit** click via `mysliceLTS://`.

Windows equivalent lives in `myslice_office_add_in_root_launcher` (`officeLuncher` + `mysliceLauncher` + `myslice.ps1`).

The hosted add-in JS (taskpane) is **not** in this folder. It is built in `myslice_office_add_in/office_add_in` and uploaded to S3. Office on Mac loads that JS from `manifest.xml` `SourceLocation`.

---

## `myslice.sh` vs `build_myslice_installer.sh`

**They are different files. They are not copies of each other.**

| File | Role | When it runs | Windows cousin |
| --- | --- | --- | --- |
| `myslice.sh` | Protocol handler (Edit) | Every click of Edit | `myslice.ps1` |
| `build_myslice_installer.sh` | Installer build | Once, on a Mac, to produce `.pkg` | `officeLuncher` / InstallForge |

- **`myslice.sh`**: parse `mysliceLTS://…` → download the file → open Word / Excel / PowerPoint.
- **`build_myslice_installer.sh`**: pack `Myslice.app` + `manifest.xml` into `Myslice_installer.pkg`.

Platypus wraps `myslice.sh` inside `Myslice.app`. The `.pkg` copies that app into `/Applications`.

---

## Folder map

| Path | Purpose |
| --- | --- |
| `myslice.sh` | **Current** protocol handler (source). |
| `Myslice.app` | Platypus app; `Contents/Resources/script` is the bundled handler. |
| `manifest.xml` | Office add-in manifest (S3 taskpane URL, ribbon). |
| `build_myslice_installer.sh` | **Current** `.pkg` builder (`Myslice`, `manifest.xml`, `logo-filled.png`). |
| `build_myslice_installer_old_stable.sh` | Old builder (`Myslicetest`, `myslice_addin_manifest.xml`). |
| `myslice copy.sh` / `myslice[with temp file].sh` | Older handler copies (logging / temp variants). |
| `build/` | Last `.pkg` expand: payload, postinstall, extracted app. |
| `Office Add-in script -part.md` | Short notes (this file replaces that for flow). |

---

## Big picture

```text
BUILD (developer Mac, once per release)
  myslice.sh  --Platypus-->  Myslice.app
  Myslice.app + manifest.xml + logo
       --build_myslice_installer.sh-->  build/Myslice_installer.pkg

INSTALL (user Mac, once)
  .pkg → /Applications/Myslice.app
  postinstall → copy manifest into Word/Excel/PowerPoint WEF
  Launch Services registers the protocol

EDIT (every Document Library click)
  Web: mysliceLTS://<https-file-url>?ext=docx&file_id=<uuid>&origin=myslice-people
  → Myslice.app → myslice.sh
  → download to temp: name.ext(uuid+timestamp)
  → open Word / Excel
  → Office add-in JS (S3) binds token from the file name
```

---

## 1. Build the protocol app (Platypus)

Platypus turns `myslice.sh` into `Myslice.app`.

Typical settings:

- Script: `myslice.sh`
- Bundle / protocol: `mysliceLTS` (also accepts `myslicelts`, `myslicetest` in the script)
- Output: `./Myslice.app`

The running copy of the script is:

`Myslice.app/Contents/Resources/script`

After changing `myslice.sh`, rebuild the `.app` in Platypus, then rebuild the `.pkg`.

---

## 2. Build the installer (`build_myslice_installer.sh`)

Run on macOS from this folder:

```bash
chmod +x build_myslice_installer.sh
./build_myslice_installer.sh
```

Requires:

- `./Myslice.app`
- `./manifest.xml`
- `./logo-filled.png`

What it does:

1. Cleans `./build`.
2. Copies `Myslice.app` → `build/payload/Applications/Myslice.app`.
3. Copies logo into the app `Contents/Resources`.
4. Copies `manifest.xml` → `build/payload/usr/local/myslice_manifests/`.
5. Writes `build/scripts/postinstall`.
6. `pkgbuild` → `build/Myslice_installer.pkg`.
7. Expands the pkg to verify the app is inside.

Identifiers:

- App: `org.crestmini2.myslice`
- Installer: `org.crestmini2.myslice.installer`

---

## 3. Install (`postinstall`)

User runs `Myslice_installer.pkg`. After files land:

1. Detect current user (`SUDO_USER` or console user).
2. Create `~/Library/Application Support/myslice` and `~/Library/Logs/myslice`.
3. Copy manifest there.
4. Copy the same manifest into Office WEF for **Word, Excel, Powerpoint**:

   `~/Library/Containers/com.microsoft.<App>/Data/Documents/wef/manifest.xml`

5. `lsregister -f /Applications/Myslice.app` (protocol / Launch Services).
6. Restart Dock.
7. Remove `/usr/local/myslice_manifests` (staging only).

Office must be restarted so it picks up the WEF manifest. Taskpane HTML/JS still load from the **S3 URL** in `manifest.xml`, not from this pkg.

---

## 4. Edit launch (`myslice.sh`)

Web Edit URL (example):

```text
mysliceLTS://https://…/file.docx?ext=docx&file_id=<uuid>&origin=myslice-people
```

`&` or extra `?` separators both work with the current `sed` (`file_id=\([^?]*\)`). If `file_url` is already a signed URL with `?`, append `&ext=` / `&file_id=` / `&origin=`.

Script steps:

1. Require one argument (the protocol URL).
2. Strip prefix `myslicelts://` | `myslicetest://` | `mysliceLTS://`.
3. Fix `https//` → `https://`.
4. Parse `file_id`, `ext`, optional `p=` (permissions).
5. Clean a base name from the download URL.
6. `mktemp -d -t myslice-` then download with `curl` to:

   `{cleaned}.{ext}({file_id}+{yyyyMMddHHmmss})`

7. Open with `open -a` Word / Excel / PowerPoint (or TextEdit/VS Code for `txt`).
8. Exit immediately (`open … &`). Temp dir is **not** deleted on success (manual / cron cleanup).

Supported `ext`: `docx|doc|dotx|dot`, `xlsx|xls|xltx|xlt`, `pptx|ppt|potx|pot`, `txt`.

---

## 5. After Office opens (add-in JS, not this repo)

The add-in (deployed JS) reads the UUID from the temp file name, calls `check-fid`, stores `token` (and `origin` **if** it is in the name).

Ribbon / API host follow origin in the **Windows** add-in + launcher. See gap below for Mac.

---

## Gap vs Windows `myslice.ps1`

Current `myslice.sh` does **not** parse `origin`.

| | Windows `myslice.ps1` | Mac `myslice.sh` |
| --- | --- | --- |
| `file_id`, `ext`, `p` | Yes | Yes |
| `origin` in file name | `name.ext(uuid+time+myslice-people)` | `name.ext(uuid+time)` only |
| Seal / people / HRMS ribbon + API | Add-in can read origin | Origin missing → add-in falls back to HRMS |

To match Windows, `myslice.sh` must parse `origin=` and append it to `TEMP_FILE_BASENAME` (and rebuild Platypus `.app` + `.pkg`).

---

## Protocol notes

Valid prefixes in `myslice.sh`: `mysliceLTS`, `myslicelts`, `myslicetest`.

`origin=myslice-people` is a valid slug for the add-in, but it only takes effect on Mac **after** the handler stamps it into the temp file name.

`ext` must be a short type (`docx` / `xlsx` / `pptx`), not a full MIME string.

---

## Related Windows docs

`myslice_office_add_in_root_launcher/markdown/INSTALLER-AND-LAUNCHER-FLOW.md`
