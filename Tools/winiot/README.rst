Python for Windows ARM32
=================================
.. contents::

Prerequisites
-------------

- `Microsoft Visual Studio 2017 <https://visualstudio.microsoft.com/downloads/>`_
- `Git for Windows <https://git-scm.com/downloads>`_
- Perl 5 (for OpenSSL Configure)
- `CPython 3.5 or newer (add Python to the path) <https://www.python.org/>`_

Get the CPython on Windows ARM32 code
------------

Check out the Windows ARM32 code for CPython and populate the external dependencies::

    git clone https://github.com/ms-iot/cpython.git
    cd cpython
    git checkout win-arm32-master
    .\PCbuild\get_externals.bat

Get OpenSSL for Windows ARM32
-----------------------------

Build OpenSSL binaries for Windows ARM32::

    cd ..
    git clone https://github.com/openssl/openssl.git
    cd openssl
    git checkout -b win-arm32 OpenSSL_1_1_0i

Start a build environment with vcvarsamd64_arm.bat and apply required patch::

    cmd /k "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsamd64_arm.bat"
    
    REM apply patch required for successful ARM32 build
    git am < ..\cpython\tools\winiot\OpenSSL-for-Windows-ARM32.patch


When running ``perl Configure`` ignore this error::

    It looks like you don't have either nmake.exe or dmake.exe on your PATH,
    so you will not be able to execute the commands from a Makefile. You can
    install dmake.exe with the Perl Package Manager by running:
    ppm install dmake

| Configure the OpenSSL makefile for Windows ARM32
Run ``nmake`` to build OpenSSL::

    perl Configure VC-WIN32 no-asm
    nmake

Exit cmd.exe started with ``cmd /k`` above::

    exit

Copy OpenSSL files for Windows ARM32  to cpython externals::

    md ..\cpython\externals\openssl-bin-1.1.0i\arm32\include\openssl
    copy LICENSE ..\cpython\externals\openssl-bin-1.1.0i\arm32
    copy include\openssl\*.h ..\cpython\externals\openssl-bin-1.1.0i\arm32\include\openssl
    copy ms\applink.c ..\cpython\externals\openssl-bin-1.1.0i\arm32\include
    copy *.lib ..\cpython\externals\openssl-bin-1.1.0i\arm32
    copy libcrypto-1_1.dll ..\cpython\externals\openssl-bin-1.1.0i\arm32
    copy libcrypto-1_1.pdb ..\cpython\externals\openssl-bin-1.1.0i\arm32
    copy libssl-1_1.dll ..\cpython\externals\openssl-bin-1.1.0i\arm32
    copy libssl-1_1.pdb ..\cpython\externals\openssl-bin-1.1.0i\arm32

Return to the Python clone root::

    cd ..\cpython

Build CPython and stage files for xcopy install
-----------------------------------------------

Building using Tools\winiot\build.bat requires CPython 3.5 or greater to be on the path.

To build a retail image::

    Tools\winiot\build.bat -arm -r -c

To build a debug image with test files::

    Tools\winiot\build.bat -arm -r -c -d -t

Copy debug files to Windows IoT Core device and run tests
---------------------------------------------------------

Map a drive and copy the files::

    net use Q: \\<device ip address>\c$ /user:\administrator
    robocopy /S PCbuild\iot\arm32\Debug\ Q:\pythond

Connect via `ssh <https://docs.microsoft.com/en-us/windows/iot-core/connect-your-device/ssh>`_ and run the standard library tests::

    ssh administrator@<device ip>
    
    set PATH=%PATH%;c:\pythond;c:\pythond\scripts
    set PYTHONHOME=c:\pythond

    REM fix case of TEMP directory variable for tests
    set TEMP=C:\Windows\Temp

    REM Run tests
    python_d -m test -j3

    REM Run ssl tests with network resources enabled
    python_d -Werror -bb -m test -u urlfetch -u network -v test_ssl

Copy release files to device
----------------------------

Map a drive and copy the files::

    net use Q: \\<device ip address>\c$ /user:administrator
    robocopy /S PCbuild\iot\arm32\Release\ Q:\python

Connect via `ssh <https://docs.microsoft.com/en-us/windows/iot-core/connect-your-device/ssh>`_ and test install::

    ssh administrator@<device ip>
    
    set PATH=%PATH%;c:\python;c:\python\scripts
    set PYTHONHOME=c:\python

    python -c "print ('Hello, ARM32!')"

Installing pip
--------------

To install pip run the ensurepip module and then check for upgrades::

    python -m ensurepip
    python -m pip install --upgrade pip