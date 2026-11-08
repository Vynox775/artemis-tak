{
  "name": "artemis-tak-overlay",
  "productName": "Artemis TAK",
  "version": "1.1.0",
  "description": "Artemis TAK",
  "main": "main.js",
  "license": "MIT",
  "author": "Artemis Defense Group",
  "scripts": {
    "start": "electron .",
    "dist": "electron-builder --win nsis --publish never"
  },
  "dependencies": {
    "electron-updater": "6.3.9"
  },
  "devDependencies": {
    "electron": "33.2.1",
    "electron-builder": "25.1.8"
  },
  "build": {
    "appId": "com.artemis.tak",
    "productName": "Artemis TAK",
    "files": [
      "main.js",
      "preload.js",
      "icon.ico"
    ],
    "win": {
      "target": "nsis",
      "icon": "icon.ico"
    },
    "nsis": {
      "oneClick": true,
      "artifactName": "artemis-tak.exe",
      "createDesktopShortcut": true,
      "createStartMenuShortcut": true,
      "shortcutName": "Artemis TAK",
      "installerIcon": "icon.ico",
      "uninstallerIcon": "icon.ico"
    },
    "publish": [
      {
        "provider": "github",
        "owner": "Vynox775",
        "repo": "artemis-tak-download",
        "releaseType": "release"
      }
    ]
  }
}