OSSO build of the aide Advanced Intrusion Detection Environment
===============================================================

This enables builds for aide 0.18.x for older Ubuntu, like *Focal* and *Jammy*.


Docker build
------------

Just do::

    ./Dockerfile.build

And it will create the build files in ``Dockerfile.out/``.

For example::

    $ dpkg-deb -c jammy/aide_0.18.6-2osso0+ubu22.04/aide_0.18.6-2osso0+ubu22.04_amd64.deb
    drwxr-xr-x root/root         0 2023-03-01 11:40 ./
    drwxr-xr-x root/root         0 2023-03-01 11:40 ./usr/
    drwxr-xr-x root/root         0 2023-03-01 11:40 ./usr/bin/
    -rwxr-xr-x root/root    220456 2023-03-01 11:40 ./usr/bin/aide
    ...
