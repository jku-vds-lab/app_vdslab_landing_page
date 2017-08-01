add another service
===================

1. create a tasks definition and publish the web at a free port 
 * 32790 ... taco-daily
 * 32791 ... lineup
 * 32792 ... bob
 * 32793 ... taggle-daily
 * 32794 ... ordino-daily
 * 32795 ... gapminder
 * 32796 ... stratomex
 * 32797 ... tourguide
 * 32798 ... pathfinder
 * 32799 ... gapminder-retrieval
 * 32800 ... domino
 * 32801 ... lineage
 * 32802 ... taco
 * 32803 ... thermalplot
 * 32804 ... ordino
1. create a new log group named `app_<Name`>` and use this as log driver
1. create a new task revision of caleydoapp
 adding within nginx a new environment variable: `PHOVEA_APP_<NAME>` `<Name>;<Domain>;cluster:<Port>`
how to access other links on the same cluster instance
------------------------------------------------------
use private ip of the cluster instance and a free port cluster/10.0.1.172
