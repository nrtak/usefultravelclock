"""Generate release-only signing overrides without changing simulator settings."""
from pathlib import Path
import os
import plistlib

root = Path(__file__).resolve().parent.parent
temp = Path(os.environ['RUNNER_TEMP'])
team = 'R3233N87DC'
profiles = {}
for kind, bundle in [('app', 'com.usefultravelclock.app'), ('widget', 'com.usefultravelclock.app.widget')]:
    with (temp / f'{kind}.plist').open('rb') as file:
        profile = plistlib.load(file)
    entitlements = profile['Entitlements']
    assert entitlements['application-identifier'] == f'{team}.{bundle}', 'Wrong profile bundle ID'
    assert 'group.com.usefultravelclock.app' in entitlements['com.apple.security.application-groups'], 'Missing App Group'
    assert not entitlements.get('get-task-allow', False), 'Development profile supplied'
    profiles[bundle] = profile['Name']

lines = ['include:', '  - project.yml', 'targets:']
for target, bundle in [('UsefulTravelClock', 'com.usefultravelclock.app'), ('UsefulTravelClockWidget', 'com.usefultravelclock.app.widget')]:
    lines += [f'  {target}:', '    settings:', '      configs:', '        Release:',
              f'          DEVELOPMENT_TEAM: {team}', '          CODE_SIGN_STYLE: Manual',
              '          CODE_SIGN_IDENTITY: Apple Distribution',
              f'          PROVISIONING_PROFILE_SPECIFIER: "{profiles[bundle]}"']
(root / 'project-release.yml').write_text('\n'.join(lines) + '\n')
with (root / 'ExportOptions.plist').open('wb') as file:
    plistlib.dump({'method': 'app-store-connect', 'teamID': team, 'signingStyle': 'manual',
                  'signingCertificate': 'Apple Distribution', 'provisioningProfiles': profiles,
                  'manageAppVersionAndBuildNumber': False, 'uploadSymbols': True}, file)
