#!/bin/sh -e

case "$1" in
    clean)
        for f in *.md; do
            rm -v "${f%.*}.tex"
        done
        rm -v gen.tex
        rm -v kiss.pdf
        ;;
    *)
        : > gen.tex
        for f in *.md; do
            lowdown -T latex "$f" > "${f%.*}.tex"
            echo "\\input{${f%.*}.tex}" >> gen.tex
        done

        cluttex -e pdflatex kiss.tex
        ;;
esac
