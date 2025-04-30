
# INSTALL R PKGS: GRAPHICS

# Run this via install_emews.sh
# Installs all R packages needed for EMEWS workflows
# Loads them immediately after installation as a test,
#       because R does not report errors when installations fail.
# You may also run this interactively for testing with:
# $ Rscript install_pkgs.R

print("INSTALL_R_PKGS: GRAPHICS: START")

# Installation settings:
r <- getOption("repos")
# Change this mirror as needed:
# r["CRAN"] <- "http://cran.cnr.berkeley.edu/"
# r["CRAN"] <- "http://cran.wustl.edu/"
# r["CRAN"] <- "https://mirror.las.iastate.edu/"
r["CRAN"] <- "https://cloud.r-project.org"
options(repos = r)
NCPUS = 1

# As of 2024-05-29, need to install jsonlite before reticulate
PKGS <- list(
  "mgcv", "farver", "ggplot2"
)

for (pkg in PKGS) {
  print("")
  cat("INSTALL: ", pkg, "\n")
  # install.packages() does not return an error status
  install.packages(pkg, Ncpus=NCPUS, verbose=TRUE)
  print("")
  # Test that the pkg installed and is loadable
  cat("LOAD:    ", pkg, "\n")
  library(package=pkg, character.only=TRUE)
}

cat("PACKAGE LIST:\n")
print(installed.packages())

print("INSTALL_R_PKGS: GRAPHICS: DONE.")
