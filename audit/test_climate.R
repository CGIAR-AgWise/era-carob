# Exercise the handoff CLI with synthetic feature definitions.
library(data.table)
dir <- tempfile(); dir.create(dir)
paths <- file.path(dir,c("candidate.rds","climate.csv","rules.csv","coverage.csv"))
m <- data.table(source="carob",source_row=1:2,latitude=1,longitude=2,country="Kenya",crop="maize",
                planting_date="2020-03-01",harvest_date="2020-06-10")
saveRDS(m,paths[1])
v <- m[1,.(source,source_row,latitude,longitude,planting_date,window_start="2020-02-23",window_end="2020-06-10",
           variable="rain",units="mm",provider_version="test",grid_id="sample",value=120)]
rules <- data.table(variable=c("rain","temperature"),units=c("mm","degC"),provider_version="test",
                    start_anchor="planting",start_days=-7L,end_anchor="harvest",end_days=0L)
fwrite(rules,paths[3])
check <- function(rows) {
  fwrite(rows,paths[2])
  system2("Rscript",c("audit/check_climate.R",shQuote(paths)),stdout=FALSE,stderr=FALSE)
}
stopifnot(check(v)==0L)
coverage <- fread(paths[4])
stopifnot(coverage[variable=="rain",matched]==1L,coverage[variable=="temperature",matched]==0L)
shifted <- copy(v)[, `:=`(window_start="2019-02-23",window_end="2019-06-10")]
forged <- copy(v)[, `:=`(harvest_date="2021-06-10",window_end="2021-06-10")]
stopifnot(check(forged)!=0L,check(shifted)!=0L,check(rbind(v,v))!=0L,check(copy(v)[,latitude:=3])!=0L)
unlink(dir,recursive=TRUE)
cat("Climate tests passed, including wrong season and absent feature.\n")
