=== 2.0 / 2016-03-DD

*   Rewrote for compatibility with cartage 2.0.

*   1 major enhancements

    *   Configuration now supports multiple servers. Old cartage-remote
        configurations will continue to work and be accessible as the +default+
        host. An error will be raised if there is an explicit +default+
        host combined with this implicit +default+ host.

=== 1.1 / 2015-03-26

*   1 major bugfix

    *   When a remote script fails, the error would not result in a non-zero
        exit code, meaning that scripts could not detect failures in cartage
        remote. Fixes [#1]{https://github.com/KineticCafe/cartage/issues/1}.

*   1 minor enhancement

    *   When the build is interrupted and a postbuild script is to be run, it
        will be passed the exception error message as well as the stage.

*   1 minor bugfix

    *   Ensured that the last stage is not +cleanup+; added a +finished+ stage.

*   Internal changes:

    *   Using [micromachine]{https://github.com/soveran/micromachine} to
        provide the remote builds state machine cleanly.

=== 1.0 / 2015-03-24

*   1 major enhancement

    *   Birthday!
