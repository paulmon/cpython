import argparse
import py_compile
import re
import sys
import shutil
import stat
import os
import tempfile

from itertools import chain
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

includeTest = False
includeDebug = False

TKTCL_RE = re.compile(r'^(_?tk|tcl).+\.(pyd|dll)', re.IGNORECASE)
DEBUG_RE = re.compile(r'_d\.(pyd|dll|exe|pdb|lib)$', re.IGNORECASE)
PYTHON_DLL_RE = re.compile(r'python\d\d?\.dll$', re.IGNORECASE)
PYTHON_D_DLL_RE = re.compile(r'python\d\d?_d\.dll$', re.IGNORECASE)

TEST_FILES = {
    '_ctypes_test',
    '_testbuffer',
    '_testcapi',
    '_testconsole',
    '_testimportmultiple',
    '_testmultiphase',
    'xxlimited',
    'python3_dstub',
}

EXCLUDE_FROM_LIBRARY = {
    '__pycache__',
    'idlelib',
    'pydoc_data',
    'site-packages',
    'tkinter',
    'turtledemo',
}

EXCLUDE_FILE_FROM_LIBRARY = {
    'bdist_wininst.py',
}

EXCLUDE_FILE_FROM_LIBS = {
    'liblzma',
    'python3stub',
}

EXCLUDED_FILES = {
    'pyshellext',
    'pyshellext_d'
}

INCLUDED_FILES = {
    'libcrypto-1_1',
    'libssl-1_1',
}

def is_debug(p):
    if p.stem.lower() in INCLUDED_FILES:
        return True

    if p.stem.lower() in EXCLUDED_FILES:
        return False

    if DEBUG_RE.search(p.name):
        return True

    return False

def is_not_debug(p):
    if DEBUG_RE.search(p.name):
        return False

    if TKTCL_RE.search(p.name):
        return False

    includeIfTest = includeTest or (p.stem.lower() not in TEST_FILES)

    return includeIfTest and p.stem.lower() not in EXCLUDED_FILES

def is_not_python(p):
    global includeDebug
    if includeDebug:
        includeFile = is_debug(p)
    else:
        includeFile = is_not_debug(p)

    return includeFile and not PYTHON_DLL_RE.search(p.name) and not PYTHON_D_DLL_RE.search(p.name)

def include_in_lib(p):
    name = p.name.lower()
    if p.is_dir():
        if name in EXCLUDE_FROM_LIBRARY:
            return False
        if name == 'test' and p.parts[-2].lower() == 'lib' and not includeTest:
            return False
        if name in {'test', 'tests'} and p.parts[-3].lower() == 'lib' and not includeTest:
            return False
        return True

    if name in EXCLUDE_FILE_FROM_LIBRARY:
        return False

    suffix = p.suffix.lower()
    return suffix not in {'.pyc', '.pyo', '.exe'}

def include_in_tools(p):
    if p.is_dir() and p.name.lower() in {'scripts', 'i18n', 'pynche', 'demo', 'parser'}:
        return True

    return p.suffix.lower() in {'.py', '.pyw', '.txt'}

BASE_NAME = 'python{0.major}{0.minor}'.format(sys.version_info)

FULL_LAYOUT = [
    ('/', '$source', 'python.exe', is_not_debug),
    ('/', '$source', 'pythonw.exe', is_not_debug),
    ('/', '$source', 'python{}.dll'.format(sys.version_info.major), is_not_debug),
    ('/', '$source', '{}.dll'.format(BASE_NAME), is_not_debug),
    ('DLLs/', '$source', '*.pyd', is_not_debug),
    ('DLLs/', '$source', '*.dll', is_not_python),
    ('Lib/', 'Lib', '**/*', include_in_lib),
    ('Tools/', 'Tools', '**/*', include_in_tools),
]

FULL_LAYOUT_DEBUG = [
    ('/', '$source', 'python_d.exe', is_debug),
    ('/', '$source', 'pythonw_d.exe', is_debug),
    ('/', '$source', 'python{}_d.dll'.format(sys.version_info.major), is_debug),
    ('/', '$source', '{}_d.dll'.format(BASE_NAME), is_debug),
    ('DLLs/', '$source', '*.pyd', is_debug),
    ('DLLs/', '$source', '*.dll', is_not_python),
    ('Lib/', 'Lib', '**/*', include_in_lib),
    ('Tools/', 'Tools', '**/*', include_in_tools),
]

