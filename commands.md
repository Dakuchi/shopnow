kubectl create secret docker-registry shopnow-registry-secret --docker-server=https://index.docker.io/v1/ --docker-username=dakuchi --docker-password=password -n shopnow

# connect discovery service with postgres 
psql -h postgres -p 5432 -U postgres -d postgres

# connect discovery service with postgres in different namespace
psql -h postgres.shopnow.svc.cluster.local -p 5432 -U postgres -d postgres 
