(lang dune 3.7)
(name normalizffi)
(version 0.1)
(using ctypes 0.3)

(generate_opam_files false)

(source (github nclskoh/normalizffi))
(license MIT)
(authors "Nicolas Koh")
(maintainers "ckoh@princeton.edu")
(package
 (name normalizffi)
 (synopsis "Ocaml bindings for the C++ Normaliz library")
 (description "")
 (depends
  (ocaml (>= 4.09)) (dune (>= 3.2)) mlgmpidl))

