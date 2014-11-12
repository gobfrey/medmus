time /usr/share/eprints/bin/epadmin erase_eprints medmus
time /usr/share/eprints/bin/import medmus archive --user 1 XML refrains_and_works.ep3xml
time ./import_tiffs.pl
time /usr/share/eprints/bin/epadmin recommit medmus eprint
time /usr/share/eprints/bin/generate_views medmus
