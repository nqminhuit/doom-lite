;; -*- no-byte-compile: t; -*-
;;; completion/vertico/packages.el

(package! vertico
  :recipe (:host github :repo "minad/vertico" :files (:defaults "extensions/vertico-*.el"))
  :pin "6976caba3c83799e54d3e2647f6dee79f18869b2")

(package! orderless
  :recipe (:host github :repo "oantolin/orderless")
  :pin "e271a8ec938929b726331236cf56d1c44571122e")

(package! consult
  :recipe (:host github :repo "minad/consult")
  :pin "a64569f377b8bc0f62e1d2ae0f3ee48ba4a7cc1c")
(package! consult-dir
  :recipe (:host github :repo "karthink/consult-dir")
  :pin "1497b46d6f48da2d884296a1297e5ace1e050eb5")
(package! embark
  :recipe (:host github :repo "oantolin/embark" :files ("embark.el" "embark-org.el"))
  :pin "87e53827cf6659dcc4ac4e54be9af34aeca44f6e")
(package! embark-consult
  :recipe (:host github :repo "oantolin/embark" :files ("embark-consult.el"))
  :pin "87e53827cf6659dcc4ac4e54be9af34aeca44f6e")

