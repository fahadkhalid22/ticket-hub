from pathlib import Path
android = Path('android/app/src/main/AndroidManifest.xml')
if android.exists():
    text = android.read_text()
    root = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
    additions = []
    if 'android.permission.INTERNET' not in text:
        additions.append('    <uses-permission android:name="android.permission.INTERNET" />')
    if 'android.permission.CAMERA' not in text:
        additions.append('    <uses-permission android:name="android.permission.CAMERA" />')
    if additions:
        text = text.replace(root, root + '\n' + '\n'.join(additions))
    android.write_text(text)
ios = Path('ios/Runner/Info.plist')
if ios.exists():
    text = ios.read_text()
    marker = '</dict>\n</plist>'
    additions = '\n\t<key>NSCameraUsageDescription</key>\n\t<string>TicketHub uses the camera to scan ticket QR codes.</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>TicketHub uses your photo library to upload business and event images.</string>\n'
    if 'NSCameraUsageDescription' not in text:
        text = text.replace(marker, additions + marker)
    ios.write_text(text)
print('Camera/photo permissions configured.')
