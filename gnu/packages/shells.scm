;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013 Cyril Roelandt <tipecaml@gmail.com>
;;; Copyright © 2014, 2015 David Thompson <davet@gnu.org>
;;; Copyright © 2014 Kevin Lemonnier <lemonnierk@ulrar.net>
;;; Copyright © 2015 Jeff Mickey <j@codemac.net>
;;; Copyright © 2016 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2016 Stefan Reichör <stefan@xsteve.at>
;;; Copyright © 2017 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2017 ng0 <contact.ng0@cryptolab.net>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages shells)
  #:use-module (gnu packages)
  #:use-module (gnu packages algebra)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages libedit)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages pcre)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages readline)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix licenses)
  #:use-module (guix packages))

(define-public dash
  (package
    (name "dash")
    (version "0.5.9")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "http://gondor.apana.org.au/~herbert/dash/files/"
                           name "-" version ".tar.gz"))
       (sha256
        (base32
         "17328wd9n5krr5wd37smrk0y7fdf8aa3hmhm02br5mqpq0a3nycj"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; The man page hails from BSD, where (d)ash is the default shell.
           ;; This isn't the case on Guix or indeed most other GNU systems.
           (substitute* "src/dash.1"
             (("the standard command interpreter for the system")
              "a command interpreter based on the original Bourne shell"))
           #t))))
    (build-system gnu-build-system)
    (inputs
     `(("libedit" ,libedit)))
    (arguments
     `(#:configure-flags '("--with-libedit")))
    (home-page "http://gondor.apana.org.au/~herbert/dash")
    (synopsis "POSIX-compliant shell optimised for size")
    (description
     "dash is a POSIX-compliant @command{/bin/sh} implementation that aims to be
as small as possible, often without sacrificing speed.  It is faster than the
GNU Bourne-Again Shell (@command{bash}) at most scripted tasks.  dash is a
direct descendant of NetBSD's Almquist Shell (@command{ash}).")
    (license (list bsd-3
                   gpl2+))))    ; mksignames.c

(define-public fish
  (package
    (name "fish")
    (version "2.5.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://fishshell.com/files/"
                                  version "/fish-" version ".tar.gz"))
              (sha256
               (base32
                "0kn2n9qr9cksg2cl78f3w0yd24368d35djhi6w5x3gbdxk23ywq3"))
              (modules '((guix build utils)))
              ;; Don't try to install /etc/fish/config.fish.
              (snippet
               '(substitute* "Makefile.in"
                  ((".*INSTALL.*sysconfdir.*fish.*") "")))))
    (build-system gnu-build-system)
    (native-inputs
     `(("doxygen" ,doxygen)
       ;; XXX These are needed to bootstrap the 2.5.0 tarball, and can probably
       ;; be removed along with the ‘bootstrap’ phase on the next update.
       ("autoconf" ,autoconf)
       ("automake" ,automake)
       ("libtool" ,libtool)))
    (inputs
     `(("bc" ,bc)
       ("ncurses" ,ncurses)
       ("pcre2" ,pcre2)               ;don't use the bundled PCRE2
       ("python" ,python-wrapper)))   ;for fish_config and manpage completions
    (arguments
     '(#:tests? #f ; no check target
       #:configure-flags '("--sysconfdir=/etc")
       #:phases
       (modify-phases %standard-phases
         ;; Embed absolute paths to store items.
         (add-after 'unpack 'embed-store-paths
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (substitute* '("share/functions/math.fish"
                            "share/functions/seq.fish")
               (("\\| bc")
                (string-append "| " (assoc-ref %build-inputs "bc")
                               "/bin/bc")))
             (substitute* "share/functions/fish_update_completions.fish"
               (("python") (which "python")))
             #t))
         (add-before 'configure 'bootstrap
           (lambda _
             (zero? (system* "autoreconf" "-vfi")))))))
    (synopsis "The friendly interactive shell")
    (description
     "Fish (friendly interactive shell) is a shell focused on interactive use,
discoverability, and friendliness.  Fish has very user-friendly and powerful
tab-completion, including descriptions of every completion, completion of
strings with wildcards, and many completions for specific commands.  It also
has extensive and discoverable help.  A special help command gives access to
all the fish documentation in your web browser.  Other features include smart
terminal handling based on terminfo, an easy to search history, and syntax
highlighting.")
    (home-page "https://fishshell.com/")
    (license gpl2)))

