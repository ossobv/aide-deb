OSSO build of the aide Advanced Intrusion Detection Environment
===============================================================

This enables builds for aide 0.18.x for older Ubuntu, like *Focal* and *Jammy*.

For *Jessie* it also builds, but with ``--without-posix-acl
--without-xattr --without-e2fsattrs --without-audit``. See the
**Jessie** heading below.


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


Jessie
------

On *Jessie* you cannot use ``aideinit`` because it tries an older
``capsh`` that has no ``--addamb=cap_dac_read_search,cap_audit_write``.
We won't need an ``_aide`` user either.

Other patches:

.. code-block:: diff

    --- a/aide/aide.conf
    +++ b/aide/aide.conf
    @@ -26,7 +26,7 @@ gzip_dbout=yes
     #report_level=changed_attributes

     # Ignore e2fs attributes that cannot be set manually
    -report_ignore_e2fsattrs=VNIE
    +#report_ignore_e2fsattrs=VNIE

     # Set to yes to print the checksums in the report in hex format
     #report_base16 = false

.. code-block:: diff

    --- a/aide/aide.conf.d/01_aide_custom
    +++ b/aide/aide.conf.d/01_aide_custom
    @@ -20,12 +20,12 @@ database_attrs = E
     #report_level=changed_attributes

     # Audit tools
    -/sbin/auditctl p+i+n+u+g+s+b+acl+xattrs+sha512
    -/sbin/aureport p+i+n+u+g+s+b+acl+xattrs+sha512
    -/sbin/ausearch p+i+n+u+g+s+b+acl+xattrs+sha512
    -/sbin/autrace p+i+n+u+g+s+b+acl+xattrs+sha512
    -/sbin/auditd p+i+n+u+g+s+b+acl+xattrs+sha512
    -/sbin/augenrules p+i+n+u+g+s+b+acl+xattrs+sha512
    +/sbin/auditctl p+i+n+u+g+s+b+sha512
    +/sbin/aureport p+i+n+u+g+s+b+sha512
    +/sbin/ausearch p+i+n+u+g+s+b+sha512
    +/sbin/autrace p+i+n+u+g+s+b+sha512
    +/sbin/auditd p+i+n+u+g+s+b+sha512
    +/sbin/augenrules p+i+n+u+g+s+b+sha512

     # Include the following dirs
     /boot R

Run ``aide`` as root:

.. code-block:: console

    # aide --config=/etc/aide/aide.conf --init
    Start timestamp: 2024-03-01 14:46:37 +0100 (AIDE 0.18.6)
    AIDE successfully initialized database.
    New AIDE database written to /var/lib/aide/aide.db.new

    Number of entries:      14404

    End timestamp: 2024-03-01 14:46:40 +0100 (run time: 0m 3s)

.. code-block:: console

    # aide --config=/etc/aide/aide.conf --check
    Start timestamp: 2024-03-01 14:47:59 +0100 (AIDE 0.18.6)
    AIDE found differences between database and filesystem!!

    Summary:
      Total number of entries:      14404
      Added entries:                0
      Removed entries:              0
      Changed entries:              1
    ...

Additionally, you will need to setup a *cronjob* or *systemd.timer* and
appropriate *service* file as well. (They aren't installed because of
the missing ``dh_installsystemd``.)

Possible ``aidecheck.service`` file:

.. code-block:: ini

    [Unit]
    Description=AIDE Check

    [Service]
    Type=simple
    # We bump the timeout because AIDE can take quite some time to finish
    TimeoutStartSec=3600

    # AIDE doesn't exit with 0 if it found differences, resulting in a failed
    # systemd unit which we don't really want.
    ExecStart=/bin/sh -c '/usr/bin/aide --config /etc/aide/aide.conf --update || /bin/true'

    # AIDE writes a /var/lib/aide/aide.db.new with the results of the scan. The
    # checks however are always done against /var/lib/aide/aide.db which never gets
    # updated so we move this manually
    ExecStop=/bin/sh -c 'if test -s /var/lib/aide/aide.db.new; then mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db && echo "Moved /var/lib/aide/aide.db.new to /var/lib/aide/aide.db"; else echo "No /var/lib/aide/aide.db.new found, not moving"; fi'

    SyslogIdentifier=aide

Possible ``aidecheck.timer`` file:

.. code-block:: ini

    [Unit]
    Description=Aide check every day at 5AM

    [Timer]
    OnCalendar=*-*-* 05:00:00
    Unit=aidecheck.service

    [Install]
    WantedBy=multi-user.target
