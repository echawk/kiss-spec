#!/bin/sh -e

case "$1" in
    clean)
        for f in *.md; do
            rm -v "${f%.*}.tex"
        done
        rm -v kiss.pdf
        ;;
    *)
        for f in *.md; do
            lowdown -T latex "$f" > "${f%.*}.tex"
        done

        cluttex -e pdflatex kiss.tex
        ;;
esac
