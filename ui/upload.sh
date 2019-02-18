#!/bin/sh

REACT_APP_OFFSITE=offsite npm run build
rsync -arv --delete build/ peerdns.p2pstuff.xyz:/srv/peerdns.hype/ui/
