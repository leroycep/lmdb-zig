id: s188jtnympidonu5pfe6e2rtq09fczeqsuv63ei4q31zoiki
name: lmdb
main: src/lib.zig
dependencies:
- type: git
  path: https://github.com/LMDB/lmdb.git
  name: lmdb
  c_include_dirs:
   - libraries/liblmdb
  c_source_flags: [-pthread]
  c_source_files:
   - libraries/liblmdb/mdb.c
   - libraries/liblmdb/midl.c
