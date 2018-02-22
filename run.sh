docker run -it -v $(pwd):/srv/jekyll -v /usr/local/bundle:/usr/local/bundle --rm -p 4000:4000 jekyll/jekyll jekyll serve
