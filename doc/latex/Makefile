PROJECTNAME = "KyberLight"

MAINDOCUMENTBASENAME = main
MAINDOCUMENTFILENAME = ${MAINDOCUMENTBASENAME}.tex
## COMMANDS:
PDFLATEX_CMD = pdflatex
#BIBTEX_CMD = bibtex
BIBTEX_CMD = biber
MAKEIDX_CMD = makeindex
DATESTAMP = `/bin/date +%Y-%m-%d`
DATESTAMP_AND_PROJECT = ${DATESTAMP}_${PROJECTNAME}
#PDFVIEWER = xpdf
PDFVIEWER = open
TEMPLATEDOCUBASENAME = Template-Documentation
TEMPLATEDOCUFILE = ${TEMPLATEDOCUBASENAME}.tex

#help
#helpThe main targets of this Makefile are:
#help	help	this help
.PHONY: help
help:
	@sed -n 's/^#help//p' < Makefile

#help	all	see "pdf"
.PHONY: all
all: pdf

#help	pdf	creates a pdf file using pdflatex
.PHONY: pdf
pdf:
	${PDFLATEX_CMD} ${MAINDOCUMENTFILENAME}
	-${BIBTEX_CMD} ${MAINDOCUMENTBASENAME}
	${PDFLATEX_CMD} ${MAINDOCUMENTFILENAME}
	${PDFLATEX_CMD} ${MAINDOCUMENTFILENAME}
	-mv ${MAINDOCUMENTBASENAME}.pdf ${DATESTAMP_AND_PROJECT}.pdf



# --------------------------------------------------------

#help	view	view the PDF-file
.PHONY: view
view: pdf
	${PDFVIEWER} ${DATESTAMP_AND_PROJECT}.pdf

# --------------------------------------------------------


#help	clean	clean up temporary files
.PHONY: clean
clean: 
	-rm -rf *.bcf *.run.xml _*_.* *~ *.aux *-blx.bib *.bbl ${MAINDOCUMENTBASENAME}.dvi *.ps *.blg *.idx *.ilg *.ind *.toc *.log *.log *.brf *.out *.lof *.lot *.gxg *.glx *.gxs *.glo *.gls *.tdo

#help	purge	cleaner than clean ;-)
.PHONY: purge
purge: clean
	-rm -f 20*_${PROJECTNAME}.pdf

#help	force	force rebuild next run
.PHONY: force
force:
	touch *tex



figures/%.pdf: figures/%.xml
	drawio-batch -d 0 $< $@
#end

