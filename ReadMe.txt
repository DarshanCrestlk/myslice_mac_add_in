# Steps for Installing on Mac

1. Ensure you have the following scripts:
   - `build_myslice_installer.sh`: The package creation script.
   - `myslice.sh`: A script that downloads and opens the file in Microsoft Word.

2. To make any changes (e.g., updating the origin or making token-related changes), modify the `myslice.sh` file.

3. Create a Platypus app, which wraps the `myslice.sh` script as a macOS application.

4. Place the following files into a single folder:
   - The Platypus app
   - `myslice.sh`
   - Your application logo
   - `manifest.xml`
   - `build_myslice_installer.sh`

5. Run the following command to make the installer script executable:
   ```
   chmod +x build_myslice_installer.sh
   ./build_myslice_installer.sh
   ```

6. Running the installer script will generate a `build` folder containing a `.pkg` file (the app installer). Double-click the `.pkg` file to install the application on your Mac.

*If there are any mistakes, please correct them and create this as an `.md` (Markdown) file.*

share this pkg file in any mac os (end user just double click on the pkg file and it will install the application)