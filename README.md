# EMEWS Tutorial

Link to GitHub IO page: https://emews.org/emews-tutorial/

To build the site, simply setup asciidoctor (see below) and run:

----
$ scripts/build_site.sh
----

The site is live at https://emews.org/emews-tutorial/
and accessible via http://emews.org

## Developer setup

### Ubuntu

Must install asciidoctor as APT package, then asciidoctor-bibtex as Ruby Gem.

Gem does not seem to work in:

* Anaconda, Python 3.11, 2024-02-06
* Anaconda, Python 3.13, 2025-11-07

So do all these steps:

```
$ sudo apt install ruby-dev
$ sudo apt install asciidoctor
$ sudo gem install asciidoctor-bibtex
$ sudo gem install pygments.rb
```
