BUILD=build
BBLS=$(BUILD)/pr.bbl $(BUILD)/conf.bbl $(BUILD)/post.bbl $(BUILD)/talk.bbl \
	 $(BUILD)/dev.bbl $(BUILD)/mthd.bbl $(BUILD)/code.bbl $(BUILD)/prep.bbl \
	 $(BUILD)/book.bbl
ORCID=0000-0002-6533-164X

all: $(BUILD)/cv.pdf

$(BUILD)/cv.pdf: $(BBLS)
	pdflatex -output-directory=$(BUILD) cv
	pdflatex -output-directory=$(BUILD) cv

%.aux: cv.tex contact.tex self.bib zenodo.bib cvbib.bst
	pdflatex -output-directory=$(BUILD) cv

%.bbl: %.aux
	bibtex $<

zenodo.bib: zenodo.stamp.md5
	$(eval SIZE=$(shell jq .[1] zenodo.stamp ))
	curl -H 'Accept: application/x-bibtex' \
		"https://zenodo.org/api/records/?q=creators.orcid:$(ORCID)&size=$(SIZE)" | \
	bibtool -r biblatex -r cv -s -F -f '{%-2T(title)}' -o zenodo.bib

# Save timestamp with the update time of the latest deposit and number of deposits
zenodo.stamp: FORCE
	curl "https://zenodo.org/api/records/?q=creators.orcid:$(ORCID)&size=1&sort=-publication_date" | \
	jq "[.hits.hits[0].updated, .hits.total]" > zenodo.stamp

# Write .md5 file IFF contents change
%.md5: %
	$(if $(filter-out $(shell cat $@ 2>/dev/null),$(shell md5sum $*)), md5sum $* > $@)

FORCE:

cvbib.bst: cvbib.dbj
	latex $<

upload: $(BUILD)/cv.pdf
	git -C $(BUILD) init
	git -C $(BUILD) checkout -b gh-pages
	git -C $(BUILD) add cv.pdf
	git -C $(BUILD) commit -m 'PDF build'
	git -C $(BUILD) remote add origin `git remote get-url --push origin`
	git -C $(BUILD) push origin gh-pages --force
	rm -rf $(BUILD)/.git

clean:
	rm $(BUILD)/*.pdf $(BBLS) $(BUILD)/*.aux $(BUILD)/*.log \
		$(BUILD)/*.out $(BUILD)/*.blg
