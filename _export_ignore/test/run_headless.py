#!/usr/bin/env python3
"""Import Editor Console in a disposable project and check its GDSh integration."""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--keep', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[4]
    project = Path(tempfile.mkdtemp(prefix='editor-console-tests-'))
    print(f'Isolated project: {project}', flush=True)
    try:
        # Every package's tests live under (_)export_ignore, so skip those and copy ours back in.
        for directory in ['addons/_lib', 'addons/editor_console', 'addons/zyx_popup_wrapper', 'addons/editor_console/export_ignore/test']:
            shutil.copytree(repo / directory, project / directory,
                            ignore=shutil.ignore_patterns('.git', 'export_ignore', '_export_ignore', '__pycache__', '*.py'))
        # Shared test-only TUI from GDSh's tests; it is deliberately absent from GDSh builtins.
        fixture_dir = Path('addons/_lib/gdsh/_export_ignore/test/fixtures')
        (project / fixture_dir).mkdir(parents=True, exist_ok=True)
        for name in ['tui_list.gd', 'tui_list.gd.uid']:
            shutil.copy2(repo / fixture_dir / name, project / fixture_dir / name)
        (project / 'project.godot').write_text('''config_version=5
[application]
config/name="Editor Console integration tests"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
        commands = [
            [args.godot, '--headless', '--path', str(project), '--editor', '--import'],
            # Import registers global classes but does not compile every script body.
            [args.godot, '--headless', '--path', str(project), '--script', 'res://addons/editor_console/src/editor_console.gd', '--check-only'],
            [args.godot, '--headless', '--path', str(project), '--script', 'res://addons/editor_console/export_ignore/test/runtime_test.gd', '--check-only'],
            [args.godot, '--headless', '--path', str(project), '--script', 'res://addons/editor_console/export_ignore/test/runtime_test.gd'],
        ]
        for command in commands:
            stage = 'isolated import' if '--import' in command else (
                'parse ' + command[command.index('--script') + 1] if '--check-only' in command else 'runtime tests')
            print(f'Running: {stage}', flush=True)
            try:
                result = subprocess.run(command, stdin=subprocess.DEVNULL, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            except subprocess.TimeoutExpired as error:
                output = error.stdout or b''
                print(output.decode(errors='replace') if isinstance(output, bytes) else output, flush=True)
                print(f'FAIL: {stage} timed out after {error.timeout}s', flush=True)
                return 1
            if result.returncode or 'SCRIPT ERROR:' in result.stdout or 'Parse Error:' in result.stdout:
                print(result.stdout, flush=True)
                print(f'FAIL: {stage}', flush=True)
                return 1
            print(f'PASS: {stage}' if '--import' in command or '--check-only' in command else result.stdout, flush=True)
        return 0
    finally:
        if not args.keep:
            shutil.rmtree(project)


if __name__ == '__main__':
    raise SystemExit(main())
