
# Zenivine

Zenivine is a quick and easy PowerShell script designed to add Widevine support to the Zen Browser. The script fetches necessary assets directly from Mozilla and integrates them into the Zen Browser's profile directories. This script is provided as-is, leveraging official assets from Mozilla.

## Usage

To run the Zenivine script directly from GitHub, open your PowerShell (with administrator privileges if required) and execute the following command:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/cryptofyre/Zenivine/main/Install-Zenivine.ps1" -OutFile "$env:TEMP\zenivine.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\zenivine.ps1"
```

## How It Works

1. **Fetch Widevine Assets:** The script downloads the required Widevine CDM assets from Mozilla.
2. **Add Widevine Support:** It then integrates these assets into the Zen Browser's profile directories.
3. **User Preferences:** The script optionally adds necessary preferences to the `user.js` file in each profile, ensuring that Widevine support is correctly configured.

## Notes

- **Compatibility:** This script is compatible with Zen Browser and should be run on systems where Zen Browser is installed.
- **Provided As-Is:** The script and associated assets are provided as-is, with no guarantees. Widevine and related assets are sourced directly from Mozilla.

## License

This project is licensed under the [MIT License](LICENSE).