if os.getenv('DOC_FILENAME'):
    FULL_LAYOUT.append(('Doc/', 'Doc/build/htmlhelp', os.getenv('DOC_FILENAME'), None))
if os.getenv('VCREDIST_PATH'):
    FULL_LAYOUT.append(('/', os.getenv('VCREDIST_PATH'), 'vcruntime*.dll', None))

def copy_to_layout(target, rel_sources):
    count = 0
    
    if target.suffix.lower() == '.zip':
        if target.exists():
            target.unlink()

        with ZipFile(str(target), 'w', ZIP_DEFLATED) as f:
            with tempfile.TemporaryDirectory() as tmpdir:
                for s, rel in rel_sources:
                    if rel.suffix.lower() == '.py':
                        pyc = Path(tmpdir) / rel.with_suffix('.pyc').name
                        try:
                            py_compile.compile(str(s), str(pyc), str(rel), doraise=True, optimize=2)
                        except py_compile.PyCompileError:
                            f.write(str(s), str(rel))
                        else:
                            f.write(str(pyc), str(rel.with_suffix('.pyc')))
                    else:
                        f.write(str(s), str(rel))
                    count += 1

    else:
        for s, rel in rel_sources:
            
            dest = target / rel
            try:
                dest.parent.mkdir(parents=True)
            except FileExistsError:
                pass

            if dest.is_file():
                timeNotEqual = True if s.stat().st_mtime !=dest.stat().st_mtime else False
                sizeNotEqual = True if s.stat().st_size != dest.stat().st_size else False

            if not dest.is_file() or timeNotEqual or sizeNotEqual:
                print(dest)
                shutil.copy2(str(s), str(dest))
                count += 1

    return count

def rglob(root, pattern, condition, includeDebug):
    dirs = [root]
    recurse = pattern[:3] in {'**/', '**\\'}
    while dirs:
        d = dirs.pop(0)
        for f in d.glob(pattern[3:] if recurse else pattern):
            if recurse and f.is_dir() and (not condition or condition(f)):
                dirs.append(f)
            elif f.is_file() and (not condition or condition(f)):
                yield f, f.relative_to(root)

def main():
    global includeDebug
    global includeTest

    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--clean', help='Clean output directory', action='store_true', default=False)
    parser.add_argument('-d', '--debug', help='Include debug files', action='store_true', default=False)
    parser.add_argument('-p', '--platform', metavar='dir', help='One of win32, amd64, or arm32', type=Path, default=None)
    parser.add_argument('-t', '--test', help='Include test files', action='store_true', default=False)
    ns = parser.parse_args()

    includeDebug = ns.debug
    platform = ns.platform
    includeTest = ns.test
    
    if includeDebug:
        configuration = 'Debug'
    else:
        configuration = 'Release'

    print ('platform = {}'.format(platform))
    print ('includeDebug = {}'.format(includeDebug))
    print ('includeTest = {}'.format(includeTest))
    print ('configuration = {}'.format(configuration))

    repo = Path(__file__).resolve().parent.parent.parent
    source = Path('{}\PCBuild\{}'.format(repo, platform))
    output = Path('{}\PCBuild\iot\{}\{}'.format(repo, platform, configuration))

    print ('repo = {}'.format(repo))
    print ('source = {}'.format(source))
    print ('output = {}'.format(output)) 

    if ns.clean:
        print ('clean output directory')
        shutil.rmtree(output)

    if not output.is_dir():
        print ('create output directory')
        os.mkdir(output)

    assert isinstance(repo, Path)
    assert isinstance(source, Path)
    assert isinstance(output, Path)

    if includeDebug:
        print ("debug layout selected")
        layout = FULL_LAYOUT_DEBUG 
    else:
        print ("full layout selected")
        layout = FULL_LAYOUT

    for t, s, p, c in layout:
        if s == '$source':
            fs = source
        else:
            fs = repo / s
        print('fs = {}'.format(fs))
        files = rglob(fs, p, c, includeDebug)
        copied = copy_to_layout(output / t.rstrip('/'), files)
        print('Copied {} files'.format(copied))

    print("================================================================================")
    print ('== output = {}'.format(output)) 
    print("================================================================================")

if __name__ == "__main__":
    sys.exit(int(main() or 0))
