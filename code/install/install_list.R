
# INSTALL APPS
# Install key application libraries as test
# Provide a single file name

# Installation settings:
r <- getOption("repos")
# Change this mirror as needed:
# r["CRAN"] <- "http://cran.cnr.berkeley.edu/"
r["CRAN"] <- "http://cran.wustl.edu/"
options(repos = r)
NCPUS = 8

cat("INSTALL-APPS.R ...\n")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  cat("INSTALL-APPS.R: provide 1 file!\n")
  quit(status=1)
}

pkg_file = args[1]
cat(paste("pkg list file:", pkg_file, "\n"))

PKGS <- scan(pkg_file, what="", sep="\n", comment.char = "#")

# Install and test each package
count = 1
total = length(PKGS)
for (pkg in PKGS) {
  cat("\n")
  progress <- sprintf("[%i/%i]", count, total)
  cat("INSTALL: ", progress, pkg, "\n")
  # install.packages() does not return an error status
  install.packages(pkg, Ncpus=NCPUS, verbose=TRUE, clean=FALSE,
                  keep_outputs=TRUE)
  cat("\n")
  # Test that the pkg installed and is loadable
  cat("LOAD:    ", progress, pkg, "\n")
  library(package=pkg, character.only=TRUE)
  count <- count + 1
}

cat("\n")
cat("INSTALL-APPS.R: OK\n");
