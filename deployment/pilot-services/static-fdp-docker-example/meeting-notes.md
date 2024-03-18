topics
------

1. What's needed for next week's review
2. FDP deployment---the what and the how


### GA preps

- what to present?
- demo required?

My understanding:
* Generic presentation about Teadal tech
* Explanation of how those tools work
* Generic demo w/ dummy FDP
* Tell reviewers it works the same in basically all rollouts

implication:
- you report on progress
- perhaps impact?
- no demo, no tech presentation about your deployment


### FDP deployment (stop gap solution)

 FDP: Nginx + content directory

 content directory (whatever host)

http://your-teadal/manrep/1/prod.csv

 + manrep
   + 1
     - prod.csv
     - logistics.cvs (json?)
     - quality.csv
     - analytics.csv
   + 2
     - prod.csv
     - logistics.cvs (json?)
     - quality.csv
     - analytics.csv
   + 3
     - prod.csv
     - logistics.cvs (json?)
     - quality.csv
     - analytics.csv


 SELECT prod_units, ...
 FROM ManRep
 WHERE id = 1
 EXPORT csv, file=prod.cvs


tar czf manreps.tgz manrep
or use zip if tar is a problem


from a machine where you can connect to your teadal node, run this cmd

kubectl -n my-fdp-ns cp manreps.tgz nginx-pod-xyz:/manreps.tgz

kubectl -n my-fdp-ns exec nginx-pod-xyz -- sh

tar -C /www/root/ xzf manreps.tgz
chmod -R nginx:nginx /www/root/

routing:

- ingress spec

security:

roles:
- top manager
- quality manager
- logistics manager
- ...

tech team takes abstract access control matrix and converts that into code