Python for Windows ARM32
=================================
.. contents::

Prerequisites
-------------

- `Microsoft Visual Studio 2017 <https://visualstudio.microsoft.com/downloads/>`_
- `Git for Windows <https://git-scm.com/downloads>`_

Get the CPython on Windows ARM32 code
------------

Check out the code for ARM32 code::

    git clone https://github.com/ms-iot/cpython.git
    cd cpython
    git checkout win-arm32-master
    .\PCbuild\get_externals.bat

Get OpenSSL for Windows ARM32
-----------------------------

To get the OpenSSL binaries for Windows ARM32 you will need to build them yourself::

    cd ..
    git clone https://github.com/paulmon/openssl.git
    cd openssl
    git checkout win-arm32-patch
    call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsamd64_arm.bat"
    perl Configure VC-WIN32 no-asm --prefix=e:\openssl --openssldir=arm32
    nmake
    REM copy files directly to cpython externals
    md ..\cpython\externals\openssl-bin-1.1.0h\arm32\include\openssl
    copy LICENSE ..\cpython\externals\openssl-bin-1.1.0h\arm32
    copy include\openssl\*.h ..\cpython\externals\openssl-bin-1.1.0h\arm32\include\openssl
    copy ms\applink.c ..\cpython\externals\openssl-bin-1.1.0h\arm32\include
    copy *.lib ..\cpython\externals\openssl-bin-1.1.0h\arm32
    copy libcrypto-1_1.dll ..\cpython\externals\openssl-bin-1.1.0h\arm32
    copy libcrypto-1_1.pdb ..\cpython\externals\openssl-bin-1.1.0h\arm32
    copy libssl-1_1.dll ..\cpython\externals\openssl-bin-1.1.0h\arm32
    copy libssl-1_1.pdb ..\cpython\externals\openssl-bin-1.1.0h\arm32
    cd ..\cpython

Build CPython and stage files for xcopy install
-----------------------------------------------

To build a retail image::

    Tools\winiot\build.bat -arm -r -c

To build a debug image with test files::

    Tools\winiot\build.bat -arm -r -c

Copy debug files to Windows IoT Core device and run tests
---------------------------------------------------------

Map a drive and copy the files::

    net use Q: \\<device ip address>\c$ /user:administrator
    copy E:\code2\cpython\PCbuild\iot\arm32\Debug\ Q:\pythond

Connect via `ssh <https://docs.microsoft.com/en-us/windows/iot-core/connect-your-device/ssh>`_ and run the standard library tests::

    ssh administrator@<device ip>
    
    set PATH=%PATH%;c:\pythond;c:\pythond\scripts
    set PYTHONHOME=c:\pythond

    REM fix case of TEMP directory variable for tests
    set TEMP=C:\Windows\Temp

    REM Run tests
    python -m test -j3

Copy release files to device
----------------------------

Map a drive and copy the files::

    net use Q: \\<device ip address>\c$ /user:administrator
    copy E:\code2\cpython\PCbuild\iot\arm32\Release\ Q:\python

Connect via `ssh <https://docs.microsoft.com/en-us/windows/iot-core/connect-your-device/ssh>`_ and test install::

    ssh administrator@<device ip>
    
    set PATH=%PATH%;c:\python;c:\python\scripts
    set PYTHONHOME=c:\python

    python -c "print ('Hello, ARM32!')"