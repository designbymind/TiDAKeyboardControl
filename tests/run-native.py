#!/usr/bin/env python3
"""Run native inset regressions on an existing, booted arm64 iOS simulator."""
import argparse
from pathlib import Path
import plistlib
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True, help='Existing booted simulator UDID')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
app = Path(tempfile.mkdtemp(prefix='dakc-inset-tests-')) / 'ChatInsetTests.app'
app.mkdir()
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-isysroot', sdk,
               '-target', 'arm64-apple-ios18.0-simulator',
               '-framework', 'UIKit', '-framework', 'QuartzCore', '-framework', 'Foundation', '-framework', 'CoreGraphics',
               '-I', str(root / 'DAKeyboardControl'), str(root / 'tests/ChatInsetTests.m'),
               str(root / 'DAKeyboardControl/DAKeyboardControl.m'), '-o', str(app / 'ChatInsetTests')], check=True)
info = {'CFBundleExecutable': 'ChatInsetTests', 'CFBundleIdentifier': 'com.designbymind.chatinsettests',
        'CFBundleName': 'ChatInsetTests', 'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1',
        'CFBundleShortVersionString': '1.0', 'MinimumOSVersion': '18.0', 'UIDeviceFamily': [1, 2],
        'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False,
                                     'UISceneConfigurations': {'UIWindowSceneSessionRoleApplication': [
                                         {'UISceneConfigurationName': 'Default', 'UISceneDelegateClassName': 'TestScene'}]}}}
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
subprocess.run(['xcrun', 'simctl', 'install', args.device, str(app)], check=True)
result = subprocess.run(['xcrun', 'simctl', 'launch', '--terminate-running-process', '--console',
                         args.device, info['CFBundleIdentifier']], text=True, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, timeout=45)
print(result.stdout)
if 'RESULT 0 failures' not in result.stdout or 'FAIL ' in result.stdout:
    raise SystemExit('Native inset regression checks failed or did not complete.')
