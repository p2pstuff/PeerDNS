#!/bin/sh

npm run build
tar czvf peerdns-ui-build.tgz build/
scp peerdns-ui-build.tgz peerdns.p2pstuff.xyz:/srv/peerdns.hype/

REACT_APP_OFFSITE=offsite npm run build
rsync -arv --delete build/ peerdns.p2pstuff.xyz:/srv/peerdns.hype/ui/
