# Validate a proposed climate handoff against the corrected source keys.
# Rscript audit/check_climate.R sf001-review.rds climate.csv coverage.csv
args <- commandArgs(TRUE)
stopifnot(length(args)==3L)
m <- data.table::as.data.table(readRDS(args[1]))
v <- data.table::fread(args[2],colClasses=c(planting_date="character",window_start="character",window_end="character"))
keys <- c("source","source_row")
required <- c(keys,"latitude","longitude","planting_date","window_start","window_end","variable","units","value","grid_id","provider_version")
stopifnot(nrow(v)>0,all(required %in% names(v)),all(complete.cases(v[,..required])),
          all(sapply(v[,..required],function(x) all(nzchar(trimws(as.character(x)))))),
          !anyDuplicated(v[,c(keys,"variable","window_start","window_end"),with=FALSE]),
          !anyDuplicated(m[,..keys]),all(is.finite(v$value)))
target <- m[,.(source,source_row,latitude,longitude,planting_date,country,crop)]
matched <- merge(v,target,by=keys,all.x=TRUE,suffixes=c("","_source"))
day <- function(x) {
  d <- as.Date(ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$",x),x,NA_character_),format="%Y-%m-%d")
  stopifnot(!anyNA(d),all(format(d,"%Y-%m-%d")==x));d
}
stopifnot(nrow(matched)==nrow(v),!anyNA(matched$latitude_source),!anyNA(matched$longitude_source),
          all(abs(matched$latitude-matched$latitude_source)<1e-7),
          all(abs(matched$longitude-matched$longitude_source)<1e-7),
          all(abs(matched$latitude)<=90 & abs(matched$longitude)<=180),
          all(matched$latitude!=0 | matched$longitude!=0),
          all(day(matched$planting_date)==day(as.character(matched$planting_date_source))),
          all(day(matched$window_start)<=day(matched$window_end)))
# Denominator deliberately includes all retained rows. A match for one variable
# does not imply a full predictor vector or a scientifically valid weather value.
target[,year:=substr(as.character(planting_date),1,4)]
groups <- c("source","country","crop","year")
den <- target[,.(retained=.N),by=groups]
coverage <- data.table::rbindlist(lapply(sort(unique(v$variable)),function(feature) {
  linked <- unique(v[variable==feature,..keys])
  n <- merge(target,linked,by=keys)[,.(matched=.N),by=groups]
  q <- merge(den,n,by=groups,all.x=TRUE)
  q[is.na(matched),matched:=0L]
  q[,variable:=feature]
  q
}))
data.table::fwrite(coverage,args[3])
