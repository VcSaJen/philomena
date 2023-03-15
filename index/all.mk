all: comments galleries sequences images posts reports tags filters

comments:
	$(MAKE) -f comments.mk

galleries:
	$(MAKE) -f galleries.mk

sequences:
	$(MAKE) -f sequences.mk

images:
	$(MAKE) -f images.mk

posts:
	$(MAKE) -f posts.mk

reports:
	$(MAKE) -f reports.mk

tags:
	$(MAKE) -f tags.mk

filters:
	$(MAKE) -f filters.mk

clean:
	rm -f ./*.jsonl
