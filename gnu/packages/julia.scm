;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2015, 2016 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2016 Efraim Flashner <efraim@flashner.co.il>
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

(define-module (gnu packages julia)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix utils)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages algebra)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages libunwind)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages multiprecision) ; mpfr
  #:use-module (gnu packages pcre)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages textutils)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages wget)
  #:use-module (ice-9 match))

(define libuv-julia
  (let ((commit "8d5131b6c1595920dd30644cd1435b4f344b46c8")
        (revision "4"))
    (package (inherit libuv)
      (name "libuv-julia")
      (version (string-append "1.9.0-" revision "." (string-take commit 8)))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/JuliaLang/libuv.git")
                      (commit commit)))
                (file-name (string-append name "-" version "-checkout"))
                (sha256
                 (base32
                  "1fq0vhiprdryw8iisxxwyld3xdr5za6y8458p22ff56al98h22fv"))))
      (build-system gnu-build-system)
      (arguments
       (substitute-keyword-arguments (package-arguments libuv)
         ((#:phases phases)
          `(modify-phases ,phases
             (delete 'autogen)))))
      (home-page "https://github.com/JuliaLang/libuv"))))

(define libunwind-for-julia
  (package
    (inherit libunwind)
    (version "1.1-julia2")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://s3.amazonaws.com/julialang/src/"
                                  "libunwind-" version ".tar.gz"))
              (sha256
               (base32
                "0499x7sg2v18a6cry6l8y713cgmic0adnjph8i0xr1db9p7n8qyv"))))))

(define-public julia
  (package
    (name "julia")
    (version "0.5.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/JuliaLang/julia/releases/download/v"
                    version "/julia-" version ".tar.gz"))
              (sha256
               (base32
                "0bhickil88lalp9jdj1kmf4is70zinhx8ha9rng0g3z50r4a2qmv"))))
    (build-system gnu-build-system)
    (arguments
     `(#:test-target "test"
       #:modules ((ice-9 match)
                  (guix build gnu-build-system)
                  (guix build utils))

       ;; Do not strip binaries to keep support for full backtraces.
       ;; See https://github.com/JuliaLang/julia/issues/17831
       #:strip-binaries? #f

       ;; The DSOs use $ORIGIN to refer to each other, but (guix build
       ;; gremlin) doesn't support it yet, so skip this phase.
       #:validate-runpath? #f

       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (add-after 'unpack 'prepare-deps
           (lambda* (#:key inputs #:allow-other-keys)
             (mkdir "deps/srccache")
             (copy-file (assoc-ref inputs "dsfmt")
                        "deps/srccache/dsfmt-2.2.3.tar.gz")
             (copy-file (assoc-ref inputs "objconv")
                        "deps/srccache/objconv.zip")
             (copy-file (assoc-ref inputs "suitesparse")
                        "deps/srccache/SuiteSparse-4.4.5.tar.gz")
             (copy-file (string-append (assoc-ref inputs "virtualenv")
                                       "/bin/virtualenv")
                        "julia-env")
             #t))
         (add-after 'unpack 'fix-llvm-flag
           (lambda _
             (substitute* "src/Makefile"
               (("-lLLVM-\\$\\(shell \\$\\(LLVM_CONFIG_HOST\\) --version\\)")
                "$(shell $(LLVM_CONFIG_HOST) --libs)"))
             #t))
         (add-before 'check 'set-home
           ;; Some tests require a home directory to be set.
           (lambda _ (setenv "HOME" "/tmp") #t))
         (add-after 'unpack 'hardcode-soname-map
          ;; ./src/runtime_ccall.cpp creates a map from library names to paths
          ;; using the output of "/sbin/ldconfig -p".  Since ldconfig is not
          ;; used in Guix, we patch runtime_ccall.cpp to contain a static map.
          (lambda* (#:key inputs #:allow-other-keys)
            (use-modules (ice-9 match))
            (substitute* "src/runtime_ccall.cpp"
              (("jl_read_sonames.*;")
               (string-join
                (map (match-lambda
                       ((input libname soname)
                        (string-append
                         "sonameMap[\"" libname "\"] = "
                         "\"" (assoc-ref inputs input) "/lib/" soname "\";")))
                     '(("libc"        "libc"           "libc.so.6")
                       ("pcre2"       "libpcre2-8"     "libpcre2-8.so")
                       ("mpfr"        "libmpfr"        "libmpfr.so")
                       ("openblas"    "libblas"        "libopenblas.so")
                       ("arpack-ng"   "libarpack"      "libarpack.so")
                       ("lapack"      "liblapack"      "liblapack.so")
                       ("libgit2"     "libgit2"        "libgit2.so")
                       ("gmp"         "libgmp"         "libgmp.so")
                       ("openlibm"    "libopenlibm"    "libopenlibm.so")
                       ("openspecfun" "libopenspecfun" "libopenspecfun.so")
                       ("fftw"        "libfftw3"       "libfftw3.so")
                       ("fftwf"       "libfftw3f"      "libfftw3f.so"))))))
            (substitute* "base/fft/FFTW.jl"
              (("const libfftw = Base.libfftw_name")
               (string-append "const libfftw = \""
                              (assoc-ref inputs "fftw") "/lib/libfftw3.so"
                              "\""))
              (("const libfftwf = Base.libfftwf_name")
               (string-append "const libfftwf = \""
                              (assoc-ref inputs "fftwf") "/lib/libfftw3f.so"
                              "\"")))
            (substitute* "base/math.jl"
              (("const libm = Base.libm_name")
               (string-append "const libm = \""
                              (assoc-ref inputs "openlibm")
                              "/lib/libopenlibm.so"
                              "\""))
              (("const openspecfun = \"libopenspecfun\"")
               (string-append "const openspecfun = \""
                              (assoc-ref inputs "openspecfun")
                              "/lib/libopenspecfun.so"
                              "\"")))
            (substitute* "base/pcre.jl"
              (("const PCRE_LIB = \"libpcre2-8\"")
               (string-append "const PCRE_LIB = \""
                              (assoc-ref inputs "pcre2")
                              "/lib/libpcre2-8.so" "\"")))
            #t))
         (add-before 'build 'fix-include-and-link-paths
          (lambda* (#:key inputs #:allow-other-keys)
            ;; LIBUTF8PROC is a linker flag, not a build target.  It is
            ;; included in the LIBFILES_* variable which is used as a
            ;; collection of build targets and a list of libraries to link
            ;; against.
            (substitute* "src/flisp/Makefile"
              (("\\$\\(BUILDDIR\\)/\\$\\(EXENAME\\): \\$\\(OBJS\\) \\$\\(LIBFILES_release\\)")
               "$(BUILDDIR)/$(EXENAME): $(OBJS) $(LLT_release)")
              (("\\$\\(BUILDDIR\\)/\\$\\(EXENAME\\)-debug: \\$\\(DOBJS\\) \\$\\(LIBFILES_debug\\)")
               "$(BUILDDIR)/$(EXENAME)-debug: $(DOBJS) $(LLT_debug)"))

            ;; The REPL must be linked with libuv.
            (substitute* "ui/Makefile"
              (("JLDFLAGS \\+= ")
               (string-append "JLDFLAGS += "
                              (assoc-ref %build-inputs "libuv")
                              "/lib/libuv.so ")))

            (substitute* "base/Makefile"
              (("\\$\\(build_includedir\\)/uv-errno.h")
               (string-append (assoc-ref inputs "libuv")
                              "/include/uv-errno.h")))
            #t))
         (add-before 'build 'replace-default-shell
          (lambda _
            (substitute* "base/client.jl"
              (("/bin/sh") (which "sh")))
            #t))
         (add-after 'unpack 'hardcode-paths
           (lambda _
             (substitute* "base/interactiveutil.jl"
               (("`which") (string-append "`" (which "which")))
               (("`wget")  (string-append "`" (which "wget"))))
             #t))
         (add-before 'check 'disable-broken-tests
           (lambda _
             (substitute* "test/choosetests.jl"
               ;; These tests fail, probably because some of the input
               ;; binaries have been stripped and thus backtraces don't look
               ;; as expected.
               (("\"backtrace\",") "")
               (("\"compile\",") "")
               (("\"replutil\",") "")
               (("\"cmdlineargs\",") ""))
             #t)))
       #:make-flags
       (list
        (string-append "prefix=" (assoc-ref %outputs "out"))

        ;; Passing the MARCH flag is necessary to build binary substitutes for
        ;; the supported architectures.
        ,(match (or (%current-target-system)
                    (%current-system))
           ("x86_64-linux" "MARCH=x86-64")
           ("i686-linux" "MARCH=pentium4")
           ;; Prevent errors when querying this package on unsupported
           ;; platforms, e.g. when running "guix package --search="
           (_ "MARCH=UNSUPPORTED"))

        "CONFIG_SHELL=bash"     ;needed to build bundled libraries
        "USE_SYSTEM_DSFMT=0"    ;not packaged for Guix and upstream has no
                                ;build system for a shared library.
        "USE_SYSTEM_LAPACK=1"
        "USE_SYSTEM_BLAS=1"
        "USE_BLAS64=0"          ;needed when USE_SYSTEM_BLAS=1

        "USE_SYSTEM_FFTW=1"
        "LIBFFTWNAME=libfftw3"
        "LIBFFTWFNAME=libfftw3f"

        ;; TODO: Suitesparse does not install shared libraries, so we cannot
        ;; use the suitesparse package.
        ;; "USE_SYSTEM_SUITESPARSE=1"
        ;; (string-append "SUITESPARSE_INC=-I "
        ;;                (assoc-ref %build-inputs "suitesparse")
        ;;                "/include")

        "USE_GPL_LIBS=1"        ;proudly
        "USE_SYSTEM_UTF8PROC=1"
        (string-append "UTF8PROC_INC="
                       (assoc-ref %build-inputs "utf8proc")
                       "/include")
        "USE_SYSTEM_LLVM=1"
        "USE_SYSTEM_LIBUNWIND=1"
        "USE_SYSTEM_LIBUV=1"
        (string-append "LIBUV="
                       (assoc-ref %build-inputs "libuv")
                       "/lib/libuv.so")
        (string-append "LIBUV_INC="
                       (assoc-ref %build-inputs "libuv")
                       "/include")
        "USE_SYSTEM_PATCHELF=1"
        "USE_SYSTEM_PCRE=1"
        "USE_SYSTEM_OPENLIBM=1"
        "USE_SYSTEM_GMP=1"
        "USE_SYSTEM_MPFR=1"
        "USE_SYSTEM_ARPACK=1"
        "USE_SYSTEM_LIBGIT2=1"
        "USE_SYSTEM_OPENSPECFUN=1")))
    (inputs
     `(("llvm" ,llvm)
       ("arpack-ng" ,arpack-ng)
       ("coreutils" ,coreutils) ;for bindings to "mkdir" and the like
       ("lapack" ,lapack)
       ("openblas" ,openblas) ;Julia does not build with Atlas
       ("libunwind" ,libunwind-for-julia)
       ("openlibm" ,openlibm)
       ("openspecfun" ,openspecfun)
       ("libgit2" ,libgit2)
       ("fftw" ,fftw)
       ("fftwf" ,fftwf)
       ("fortran" ,gfortran)
       ("libuv" ,libuv-julia)
       ("pcre2" ,pcre2)
       ("utf8proc" ,utf8proc)
       ("mpfr" ,mpfr)
       ("wget" ,wget)
       ("which" ,which)
       ("zlib" ,zlib)
       ("gmp" ,gmp)
       ("virtualenv" ,python2-virtualenv)
       ;; FIXME: The following inputs are downloaded from upstream to allow us
       ;; to use the lightweight Julia release tarball.  Ideally, these inputs
       ;; would eventually be replaced with proper Guix packages.

       ;; TODO: run "make -f contrib/repackage_system_suitesparse4.make" to copy static lib
       ("suitesparse"
        ,(origin
           (method url-fetch)
           (uri "http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-4.4.5.tar.gz")
           (sha256
            (base32
             "1jcbxb8jx5wlcixzf6n5dca2rcfx6mlcms1k2rl5gp67ay3bix43"))))
       ("objconv"
        ,(origin
           (method url-fetch)
           (uri "http://www.agner.org/optimize/objconv.zip")
           (sha256
            (base32
             "1fi7qa2sd9vb35dvkgripjf0fayzg2qmff215f8agfqfiwd1g8qs"))))
       ("dsfmt"
        ,(origin
           (method url-fetch)
           (uri (string-append
                 "http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/"
                 "SFMT/dSFMT-src-2.2.3.tar.gz"))
           (sha256
            (base32
             "03kaqbjbi6viz0n33dk5jlf6ayxqlsq4804n7kwkndiga9s4hd42"))))))
    (native-inputs
     `(("openssl" ,openssl)
       ("perl" ,perl)
       ("patchelf" ,patchelf)
       ("pkg-config" ,pkg-config)
       ("python" ,python-2)))
    ;; Julia is not officially released for ARM and MIPS.
    ;; See https://github.com/JuliaLang/julia/issues/10639
    (supported-systems '("i686-linux" "x86_64-linux"))
    (home-page "http://julialang.org/")
    (synopsis "High-performance dynamic language for technical computing")
    (description
     "Julia is a high-level, high-performance dynamic programming language for
technical computing, with syntax that is familiar to users of other technical
computing environments.  It provides a sophisticated compiler, distributed
parallel execution, numerical accuracy, and an extensive mathematical function
library.")
    (license license:expat)))