(define-public rc
  (package
    (name "rc")
    (version "1.7.4")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "git://github.com/rakitzis/rc.git")
                    ;; commit name 'release: rc-1.7.4'
                    (commit "c884da53a7c885d46ace2b92de78946855b18e92")))
              (sha256
               (base32
                "00mgzvrrh9w96xa85g4gjbsvq02f08k4jwjcdnxq7kyh5xgiw95l"))
              (file-name (string-append name "-" version "-checkout"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       '("--with-edit=gnu")
       #:phases
       (modify-phases %standard-phases
         (add-after
          'unpack 'autoreconf
          (lambda _ (zero? (system* "autoreconf" "-vfi"))))
         (add-before
          'autoreconf 'patch-trip.rc
          (lambda _
            (substitute* "trip.rc"
              (("/bin/pwd") (which "pwd"))
              (("/bin/sh")  (which "sh"))
              (("/bin/rm")  (which "rm"))
              (("/bin\\)")  (string-append (dirname (which "rm")) ")")))
            #t)))))
    (inputs `(("readline" ,readline)
              ("perl" ,perl)))
    (native-inputs `(("autoconf" ,autoconf)
                     ("automake" ,automake)
                     ("libtool" ,libtool)
                     ("pkg-config" ,pkg-config)))
    (synopsis "Alternative implementation of the rc shell by Byron Rakitzis")
    (description
     "This is a reimplementation by Byron Rakitzis of the Plan 9 shell.  It
has a small feature set similar to a traditional Bourne shell.")
    (home-page "http://github.com/rakitzis/rc")
    (license zlib)))

(define-public es
  (package
    (name "es")
    (version "0.9.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/wryun/es-shell/releases/"
                           "download/v" version "/es-" version ".tar.gz"))
       (sha256
        (base32
         "1fplzxc6lncz2lv2fyr2ig23rgg5j96rm2bbl1rs28mik771zd5h"))
       (file-name (string-append name "-" version ".tar.gz"))))
    (build-system gnu-build-system)
    (arguments
     `(#:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 're-enter-rootdir
           ;; The tarball has no folder.
           (lambda _
             (chdir ".."))))))
    (inputs
     `(("readline" ,readline)))
    (native-inputs
     `(("bison" ,bison)))
    (synopsis "Extensible shell with higher-order functions")
    (description
     "Es is an extensible shell.  The language was derived from the Plan 9
shell, rc, and was influenced by functional programming languages, such as
Scheme, and the Tcl embeddable programming language.  This implementation is
derived from Byron Rakitzis's public domain implementation of rc, and was
written by Paul Haahr and Byron Rakitzis.")
    (home-page "https://wryun.github.io/es-shell/")
    (license public-domain)))

(define-public tcsh
  (package
    (name "tcsh")
    (version "6.18.01")
    (source (origin
              (method url-fetch)
              ;; Old tarballs are moved to old/.
              (uri (list (string-append "ftp://ftp.astron.com/pub/tcsh/"
                                        "tcsh-" version ".tar.gz")
                         (string-append "ftp://ftp.astron.com/pub/tcsh/"
                                        "old/tcsh-" version ".tar.gz")))
              (sha256
               (base32
                "1a4z9kwgx1iqqzvv64si34m60gj34p7lp6rrcrb59s7ka5wa476q"))
              (patches (search-patches "tcsh-fix-autotest.patch"
                                       "tcsh-do-not-define-BSDWAIT.patch"
                                       "tcsh-fix-out-of-bounds-read.patch"))
              (patch-flags '("-p0"))))
    (build-system gnu-build-system)
    (inputs
     `(("autoconf" ,autoconf)
       ("coreutils" ,coreutils)
       ("ncurses" ,ncurses)))
    (arguments
     `(#:phases
       (alist-cons-before
        'check 'patch-test-scripts
        (lambda _
          ;; Take care of pwd
          (substitute* '("tests/commands.at" "tests/variables.at")
            (("/bin/pwd") (which "pwd")))
          ;; The .at files create shell scripts without shebangs. Erk.
          (substitute* "tests/commands.at"
            (("./output.sh") "/bin/sh output.sh"))
          (substitute* "tests/syntax.at"
            (("; other_script.csh") "; /bin/sh other_script.csh"))
          ;; Now, let's generate the test suite and patch it
          (system* "make" "tests/testsuite")

          ;; This file is ISO-8859-1 encoded.
          (with-fluids ((%default-port-encoding #f))
            (substitute* "tests/testsuite"
              (("/bin/sh") (which "sh")))))
        (alist-cons-after
         'install 'post-install
         (lambda* (#:key inputs outputs #:allow-other-keys)
          (let* ((out (assoc-ref %outputs "out"))
                 (bin (string-append out "/bin")))
           (with-directory-excursion bin
             (symlink "tcsh" "csh"))))
         %standard-phases))))
    (home-page "http://www.tcsh.org/")
    (synopsis "Unix shell based on csh")
    (description
     "Tcsh is an enhanced, but completely compatible version of the Berkeley
UNIX C shell (csh).  It is a command language interpreter usable both as an
interactive login shell and a shell script command processor.  It includes a
command-line editor, programmable word completion, spelling correction, a
history mechanism, job control and a C-like syntax.")
    (license bsd-4)))

(define-public zsh
  (package
    (name "zsh")
    (version "5.2")
    (source (origin
              (method url-fetch)
              (uri (list (string-append
                           "http://www.zsh.org/pub/zsh-" version
                           ".tar.gz")
                         (string-append
                           "http://www.zsh.org/pub/old/zsh-" version
                           ".tar.gz")))
              (sha256
               (base32
                "0dsr450v8nydvpk8ry276fvbznlrjgddgp7zvhcw4cv69i9lr4ps"))))
    (build-system gnu-build-system)
    (arguments `(#:configure-flags '("--with-tcsetpgrp" "--enable-pcre")
                 #:phases
                 (modify-phases %standard-phases
                   (add-before 'configure 'fix-sh
                     (lambda _
                       ;; Some of the files are ISO-8859-1 encoded.
                       (with-fluids ((%default-port-encoding #f))
                                    (substitute*
                                        '("configure"
                                          "configure.ac"
                                          "Src/exec.c"
                                          "Src/mkmakemod.sh"
                                          "Config/installfns.sh"
                                          "Config/defs.mk.in"
                                          "Test/E01options.ztst"
                                          "Test/A05execution.ztst"
                                          "Test/A01grammar.ztst"
                                          "Test/A06assign.ztst"
                                          "Test/B02typeset.ztst"
                                          "Completion/Unix/Command/_init_d"
                                          "Util/preconfig")
                                      (("/bin/sh") (which "sh")))))))))
    (native-inputs `(("autoconf" ,autoconf)))
    (inputs `(("ncurses" ,ncurses)
              ("pcre" ,pcre)
              ("perl" ,perl)))
    (synopsis "Powerful shell for interactive use and scripting")
    (description "The Z shell (zsh) is a Unix shell that can be used
as an interactive login shell and as a powerful command interpreter
for shell scripting.  Zsh can be thought of as an extended Bourne shell
with a large number of improvements, including some features of bash,
ksh, and tcsh.")
    (home-page "http://www.zsh.org/")

    ;; The whole thing is under an MIT/X11-style license, but there's one
    ;; command, 'Completion/Unix/Command/_darcs', which is under GPLv2+.
    (license gpl2+)))

(define-public xonsh
  (package
    (name "xonsh")
    (version "0.5.3")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "xonsh" version))
        (sha256
          (base32
            "1pb1am26wl21g798lpl091j95900py7jj4g98rs9qkhywiln4z4q"))
        (modules '((guix build utils)))
        (snippet
         `(begin
            ;; Delete bundled ply.
            (delete-file-recursively "xonsh/ply")
            (substitute* '("setup.py")
              (("'xonsh\\.ply\\.ply',") ""))
            #t))))
    (build-system python-build-system)
    (arguments
     '(;; TODO Try running run the test suite.
       ;; See 'requirements-tests.txt' in the source distribution for more
       ;; information.
       #:tests? #f))
    (inputs
     `(("python-ply" ,python-ply)))
    (home-page "http://xon.sh/")
    (synopsis "Python-ish shell")
    (description
     "Xonsh is a Python-ish, BASHwards-looking shell language and command
prompt.  The language is a superset of Python 3.4+ with additional shell
primitives that you are used to from Bash and IPython.  It works on all major
systems including Linux, Mac OSX, and Windows.  Xonsh is meant for the daily
use of experts and novices alike.")
    (license bsd-2)))
