# Ordinary-source publication

The 22-file implementation formerly retained in `.numi/connectome-finalize`
and `.numi/connectome-decoder` is now published at its ordinary source paths.
No materialization command is required. The historical final-source SHA-256
manifest is preserved beside this file; future reviewed changes legitimately
supersede those baseline hashes.

Source objects were checked against that manifest and independently computed
Git blob IDs in run 34182723648. The preparation job stored immutable blobs;
it did not create a commit or update any branch. The owning development session
assembled this source tree and published it by a non-forced `main` update.

The obsolete reconstruction script and one-off workflows have been removed.
The maintained connectome workflow now builds every target of the real package,
including its tests, from the exact checkout. It never applies patches or
publishes source. The focused diagnostic harness remains optional, not the
package integration authority.

Local checks before this publication: 23 native C++ checks passed; four import
checks passed and two Arrow-dependent checks were skipped because PyArrow was
not present in the Linux workspace. Apple CI installs Arrow and runs that
suite without those skips. The previously passing Apple source/shader/learner
run remains recorded in `evidence/connectome-continuation/README.md`.

This publication does not claim a new Apple pass, a production Metal 4 root,
or a successful physical robot task. Historical reports describing staged
source refer to their explicitly named older revisions.
